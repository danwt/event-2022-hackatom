#!/bin/bash
set -eux 

# Home directory
H="."
PDIR=${H}/p
CDIR=${H}/c
PBIN=interchain-security-pd
CBIN=interchain-security-cd

HANDLE=fizz

### EXTRA ACTIONS ###

EXTRA_DELEGATE_AMT="8000000stake"

$PBIN q tendermint-validator-set --home $PDIR
$CBIN q tendermint-validator-set --home $CDIR

DELEGATIONS=$($PBIN q staking delegations \
	$(jq -r .address keypair_p_${HANDLE}.json) \
	--home $PDIR -o json)

echo $DELEGATIONS

OPERATOR_ADDR=$(echo $DELEGATIONS | jq -r .delegation_responses[0].delegation.validator_address)

# delegate some more tokens to see power change
$PBIN tx staking delegate $OPERATOR_ADDR $EXTRA_DELEGATE_AMT \
    --from $HANDLE \
    --chain-id provider \
    --home $PDIR \
    --keyring-backend test \
    -y -b block

sleep 13

$PBIN q tendermint-validator-set --home $PDIR
$CBIN q tendermint-validator-set --home $CDIR