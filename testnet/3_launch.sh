#!/bin/bash
set -eux 

# User balance of stake tokens 
FIZZ_COINS_P="100000000000stake"
# User balance of stake tokens 
FIZZ_COINS_C="100000000000stake"
# Amount of stake tokens staked
STAKE_AMT="100000000stake"
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

./2_killAndClean.sh

### PROVIDER CHAIN ###

# Build genesis file and node directory structure (fizz is node moniker)
$PBIN init --chain-id provider fizz --home ${H}/p

dasel put string -f ${H}/p/config/genesis.json\
    .app_state.gov.voting_params.voting_period "3s"

sleep 1

# Create a keypair (fizz is key name)
$PBIN keys\
    add fizz \
    --home ${H}/p \
    --keyring-backend test\
    --output json\
    > fizz_keypair_p.json 2>&1

sleep 1

# Create an account with some coins (fizz is key name)
$PBIN add-genesis-account\
    fizz $FIZZ_COINS_P\
    --home ${H}/p \
    --keyring-backend test

sleep 1

# Create a validator using the fizz key, and self-delegate
# some coins. (here fizz is a keyname and the moniker for the
# new validator)
$PBIN gentx fizz $STAKE_AMT\
    --moniker fizz \
    --chain-id provider\
    --home ${H}/p\
    --keyring-backend test

sleep 1

# Collect the genesis transactions and create the genesis file
$PBIN collect-gentxs\
    --home ${H}/p\
    --gentx-dir ${H}/p/config/gentx/

sleep 1

# Configure tendermint

dasel put string -f ${H}/p/config/client.toml node "tcp://${PRPCLADDR}"
dasel put string -f ${H}/p/config/config.toml consensus.timeout_commit 3s
dasel put string -f ${H}/p/config/config.toml consensus.timeout_propose 1s

# Allow rest api queries to node (for explorer)

dasel put bool -f ${H}/p/config/app.toml .api.enable true
dasel put bool -f ${H}/p/config/app.toml .api.swagger true
dasel put bool -f ${H}/p/config/app.toml .api.enabled-unsafe-cors true

# Start the provider chain
$PBIN start\
    --home ${H}/p\
    --address tcp://${PADDR}\
    --rpc.laddr tcp://${PRPCLADDR}\
    --grpc.address ${PGRPCADDR}\
    --p2p.laddr tcp://${PP2PLADDR}\
    --grpc-web.enable=false\
    &> ${H}/p/logs &

sleep 5

# Create consumer chain proposal file
tee ${H}/proposal.json<<EOF
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

# Submit consumer chain proposal (fizz is key name,
# node is the tendermint rpc endpoint for provider)
$PBIN tx gov submit-proposal create-consumer-chain\
    ${H}/proposal.json\
    --from fizz\
    --node tcp://${PRPCLADDR}\
    --chain-id provider\
    --home ${H}/p\
    --keyring-backend test\
    -b block\
    -y

sleep 1

# Vote yes to proposal (1 is proposal id, fizz is key name)
$PBIN tx gov vote 1 yes\
    --from fizz\
    --chain-id provider\
    --home ${H}/p\
    --keyring-backend test\
    -b block\
    -y

sleep 5

### CONSUMER CHAIN ###

# Create default genesis file and node directory
# (fizz is again a moniker here)
$CBIN init\
    fizz\
    --chain-id consumer\
    --home ${H}/c

sleep 1

# Create user account keypair (reuse fizz name)
$CBIN keys add fizz\
    --home ${H}/c\
    --keyring-backend test\
    --output json\
    > ${H}/fizz_keypair_c.json 2>&1

# Create an account with some coins (fizz is key name)
$CBIN add-genesis-account\
    fizz $FIZZ_COINS_C\
    --home ${H}/c \
    --keyring-backend test

# Fetch consumer genesis state from provider
# (provider is module name, consumer is a chain-id)
$PBIN query provider consumer-genesis consumer\
    --home ${H}/p\
    -o json > ${H}/consumer_module_genesis_state.json

# Splice the module state exported by the provider into the consumer genesis
jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]'\
    ${H}/c/config/genesis.json ${H}/consumer_module_genesis_state.json\
    > ${H}/c/edited_genesis.json\
    && mv ${H}/c/edited_genesis.json ${H}/c/config/genesis.json

# Delete module state because no longer needed
rm ${H}/consumer_module_genesis_state.json

# Update consumer chain params
dasel put string -f ${H}/c/config/genesis.json .app_state.gov.voting_params.voting_period 3s
dasel put string -f ${H}/c/config/genesis.json .app_state.staking.params.unbonding_time 600s

# Copy validator key files from the provider to be used to sign consumer blocks.
# We need this because the provider exports a validator set which must be used
# to validate the first consumer block.
cp ${H}/p/config/priv_validator_key.json ${H}/c/config/priv_validator_key.json
cp ${H}/p/config/node_key.json ${H}/c/config/node_key.json

# Set default client port
dasel put string -f ${H}/c/config/client.toml .node "tcp://${CRPCLADDR}"
dasel put string -f ${H}/c/config/app.toml .api.address "tcp://0.0.0.0:1318"
dasel put bool -f ${H}/c/config/app.toml .api.enable true
dasel put bool -f ${H}/c/config/app.toml .api.swagger true
dasel put bool -f ${H}/c/config/app.toml .api.enabled-unsafe-cors true

# Start consumer
$CBIN start\
    --home ${H}/c \
    --address tcp://${CADDR} \
    --rpc.laddr tcp://${CRPCLADDR} \
    --grpc.address ${CGRPCADDR} \
    --p2p.laddr tcp://${CP2PLADDR} \
    --grpc-web.enable=false \
    &> ${H}/c/logs &