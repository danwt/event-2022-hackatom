#!/bin/bash
set -eux 

HANDLE=$1

if [ "$HANDLE" == "" ]; then
   echo "Must provid handle as first arg."
   exit 1
fi

# Home directory
H="."
PDIR=${H}/p_${HANDLE}
CDIR=${H}/c_${HANDLE}
PBIN=interchain-security-pd
CBIN=interchain-security-cd

# Node IP address
NODE_IP="127.0.0.2"

# ip addr add $NODE_IP dev etho0 || true # allowed to fail

PADDR="${NODE_IP}:26655"
PRPCLADDR="${NODE_IP}:26658"
PGRPCADDR="${NODE_IP}:9091"
PP2PLADDR="${NODE_IP}:26656"
CADDR="${NODE_IP}:26645"
CRPCLADDR="${NODE_IP}:26648"
CGRPCADDR="${NODE_IP}:9081"
CP2PLADDR="${NODE_IP}:26646"

# Cleanup
rm -rf $PDIR
rm -rf $CDIR
rm -f *_${HANDLE}.json

$PBIN keys\
    delete $HANDLE \
    --home $PDIR \
    --keyring-backend test\
    --output json\
    || true

### PROVIDER

# Init new node directory
$PBIN init --chain-id provider $HANDLE --home $PDIR

sleep 1

# Create a keypair ($HANDLE is key name)
$PBIN keys\
    add $HANDLE \
    --home $PDIR \
    --keyring-backend test\
    --output json\
    > keypair_p_${HANDLE}.json 2>&1

sleep 1

# TODO:  - not sure if I need this
echo '{"height": "0","round": 0,"step": 0}' > $PDIR/data/priv_validator_state.json

# Get the provider genesis file
cp ${H}/p/config/genesis.json $PDIR/config/genesis.json

COORDINATOR_P2P_ADDRESS=$(jq -r '.app_state.genutil.gen_txs[0].body.memo' $PDIR/config/genesis.json)

echo $COORDINATOR_P2P_ADDRESS

# Start the node
# If you get the error "can't bind address xxx.xxx.x.x"
# try using `127.0.0.1` instead.
$PBIN start\
    --home $PDIR \
    --address tcp://${PADDR}\
    --rpc.laddr tcp://${PRPCLADDR}\
    --grpc.address ${PGRPCADDR}\
    --p2p.laddr tcp://${PP2PLADDR}\
    --grpc-web.enable=false \
    --p2p.persistent_peers $COORDINATOR_P2P_ADDRESS \
    &> $PDIR/logs &

# TODO: can this go BEFORE start?
# TODO: original comment 'Update the node client RPC endpoint using the following command'
dasel put string -f $PDIR/config/client.toml node "tcp://${PRPCLADDR}"

sleep 5

# poll for chain start
set +e
until $CBIN query block --node "tcp://${PRPCLADDR}" | grep -q -v '{"block_id":{"hash":"","parts":{"total":0,"hash":""}},"block":null}'; do sleep 0.3 ; done
set -e

# Get fizz account addresses
# TODO: parameterise

SRC_ADDR=$(dasel --plain -f keypair_p_fizz.json .address)
DST_ADDR=$(dasel --plain -f keypair_p_buzz.json .address)

# Get some tokens
$PBIN tx bank send\
    $SRC_ADDR $DST_ADDR \
    1000000stake\
    --from fizz\
    --home ${H}/p \
    --chain-id provider\
    --keyring-backend test \
    -b block\
    -y

sleep 4

# Get the validator node pubkey 
VAL_PUBKEY=$($PBIN tendermint show-validator --home $PDIR)

# Create the validator
$PBIN tx staking create-validator \
    --amount 1000000stake \
    --pubkey $VAL_PUBKEY \
    --moniker $HANDLE \
    --from $HANDLE \
    --keyring-backend test \
    --home $PDIR \
    --chain-id provider \
    --commission-max-change-rate 0.01 \
    --commission-max-rate 0.2 \
    --commission-rate 0.1 \
    --min-self-delegation 1 \
    -b block\
    -y

sleep 6

# Verify that your validator node is now part of the validator-set.

$PBIN q tendermint-validator-set --home ${H}/p

### CONSUMER ###

# Init new node directory
$CBIN init\
    $HANDLE\
    --chain-id consumer\
    --home $CDIR

sleep 1

# Create user account keypair (reuse name)
$CBIN keys add $HANDLE\
    --home $CDIR\
    --keyring-backend test\
    --output json\
    > ${H}/keypair_c_${HANDLE}.json 2>&1

# Get the provider genesis file
cp ${H}/p/config/genesis.json $CDIR/config/genesis.json
# Copy validator keys to consumer directory
cp ${H}/p/config/node_key.json $CDIR/config/node_key.json
cp ${H}/p/config/priv_validator_key.json $CDIR/config/priv_validator_key.json

# Get persistent peer address
COORDINATOR_P2P_ADDRESS=$(jq -r '.app_state.genutil.gen_txs[0].body.memo' $PDIR/config/genesis.json)

CONSUMER_P2P_ADDRESS=$(echo $COORDINATOR_P2P_ADDRESS | sed 's/:.*/:26646/')


# Start the node
$CBIN start\
    --home $CDIR \
    --address tcp://${CADDR} \
    --rpc.laddr tcp://${CRPCLADDR} \
    --grpc.address ${CGRPCADDR} \
    --p2p.laddr tcp://${CP2PLADDR} \
    --grpc-web.enable=false \
    --p2p.persistent_peers $CONSUMER_P2P_ADDRESS \
    &> $CDIR/logs &

sleep 5

# TODO: can this go BEFORE start?
# TODO: original comment 'Update the node client RPC endpoint using the following command'
dasel put string -f $CDIR/config/client.toml node "tcp://${CRPCLADDR}"

# Check consumer validator set
$CBIN q tendermint-validator-set --home $CDIR