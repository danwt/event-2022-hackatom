#!/bin/bash
set -eux 

TOTAL_COINS=100000000000stake
STAKE_COINS=100000000stake
PROVIDER_BINARY=interchain-security-pd
PROVIDER_HOME=$HOME/.tool_provider
PROVIDER_CHAIN_ID=provider
PROVIDER_MONIKER=provider
VALIDATOR=validator
NODE_IP="localhost"
PROVIDER_RPC_LADDR="$NODE_IP:26658"
PROVIDER_GRPC_ADDR="$NODE_IP:9091"

# Clean start
killall $PROVIDER_BINARY &> /dev/null || true
rm -rf $PROVIDER_HOME

./$PROVIDER_BINARY init $PROVIDER_MONIKER --home $PROVIDER_HOME --chain-id $PROVIDER_CHAIN_ID
jq ".app_state.gov.voting_params.voting_period = \"3s\" | .app_state.staking.params.unbonding_time = \"600s\" | .app_state.provider.params.template_client.trusting_period = \"300s\"" \
   $PROVIDER_HOME/config/genesis.json > \
   $PROVIDER_HOME/edited_genesis.json && mv $PROVIDER_HOME/edited_genesis.json $PROVIDER_HOME/config/genesis.json
sleep 1

# Create account keypair
./$PROVIDER_BINARY keys add $VALIDATOR --home $PROVIDER_HOME --keyring-backend test --output json > $PROVIDER_HOME/keypair.json 2>&1
sleep 1

# Add stake to user
./$PROVIDER_BINARY add-genesis-account $(jq -r .address $PROVIDER_HOME/keypair.json) $TOTAL_COINS --home $PROVIDER_HOME --keyring-backend test
sleep 1

# Stake 1/1000 user's coins
./$PROVIDER_BINARY gentx $VALIDATOR $STAKE_COINS --chain-id $PROVIDER_CHAIN_ID --home $PROVIDER_HOME --keyring-backend test --moniker $VALIDATOR
sleep 1

./$PROVIDER_BINARY collect-gentxs --home $PROVIDER_HOME --gentx-dir $PROVIDER_HOME/config/gentx/
sleep 1

# Start the chain
./$PROVIDER_BINARY start \
	--home $PROVIDER_HOME \
	--rpc.laddr tcp://$PROVIDER_RPC_LADDR \
	--grpc.address $PROVIDER_GRPC_ADDR \
	--address tcp://${NODE_IP}:26655 \
	--p2p.laddr tcp://${NODE_IP}:26656 \
	--grpc-web.enable=false &> $PROVIDER_HOME/logs &
sleep 10

# Build consumer chain proposal file
tee $PROVIDER_HOME/consumer-proposal.json<<EOF
{
    "title": "Create a chain",
    "description": "Gonna be a great chain",
    "chain_id": "wasm",
    "initial_height": {
        "revision_number": 0,
        "revision_height": 4
    },
    "genesis_hash": "8beb03cf0d59d5c77f0521eaf169311f7ea442ca55894c9c9b8bc58d52806e7a",
    "binary_hash": "f3414a11bf4ef5dbd1e65fa341d1ece5d8b7b139f648edd0d2513e4c168a859d",
    "spawn_time": "2022-06-01T09:10:00.000000000-00:00", 
    "deposit": "10000001stake"
}
EOF

./$PROVIDER_BINARY tx gov submit-proposal create-consumer-chain $PROVIDER_HOME/consumer-proposal.json \
	--chain-id $PROVIDER_CHAIN_ID --node tcp://$PROVIDER_RPC_LADDR --from $VALIDATOR --home $PROVIDER_HOME --keyring-backend test -b block -y
sleep 1

# Vote yes to proposal
./$PROVIDER_BINARY tx gov vote 1 yes --from $VALIDATOR --chain-id $PROVIDER_CHAIN_ID --node tcp://$PROVIDER_RPC_LADDR --home $PROVIDER_HOME -b block -y --keyring-backend test
sleep 5
