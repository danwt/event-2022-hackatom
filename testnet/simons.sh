#!/bin/bash
set -eux 

# User balance of stake tokens 
USER_COINS="100000000000stake"
# Amount of stake tokens staked
STAKE="100000000stake"
# Node IP address
NODE_IP="127.0.0.1"

# Home directory
HOME_DIR="."


# Clean start
killall interchain-security-pd &> /dev/null || true
rm -rf ${HOME_DIR}/provider

# Build genesis file and node directory structure
interchain-security-pd init --chain-id provider simon --home ${HOME_DIR}/provider
jq ".app_state.gov.voting_params.voting_period = \"3s\"" \
   ${HOME_DIR}/provider/config/genesis.json > \
   ${HOME_DIR}/provider/edited_genesis.json && mv ${HOME_DIR}/provider/edited_genesis.json ${HOME_DIR}/provider/config/genesis.json
sleep 1

# jq condition to reduce unbonding time
#  | .app_state.staking.params.unbonding_time = \"600s\"


# Create account keypair
interchain-security-pd keys add simon --home ${HOME_DIR}/provider --keyring-backend test --output json > simon_keypair.json 2>&1
sleep 1

# Add stake to user
interchain-security-pd add-genesis-account $(jq -r .address simon_keypair.json) $USER_COINS --home ${HOME_DIR}/provider --keyring-backend test
sleep 1


# Stake 1/1000 user's coins
interchain-security-pd gentx simon $STAKE --chain-id provider --home ${HOME_DIR}/provider --keyring-backend test --moniker simon
sleep 1

interchain-security-pd collect-gentxs --home ${HOME_DIR}/provider --gentx-dir ${HOME_DIR}/provider/config/gentx/
sleep 1

sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${NODE_IP}:26658\"/" ${HOME_DIR}/provider/config/client.toml
sed -i -r 's/timeout_commit = "5s"/timeout_commit = "3s"/g' ${HOME_DIR}/provider/config/config.toml
sed -i -r 's/timeout_propose = "3s"/timeout_propose = "1s"/g' ${HOME_DIR}/provider/config/config.toml


# Start gaia
interchain-security-pd start --home ${HOME_DIR}/provider --rpc.laddr tcp://${NODE_IP}:26658 --grpc.address $NODE_IP:9091 \
 --address tcp://${NODE_IP}:26655 --p2p.laddr tcp://${NODE_IP}:26656 --grpc-web.enable=false &> ${HOME_DIR}/provider/logs &

sleep 5

# Build consumer chain proposal file
tee ${HOME_DIR}/consumer-proposal.json<<EOF
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

interchain-security-pd keys show simon --keyring-backend test --home ${HOME_DIR}/provider


# Submit consumer chain proposal
interchain-security-pd tx gov submit-proposal create-consumer-chain ${HOME_DIR}/consumer-proposal.json --chain-id provider --from simon --home ${HOME_DIR}/provider --node tcp://${NODE_IP}:26658  --keyring-backend test -b block -y

sleep 1

# Vote yes to proposal
interchain-security-pd tx gov vote 1 yes --from simon --chain-id provider --home ${HOME_DIR}/provider -b block -y --keyring-backend test
sleep 5

## CONSUMER CHAIN ##

# Clean start
killall interchain-security-cd &> /dev/null || true
rm -rf ${HOME_DIR}/consumer

# Build genesis file and node directory structure
interchain-security-cd init --chain-id consumer simon --home ${HOME_DIR}/consumer
sleep 1

# Create user account keypair
interchain-security-cd keys add simon --home ${HOME_DIR}/consumer --keyring-backend test --output json > ${HOME_DIR}/simon_cons_keypair.json 2>&1

# Add stake to user account
interchain-security-cd add-genesis-account $(jq -r .address simon_cons_keypair.json)  1000000000stake --home ${HOME_DIR}/consumer

# Add consumer genesis states to genesis file
interchain-security-pd query provider consumer-genesis consumer --home ${HOME_DIR}/provider -o json > ${HOME_DIR}/consumer_gen.json
jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]' ${HOME_DIR}/consumer/config/genesis.json ${HOME_DIR}/consumer_gen.json > ${HOME_DIR}/consumer/edited_genesis.json && mv ${HOME_DIR}/consumer/edited_genesis.json ${HOME_DIR}/consumer/config/genesis.json
rm ${HOME_DIR}/consumer_gen.json

jq ".app_state.gov.voting_params.voting_period = \"3s\" | .app_state.staking.params.unbonding_time = \"600s\"" \
	   ${HOME_DIR}/consumer/config/genesis.json > \
	   ${HOME_DIR}/consumer/edited_genesis.json && mv ${HOME_DIR}/consumer/edited_genesis.json ${HOME_DIR}/consumer/config/genesis.json

# Create validator states
echo '{"height": "0","round": 0,"step": 0}' > ${HOME_DIR}/consumer/data/priv_validator_state.json

# Copy validator key files
cp ${HOME_DIR}/provider/config/priv_validator_key.json ${HOME_DIR}/consumer/config/priv_validator_key.json
cp ${HOME_DIR}/provider/config/node_key.json ${HOME_DIR}/consumer/config/node_key.json

# Set default client port
sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${NODE_IP}:26648\"/" ${HOME_DIR}/consumer/config/client.toml

# Start giaia
interchain-security-cd start --home ${HOME_DIR}/consumer \
        --rpc.laddr tcp://${NODE_IP}:26648 \
        --grpc.address ${NODE_IP}:9081 \
        --address tcp://${NODE_IP}:26645 \
        --p2p.laddr tcp://${NODE_IP}:26646 \
        --grpc-web.enable=false \
        &> ${HOME_DIR}/consumer/logs &

