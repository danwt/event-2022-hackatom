#!/bin/bash
set -eux

# bash temp_start_consumer.sh $HOME/genesis.json $HOME/.tool_provider

CONSUMER_HOME="$HOME/.interchain-security-cd"
PROVIDER_CHAIN_ID="provider"
CONSUMER_CHAIN_ID="wasm"
MONIKER="testnet"
VALIDATOR="validator"
KEYRING="--keyring-backend test"
STAKE="100000000stake"
TX_FLAGS="--gas-adjustment 100 --gas auto"
PROVIDER_BINARY="interchain-security-pd"
CONSUMER_BINARY="wasmd_consumer"
NODE_IP="localhost"
PROVIDER_RPC_LADDR="$NODE_IP:26658"
PROVIDER_GRPC_ADDR="$NODE_IP:9091"
CONSUMER_RPC_LADDR="$NODE_IP:26648"
CONSUMER_GRPC_ADDR="$NODE_IP:9081"
CONSUMER_USER="consumer"
CONTRACT_ADMIN="admin"
CONSUMER_GENESIS=$1
PROVIDER_HOME=$2

# Clean start
killall $CONSUMER_BINARY &> /dev/null || true
rm -rf $CONSUMER_HOME

################CONSUMER############################

# Build genesis file and node directory structure
$CONSUMER_BINARY init --chain-id $CONSUMER_CHAIN_ID $MONIKER --home $CONSUMER_HOME
sleep 1

# Copy input genesis to the consumer config folder
cp $CONSUMER_GENESIS $CONSUMER_HOME/config/genesis.json

# Create user account keypair
./$CONSUMER_BINARY keys add $CONSUMER_USER $KEYRING --home $CONSUMER_HOME --output json > $CONSUMER_HOME/consumer_keypair.json 2>&1

# Add stake to user account
./$CONSUMER_BINARY add-genesis-account $(jq -r .address $CONSUMER_HOME/consumer_keypair.json)  1000000000stake --home $CONSUMER_HOME

# Add account that was used during genesis.json creation by the tool so we can instantiate predeployed contracts
echo "fee million dune better provide wolf lend begin local aerobic glare sea visa tissue tumble pepper cream auction output glass peace blade gather kingdom" | ./$CONSUMER_BINARY keys add $CONTRACT_ADMIN $KEYRING --home $CONSUMER_HOME --recover
./$CONSUMER_BINARY add-genesis-account wasm1ykqt29d4ekemh5pc0d2wdayxye8yqupttf6vyz 1000000000stake --home $CONSUMER_HOME

# Copy validator key files
cp $PROVIDER_HOME/config/priv_validator_key.json $CONSUMER_HOME/config/priv_validator_key.json
cp $PROVIDER_HOME/config/node_key.json $CONSUMER_HOME/config/node_key.json

# Set default client port
sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${CONSUMER_RPC_LADDR}\"/" $CONSUMER_HOME/config/client.toml

# Start the chain
./$CONSUMER_BINARY start \
       --home $CONSUMER_HOME \
       --rpc.laddr tcp://${CONSUMER_RPC_LADDR} \
       --grpc.address ${CONSUMER_GRPC_ADDR} \
       --address tcp://${NODE_IP}:26645 \
       --p2p.laddr tcp://${NODE_IP}:26646 \
       --grpc-web.enable=false \
       --log_level trace \
       --trace \
       &> $CONSUMER_HOME/logs &
        
sleep 10

######################################HERMES###################################

# Setup Hermes in packet relayer mode
killall hermes 2> /dev/null || true

tee ~/.hermes/config.toml<<EOF
[global]
log_level = "trace"

[mode]

[mode.clients]
enabled = true
refresh = true
misbehaviour = true

[mode.connections]
enabled = false

[mode.channels]
enabled = false

[mode.packets]
enabled = true

[[chains]]
account_prefix = "wasm"
clock_drift = "5s"
gas_adjustment = 0.1
grpc_addr = "tcp://${CONSUMER_GRPC_ADDR}"
id = "$CONSUMER_CHAIN_ID"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${CONSUMER_RPC_LADDR}"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "599s"
websocket_addr = "ws://${CONSUMER_RPC_LADDR}/websocket"

[chains.gas_price]
       denom = "stake"
       price = 0.00

[chains.trust_threshold]
       denominator = "3"
       numerator = "1"

[[chains]]
account_prefix = "cosmos"
clock_drift = "5s"
gas_adjustment = 0.1
grpc_addr = "tcp://${PROVIDER_GRPC_ADDR}"
id = "$PROVIDER_CHAIN_ID"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${PROVIDER_RPC_LADDR}"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "599s"
websocket_addr = "ws://${PROVIDER_RPC_LADDR}/websocket"

[chains.gas_price]
       denom = "stake"
       price = 0.00

[chains.trust_threshold]
       denominator = "3"
       numerator = "1"
EOF

# Delete all previous keys in relayer
hermes keys delete $CONSUMER_CHAIN_ID -a
hermes keys delete $PROVIDER_CHAIN_ID -a

# Restore keys to hermes relayer
hermes keys restore --mnemonic "$(jq -r .mnemonic $CONSUMER_HOME/consumer_keypair.json)" $CONSUMER_CHAIN_ID
# temp_start_provider.sh creates key pair and stores it in keypair.json
hermes keys restore --mnemonic "$(jq -r .mnemonic $PROVIDER_HOME/keypair.json)" $PROVIDER_CHAIN_ID

sleep 5

hermes create connection $CONSUMER_CHAIN_ID --client-a 07-tendermint-0 --client-b 07-tendermint-0
hermes create channel $CONSUMER_CHAIN_ID --port-a consumer --port-b provider -o ordered --channel-version 1 connection-0

sleep 5

hermes -j start &> ~/.hermes/logs &

############################################################

DELEGATIONS=$($PROVIDER_BINARY q staking delegations $(jq -r .address $PROVIDER_HOME/keypair.json) --home $PROVIDER_HOME --node tcp://${PROVIDER_RPC_LADDR} -o json)
OPERATOR_ADDR=$(echo $DELEGATIONS | jq -r .delegation_responses[0].delegation.validator_address)

./$PROVIDER_BINARY tx staking delegate $OPERATOR_ADDR 50000000stake \
       --from validator \
       $KEYRING \
       --home $PROVIDER_HOME \
       --node tcp://${PROVIDER_RPC_LADDR} \
       --chain-id $PROVIDER_CHAIN_ID -y -b block

# echo "Consumer chain validator set after delegation:"
# $CONSUMER_BINARY q tendermint-validator-set --home $CONSUMER_HOME --node tcp://$CONSUMER_RPC_LADDR
