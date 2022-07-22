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

### EXTRA ACTIONS ###

EXTRA_DELEGATE_AMT="8000000stake"

$PBIN q tendermint-validator-set --home ${H}/p
$CBIN q tendermint-validator-set --home ${H}/c

DELEGATIONS=$($PBIN q staking delegations \
	$(jq -r .address fizz_keypair_p.json) \
	--home ${H}/p -o json)

echo $DELEGATIONS

OPERATOR_ADDR=$(echo $DELEGATIONS | jq -r .delegation_responses[0].delegation.validator_address)

# delegate some more tokens to see power change
$PBIN tx staking delegate $OPERATOR_ADDR $EXTRA_DELEGATE_AMT \
    --from fizz \
    --chain-id provider \
    --home ${H}/p \
    --keyring-backend test \
    -y -b block

sleep 13

$PBIN q tendermint-validator-set --home ${H}/p
$CBIN q tendermint-validator-set --home ${H}/c