sleep 3

# Setup Hermes in packet relayer mode
killall hermes 2> /dev/null || true

tee ~/.hermes/config.toml<<EOF
[global]
log_level = "info"

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
account_prefix = "cosmos"
clock_drift = "5s"
gas_adjustment = 0.1
grpc_addr = "tcp://${NODE_IP}:9081"
id = "consumer"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${NODE_IP}:26648"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "14days"
websocket_addr = "ws://${NODE_IP}:26648/websocket"

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
grpc_addr = "tcp://${NODE_IP}:9091"
id = "provider"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${NODE_IP}:26658"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "14days"
websocket_addr = "ws://${NODE_IP}:26658/websocket"

[chains.gas_price]
       denom = "stake"
       price = 0.00

[chains.trust_threshold]
       denominator = "3"
       numerator = "1"
EOF

# Delete all previous keys in relayer
hermes keys delete consumer -a
hermes keys delete provider -a

# Restore keys to hermes relayer
hermes keys restore --mnemonic  "$(jq -r .mnemonic simon_cons_keypair.json)" consumer
hermes keys restore --mnemonic  "$(jq -r .mnemonic simon_keypair.json)" provider

sleep 5

hermes create connection consumer --client-a 07-tendermint-0 --client-b 07-tendermint-0
hermes create channel consumer --port-a consumer --port-b provider -o ordered --channel-version 1 connection-0

sleep 5

hermes -j start &> ~/.hermes/logs &

interchain-security-pd q tendermint-validator-set --home ${HOME_DIR}/provider
interchain-security-cd q tendermint-validator-set --home ${HOME_DIR}/consumer

DELEGATIONS=$(interchain-security-pd q staking delegations \
	$(jq -r .address simon_keypair.json) \
	--home ${HOME_DIR}/provider -o json)

OPERATOR_ADDR=$(echo $DELEGATIONS | jq -r .delegation_responses[0].delegation.validator_address)

interchain-security-pd tx staking delegate $OPERATOR_ADDR 1000000stake \
       	--from simon \
       	--keyring-backend test \
       	--home ${HOME_DIR}/provider \
       	--chain-id provider \
	-y -b block

sleep 13

interchain-security-pd q tendermint-validator-set --home ${HOME_DIR}/provider
interchain-security-cd q tendermint-validator-set --home ${HOME_DIR}/consumer


# rm -rf ${HOME_DIR}/provider2
# interchain-security-pd init --chain-id provider rick --home ${HOME_DIR}/provider2
# interchain-security-pd keys add rick --home ${HOME_DIR}/provider2 --keyring-backend test --output json > rick_keypair.json 2>&1
# cp ${HOME_DIR}/provider/config/genesis.json ${HOME_DIR}/provider2/config/genesis.json
# echo '{"height": "0","round": 0,"step": 0}' > ${HOME_DIR}/provider2/data/priv_validator_state.json

# sed -i -r "/node =/ s/= .*/= \"tcp:\/\/${NODE_IP}:26638\"/" ${HOME_DIR}/provider2/config/client.toml

# NODE_SIMON_ID=$(interchain-security-pd tendermint show-node-id --home ${HOME_DIR}/provider)
# interchain-security-pd start --home ${HOME_DIR}/provider2 \
#         --rpc.laddr tcp://${NODE_IP}:26638 \
#         --grpc.address ${NODE_IP}:9071 \
#         --address tcp://${NODE_IP}:26635 \
#         --p2p.laddr tcp://${NODE_IP}:26636 \
#         --grpc-web.enable=false \
#         --p2p.persistent_peers ${NODE_SIMON_ID}@${NODE_IP}:26656 \
#         &> ${HOME_DIR}/provider2/logs &


# sleep 5
# interchain-security-pd tx bank send $(jq -r .address simon_keypair.json) $(jq -r .address rick_keypair.json) 10000000stake --from simon --home ${HOME_DIR}/provider --chain-id provider --keyring-backend test -y -b block
# interchain-security-pd q bank balances $(jq -r .address rick_keypair.json) --home ${HOME_DIR}/provider

# VAL_PUBKEY=$(interchain-security-pd tendermint show-validator --home ${HOME_DIR}/provider2)
interchain-security-pd tx staking create-validator \
            --amount 10000000stake \
            --pubkey $VAL_PUBKEY \
            --from simon \
            --keyring-backend test \
            --home ./provider \
            --chain-id provider \
            --commission-max-change-rate 0.01 \
            --commission-max-rate 0.2 \
            --commission-rate 0.1 \
            --moniker rick \
            --min-self-delegation 1 \
            --node tcp://${NODE_IP}:26658 \
            -b block -y

# hermes clear packets provider parent channel-0

# interchain-security-pd q tendermint-validator-set --home ${HOME_DIR}/provider
# interchain-security-pd q tendermint-validator-set --home ${HOME_DIR}/provider2
# interchain-security-pd q tendermint-validator-set --home ${HOME_DIR}/consumer


# interchain-security-pd tx bank send cosmos1yeyj3s7y2zpaevjts7qeeyrg8nhguqs9ng5z77 \
#        	cosmos1sttpmvka63zjltd5xh834m3mft3elhw67qn8ul \
# 	10000000stake \
# 	--from simon \
# 	--home ${HOME_DIR}/provider \
#        	--chain-id provider \
#        	--keyring-backend test -y -b block