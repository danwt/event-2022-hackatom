### Test the CCV protocol
# These optional steps show you how CCV updates the Consumer 
# chain validator-set voting power. In order to do so, we will delegate some tokens
# to the validator on the Provider chain and verify that the Consumer
# chain validator-set gets updated.

# Delegate tokens
# Get validator delegations
DELEGATIONS=$(interchain-security-pd q staking delegations \
    $(jq -r .address <provider-keyname>_keypair.json) --home <prov-node-dir> -o json)

# Get validator operator address
OPERATOR_ADDR=$(echo $DELEGATIONS | jq -r '.delegation_responses[0].delegation.validator_address')

# Delegate tokens
interchain-security-pd tx staking delegate $OPERATOR_ADDR 1000000stake \
                --from <provider-keyname> \
                --keyring-backend test \
                --home <prov-node-dir> \
                --chain-id provider \
                -y -b block

# Check the validator set

# Get validator consensus address
VAL_ADDR=$(interchain-security-pd tendermint show-address --home <prov-node-dir>)
        
# Query validator consenus info        
interchain-security-cd q tendermint-validator-set --home <cons-node-dir> | grep -A11 $VAL_ADDR
