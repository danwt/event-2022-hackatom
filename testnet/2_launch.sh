#!/bin/bash
set -eux 

# User balance of stake tokens 
USER_COINS="100000000000stake"
# Amount of stake tokens staked
STAKE="100000000stake"
# Node IP address
NODE_IP="localhost"

PADDR="${NODE_IP}:26655"
PRPCLADDR="${NODE_IP}:26658"
PGRPCADDR="${NODE_IP}:9091"
PP2PLADDR="${NODE_IP}:26656"
CADDR="${NODE_IP}:26645"
CRPCLADDR="${NODE_IP}:26648"
CGRPCADDR="${NODE_IP}:9081"
CP2PLADDR="${NODE_IP}:26646"

# Home directory
H="."

PBIN=interchain-security-pd
CBIN=interchain-security-cd

./1_kill.sh

# Build genesis file and node directory structure
$PBIN init --chain-id provider fizz --home ${H}/provider

jq ".app_state.gov.voting_params.voting_period = \"3s\"" \
    ${H}/provider/config/genesis.json > \
    ${H}/provider/edited_genesis.json && \
    mv ${H}/provider/edited_genesis.json ${H}/provider/config/genesis.json

sleep 1

# jq condition to reduce unbonding time
#  | .app_state.staking.params.unbonding_time = \"600s\"

# Create account keypair
$PBIN keys\
    add fizz \
    --home ${H}/provider\
    --keyring-backend test\
    --output json\
    > fizz_keypair.json 2>&1

sleep 1

# Add stake to user
$PBIN add-genesis-account\
    $(jq -r .address fizz_keypair.json) $USER_COINS\
    --home ${H}/provider\
    --keyring-backend test

sleep 1

# Stake 1/1000 user's coins
$PBIN gentx fizz $STAKE\
    --chain-id provider\
    --home ${H}/provider\
    --keyring-backend test\
    --moniker fizz

sleep 1

$PBIN collect-gentxs\
    --home ${H}/provider\
    --gentx-dir ${H}/provider/config/gentx/

sleep 1

# config tendermint

dasel put string -f ${H}/provider/config/client.toml node "tcp://${PRPCLADDR}"
dasel put string -f ${H}/provider/config/config.toml consensus.timeout_commit 3s
dasel put string -f ${H}/provider/config/config.toml consensus.timeout_propose 1s

# config sdk

dasel put bool -f ${H}/provider/config/app.toml .api.enable true
dasel put bool -f ${H}/provider/config/app.toml .api.swagger true
dasel put bool -f ${H}/provider/config/app.toml .api.enabled-unsafe-cors true

# Start chain (gaia equivalent)
$PBIN start\
    --home ${H}/provider\
    --address tcp://${PADDR}\
    --rpc.laddr tcp://${PRPCLADDR}\
    --grpc.address ${PGRPCADDR}\
    --p2p.laddr tcp://${PP2PLADDR}\
    --grpc-web.enable=false\
    &> ${H}/provider/logs &

sleep 5

# Build consumer chain proposal file
tee ${H}/consumer-proposal.json<<EOF
{
    "title": "Create a chain",
    "description": "Gonna be a great chain",
    "chain_id": "consumer",
    "initial_height": {
        "revision_height": 1
    },
    "genesis_hash": "Z2VuX2hhc2g=",
    "binary_hash": "YmluX2hhc2g=",
    "spawn_time": "2022-03-11T09:02:14.718477-08:00",
    "deposit": "10000001stake"
}
EOF

$PBIN keys show fizz\
    --home ${H}/provider\
    --keyring-backend test

# Submit consumer chain proposal
$PBIN tx gov submit-proposal create-consumer-chain ${H}/consumer-proposal.json\
    --node tcp://${NODE_IP}:26658\
    --from fizz\
    --chain-id provider\
    --home ${H}/provider\
    --keyring-backend test\
    -b block\
    -y

sleep 1

# Vote yes to proposal
$PBIN tx gov vote 1 yes\
    --from fizz\
    --chain-id provider\
    --home ${H}/provider\
    --keyring-backend test\
    -b block\
    -y

sleep 5

## CONSUMER CHAIN ##

# Build genesis file and node directory structure
$CBIN init\
    fizz\
    --chain-id consumer\
    --home ${H}/consumer

sleep 1

# Create user account keypair
$CBIN keys add fizz\
    --home ${H}/consumer\
    --keyring-backend\
    test --output json\
    > ${H}/fizz_cons_keypair.json 2>&1

# Add stake to user account
$CBIN add-genesis-account\
    $(jq -r .address fizz_cons_keypair.json)\
    1000000000stake\
    --home ${H}/consumer

# Add consumer genesis states to genesis file
$PBIN query provider consumer-genesis consumer\
    --home ${H}/provider\
    -o json > ${H}/consumer_gen.json

jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]'\
    ${H}/consumer/config/genesis.json ${H}/consumer_gen.json\
    > ${H}/consumer/edited_genesis.json\
    && mv ${H}/consumer/edited_genesis.json ${H}/consumer/config/genesis.json

rm ${H}/consumer_gen.json

dasel put string -f ${H}/consumer/config/genesis.json .app_state.gov.voting_params.voting_period 3s
dasel put string -f ${H}/consumer/config/genesis.json .app_state.staking.params.unbonding_time 600s

# Create validator states
echo '{"height": "0","round": 0,"step": 0}' > ${H}/consumer/data/priv_validator_state.json

# Copy validator key files
cp ${H}/provider/config/priv_validator_key.json ${H}/consumer/config/priv_validator_key.json
cp ${H}/provider/config/node_key.json ${H}/consumer/config/node_key.json

# Set default client port
dasel put string -f ${H}/consumer/config/config.toml .rpc.laddr "tcp://127.0.0.1:26647"
dasel put string -f ${H}/consumer/config/client.toml .node "tcp://${CRPCLADDR}"
dasel put string -f ${H}/consumer/config/app.toml .api.address "tcp://0.0.0.0:1318"
dasel put bool -f ${H}/consumer/config/app.toml .api.enable true
dasel put bool -f ${H}/consumer/config/app.toml .api.swagger true
dasel put bool -f ${H}/consumer/config/app.toml .api.enabled-unsafe-cors true

# Start consumer
$CBIN start\
    --home ${H}/consumer \
    --address tcp://${CADDR} \
    --rpc.laddr tcp://${CRPCLADDR} \
    --grpc.address ${CGRPCADDR} \
    --p2p.laddr tcp://${CP2PLADDR} \
    --grpc-web.enable=false \
    &> ${H}/consumer/logs &