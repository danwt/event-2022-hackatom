#!/bin/bash
set -eux 

# Amount on genesis
ACC_AMT="1000000000000stake"
# Amount to self delegate
FIZZ_SELF_DELEGATE_AMT="1000000000stake"
OTHER_SELF_DELEGATE_AMT="90000000stake"
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

HANDLE=$1

### PROVIDER

# Init new node directory
$PBIN init --chain-id provider $HANDLE --home ${H}/p

# Create a keypair ($HANDLE is key name)
$PBIN keys\
    add $HANDLE \
    --home ${H}/p \
    --keyring-backend test\
    --output json\
    > buzz_keypair_p.json 2>&1

# Get the provider genesis file
curl -o ${H}/p/config/genesis.json https://pastebin.com/<your-pastbin-genesis-dump>

MY_IP=$(host -4 myip.opendns.com resolver1.opendns.com | grep "address" | awk '{print $4}')

COORDINATOR_P2P_ADDRESS=$(jq -r '.app_state.genutil.gen_txs[0].body.memo' ${H}/p/config/genesis.json)

# Start the node
# If you get the error "can't bind address xxx.xxx.x.x"
# try using `127.0.0.1` instead.
$PBIN start\
    --home ${H}/p \
    --address tcp://${MY_IP}:26655 \
    --rpc.laddr tcp://${MY_IP}:26658 \
    --grpc.address ${MY_IP}:9091 \
    --p2p.laddr tcp://${MY_IP}:26656 \
    --grpc-web.enable=false \
    --p2p.persistent_peers $COORDINATOR_P2P_ADDRESS \
    &> ${H}/p/logs &

# TODO: can this go BEFORE start?
# TODO: original comment 'Update the node client RPC endpoint using the following command'
dasel put string -f ${H}/p/config/client.toml node "tcp://${PRPCLADDR}"

# Fund your account

# TODO: send over from god address

# Make sure your node account has at least `1000000stake` coins in order to stake.
# Verify your account balance using the command below.
$PBIN q\
    bank balances $(jq -r .address buzz_keypair_p.json)\
    --home ${H}/p

# Ask to get your local account fauceted or use the command below if you have access
# to another account at least extra `1000000stake` tokens.*

# Get local account addresses
ACCOUNT_ADDR=$($PBIN keys show $HANDLE \
       --home /${H}/p --output json | jq '.address')

# Run this command 
$PBIN tx bank send\
  <source-address> $ACCOUNT_ADDR \
  1000000stake\
  --from <source-keyname>\
  --home ${H}/p\
  --chain-id provider\
  -b block 

# Get the validator node pubkey 
VAL_PUBKEY=$($PBIN tendermint show-validator --home ${H}/p)

# Create the validator
$PBIN tx staking create-validator \
  --amount 1000000stake \
  --pubkey $VAL_PUBKEY \
  --moniker $HANDLE \
  --from $HANDLE \
  --keyring-backend test \
  --home ${H}/p \
  --chain-id provider \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.2 \
  --commission-rate 0.1 \
  --min-self-delegation 1 \
  -b block -y

# Verify that your validator node is now part of the validator-set.

$PBIN q tendermint-validator-set --home ${H}/p

### CONSUMER ###

rm -rf ${H}/c 

# Init new node directory
$CBIN init\
    $HANDLE\
    --chain-id consumer\
    --home ${H}/c

sleep 1

# Create user account keypair (reuse name)
$CBIN keys add $HANDLE\
    --home ${H}/c\
    --keyring-backend test\
    --output json\
     > ${H}/buzz_keypair_c.json 2>&1

# Import Consumer chain genesis file__
#    as explained in the provider chain section point 5 .
# TODO:???

# Copy validator keys to consumer directory
cp ${H}/p/config/node_key.json ${H}/c/config/node_key.json
cp ${H}/p/config/priv_validator_key.json ${H}/c/config/priv_validator_key.json

# Get persistent peer address
COORDINATOR_P2P_ADDRESS=$(jq -r '.app_state.genutil.gen_txs[0].body.memo' ${H}/p/config/genesis.json)

CONSUMER_P2P_ADDRESS=$(echo $COORDINATOR_P2P_ADDRESS | sed 's/:.*/:26646/')

# Start the node
$CBIN start\
    --home ${H}/c \
    --address tcp://${MY_IP}:26645 \
    --rpc.laddr tcp://${MY_IP}:26648 \
    --grpc.address ${MY_IP}:9081 \
    --p2p.laddr tcp://${MY_IP}:26646 \
    --grpc-web.enable=false \
    --p2p.persistent_peers $CONSUMER_P2P_ADDRESS \
    &> ${H}/c/logs &

# TODO: can this go BEFORE start?
# TODO: original comment 'Update the node client RPC endpoint using the following command'
dasel put string -f ${H}/c/config/client.toml node "tcp://${CRPCLADDR}"

# Check consumer validator set
$CBIN q tendermint-validator-set --home ${H}/c