#!/bin/bash
set -eux 

# Home directory
H="."
PDIR=${H}/p
CDIR=${H}/c
PBIN=interchain-security-pd
CBIN=interchain-security-cd

HANDLE=fizz

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

# Amount on genesis
ACC_AMT="1000000000000stake"
# Amount to self delegate
SELF_DEL_AMT="1000000000stake"

### PROVIDER CHAIN ###

# Build genesis file and node directory structure ($HANDLE is node moniker)
$PBIN init --chain-id provider $HANDLE --home $PDIR

dasel put string -f $PDIR/config/genesis.json\
    .app_state.gov.voting_params.voting_period "3s"

sleep 1

# Create a keypair ($HANDLE is key name)
$PBIN keys\
    add $HANDLE \
    --home $PDIR \
    --keyring-backend test\
    --output json\
    > keypair_p_${HANDLE}.json 2>&1

sleep 1

# Create an account with some coins ($HANDLE is key name)
$PBIN add-genesis-account\
    $HANDLE $ACC_AMT\
    --home $PDIR \
    --keyring-backend test

sleep 1

# Create a validator using the $HANDLE key, and self-delegate
# some coins. (here $HANDLE is a keyname and the moniker for the
# new validator)
$PBIN gentx $HANDLE $SELF_DEL_AMT\
    --moniker $HANDLE \
    --chain-id provider\
    --home $PDIR\
    --keyring-backend test

sleep 1

# Collect the genesis transactions and create the genesis file
$PBIN collect-gentxs\
    --home $PDIR\
    --gentx-dir $PDIR/config/gentx/

sleep 1

# Configure tendermint

dasel put string -f $PDIR/config/client.toml node "tcp://${PRPCLADDR}"
dasel put string -f $PDIR/config/config.toml consensus.timeout_commit 3s
dasel put string -f $PDIR/config/config.toml consensus.timeout_propose 1s

# Allow rest api queries to node (for explorer)

dasel put bool -f $PDIR/config/app.toml .api.enable true
dasel put bool -f $PDIR/config/app.toml .api.swagger true
dasel put bool -f $PDIR/config/app.toml .api.enabled-unsafe-cors true

# Start the provider chain
$PBIN start\
    --home $PDIR\
    --address tcp://${PADDR}\
    --rpc.laddr tcp://${PRPCLADDR}\
    --grpc.address ${PGRPCADDR}\
    --p2p.laddr tcp://${PP2PLADDR}\
    --grpc-web.enable=false\
    &> $PDIR/logs &

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

# Submit consumer chain proposal ($HANDLE is key name,
# node is the tendermint rpc endpoint for provider)
$PBIN tx gov submit-proposal create-consumer-chain\
    ${H}/proposal.json\
    --from $HANDLE\
    --node tcp://${PRPCLADDR}\
    --chain-id provider\
    --home $PDIR\
    --keyring-backend test\
    -b block\
    -y

sleep 1

# Vote yes to proposal (1 is proposal id, $HANDLE is key name)
$PBIN tx gov vote 1 yes\
    --from $HANDLE\
    --chain-id provider\
    --home $PDIR\
    --keyring-backend test\
    -b block\
    -y

sleep 5

### CONSUMER CHAIN ###

# Create default genesis file and node directory
# ($HANDLE is again a moniker here)
$CBIN init\
    $HANDLE\
    --chain-id consumer\
    --home $CDIR

sleep 1

# Create user account keypair (reuse $HANDLE name)
$CBIN keys add $HANDLE\
    --home $CDIR\
    --keyring-backend test\
    --output json\
    > ${H}/keypair_c_${HANDLE}.json 2>&1

# Create an account with some coins ($HANDLE is key name)
$CBIN add-genesis-account\
    $HANDLE $ACC_AMT\
    --home $CDIR \
    --keyring-backend test

# Fetch consumer genesis state from provider
# (provider is module name, consumer is a chain-id)
$PBIN query provider consumer-genesis consumer\
    --home $PDIR\
    -o json > ${H}/consumer_module_genesis_state.json

# Splice the module state exported by the provider into the consumer genesis
jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]'\
    $CDIR/config/genesis.json ${H}/consumer_module_genesis_state.json\
    > $CDIR/edited_genesis.json\
    && mv $CDIR/edited_genesis.json $CDIR/config/genesis.json

# Delete module state because no longer needed
rm ${H}/consumer_module_genesis_state.json

# Update consumer chain params
dasel put string -f $CDIR/config/genesis.json .app_state.gov.voting_params.voting_period 3s
dasel put string -f $CDIR/config/genesis.json .app_state.staking.params.unbonding_time 600s

# Copy validator key files from the provider to be used to sign consumer blocks.
# We need this because the provider exports a validator set which must be used
# to validate the first consumer block.
cp $PDIR/config/priv_validator_key.json $CDIR/config/priv_validator_key.json
cp $PDIR/config/node_key.json $CDIR/config/node_key.json

# Set default client port
dasel put string -f $CDIR/config/client.toml .node "tcp://${CRPCLADDR}"
dasel put string -f $CDIR/config/app.toml .api.address "tcp://0.0.0.0:1318"
dasel put bool -f $CDIR/config/app.toml .api.enable true
dasel put bool -f $CDIR/config/app.toml .api.swagger true
dasel put bool -f $CDIR/config/app.toml .api.enabled-unsafe-cors true

# Start consumer
$CBIN start\
    --home $CDIR \
    --address tcp://${CADDR} \
    --rpc.laddr tcp://${CRPCLADDR} \
    --grpc.address ${CGRPCADDR} \
    --p2p.laddr tcp://${CP2PLADDR} \
    --grpc-web.enable=false \
    &> $CDIR/logs &