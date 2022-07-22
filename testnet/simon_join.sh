
# Init new node directory
interchain-securityd init <prov-node-moniker> --chain-id provider --home <prov-node-dir>

# Generate a new keypair
interchain-security-pd keys add <provider-keyname> --home <prov-node-dir> --keyring-backend test --output json > <provider_keyname_keypair>.json 2>&1

# Get the provider genesis file
curl -o <prov-node-dir>/config/genesis.json https://pastebin.com/<your-pastbin-genesis-dump>

MY_IP=$(host -4 myip.opendns.com resolver1.opendns.com | grep "address" | awk '{print $4}')

COORDINATOR_P2P_ADDRESS=$(jq -r '.app_state.genutil.gen_txs[0].body.memo' <prov-node-dir>/config/genesis.json)

# Run node
interchain-securityd start --home <prov-node-dir> \
        --rpc.laddr tcp://${MY_IP}:26658 \
        --grpc.address ${MY_IP}:9091 \
        --address tcp://${MY_IP}:26655 \
        --p2p.laddr tcp://${MY_IP}:26656 \
        --grpc-web.enable=false \
        --p2p.persistent_peers $COORDINATOR_P2P_ADDRESS \
        &> <prov-node-dir>/logs &

# If you get the error "can't bind address xxx.xxx.x.x"
# try using `127.0.0.1` instead.

# Setup the client RPC endpoint using the following command.
sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${MY_IP}:26658\"/" <prov-node-dir>/config/client.toml

# Fund your account
# Make sure your node account has at least `1000000stake` coins in order to stake.
# Verify your account balance using the command below.
interchain-security-pd q bank balances $(jq -r .address <provider-keyname>_keypair.json) --home <prov-node-dir>

* Ask to get your local account fauceted or use the command below if you have access to another account at least extra `1000000stake` tokens.*

# Get local account addresses
ACCOUNT_ADDR=$(interchain-security-pd keys show <your-keyname> \
       --home /<prov-node-dir> --output json | jq '.address')

# Run this command 
interchain-security-pd tx bank send <source-address> <destination-address> \
        1000000stake --from <source-keyname> --home /<prov-node-dir> --chain-id provider -b block 
  
# Bond your local node as a validator by sending the following transaction.

# Get the validator node pubkey 
VAL_PUBKEY=$(interchain-security-pd tendermint show-validator --home <prov-node-dir>)

# Create the validator
interchain-security-pd tx staking create-validator \
            --amount 1000000stake \
            --pubkey $VAL_PUBKEY \
            --from <provider-keyname> \
            --keyring-backend test \
            --home <prov-node-dir> \
            --chain-id provider \
            --commission-max-change-rate 0.01 \
            --commission-max-rate 0.2 \
            --commission-rate 0.1 \
            --moniker <prov-node-moniker> \
            --min-self-delegation 1 \
            -b block -y

# Verify that your validator node is now part of the validator-set.

interchain-security-pd q tendermint-validator-set --home <prov-node-dir>

### Run a validator on the Consumer chain
#The following steps will explain you how to configure and run a validator node for joining the Consumer chain.  

rm -rf <cons-node-dir>

# Create the node directory

# This command generates the required node directory stucture along with the intial genesis file.
interchain-security-cd init <cons-node-moniker> --chain-id consumer --home <cons-node-dir>

# Generate a node keypair
# This command create a keypair for the consumer node.
interchain-security-cd keys add <consumer-keyname> \
    --home <cons-node-dir> --output json > <consumer_keyname_keypair>.json 2>&1

# Import Consumer chain genesis file__
# Import the consumer genesis file to your local node folder as explained in the provider chain section point 5 .

# Import validator keypair node__ 
# The following will copy the required validator keypair files in order to run the same node on the consumer chain.  

cp <prov-node-dir>/config/node_key.json <cons-node-dir>/config/node_key.json

cp <prov-node-dir>/config/priv_validator_key.json <cons-node-dir>/config/priv_validator_key.json

# Run the validator node
# This command will run the validator on the consumer chain.  

# Get persistent peer address
COORDINATOR_P2P_ADDRESS=$(jq -r '.app_state.genutil.gen_txs[0].body.memo' <prov-node-dir>/config/genesis.json)

CONSUMER_P2P_ADDRESS=$(echo $COORDINATOR_P2P_ADDRESS | sed 's/:.*/:26646/')

interchain-security-cd start --home <cons-node-dir> \
        --rpc.laddr tcp://${MY_IP}:26648 \
        --grpc.address ${MY_IP}:9081 \
        --address tcp://${MY_IP}:26645 \
        --p2p.laddr tcp://${MY_IP}:26646 \
        --grpc-web.enable=false \
        --p2p.persistent_peers $CONSUMER_P2P_ADDRESS \
        &> <cons-node-dir>/logs &

# Query the consumer chain node__
# Update the node client RPC endpoint using the following command.  

sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${MY_IP}:26648\"/" <cons-node-dir>/config/client.toml

# Query the consumer chain and check that the validator node was added to the validator set.

interchain-security-cd q tendermint-validator-set --home <cons-node-dir>

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





