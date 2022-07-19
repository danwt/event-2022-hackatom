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

# Setup Hermes in packet relayer mode

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
gas_multiplier = 1.1
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
gas_multiplier = 1.1
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
hermes keys delete --chain consumer --all
hermes keys delete --chain provider --all

# Restore keys to hermes relayer
# TODO: think I might need to use --mnemonic-file here
hermes keys add --key-file simon_cons_keypair.json --chain consumer
hermes keys add --key-file simon_keypair.json --chain provider

sleep 5

hermes create connection --a-chain consumer --a-client 07-tendermint-0 --b-client 07-tendermint-0
hermes create channel --a-chain consumer --a-port consumer --b-port provider --order ordered --channel-version 1 --a-connection connection-0

sleep 5

hermes -j start &> ~/.hermes/logs &

interchain-security-pd q tendermint-validator-set --home ${HOME_DIR}/provider
interchain-security-cd q tendermint-validator-set --home ${HOME_DIR}/consumer

DELEGATIONS=$(interchain-security-pd q staking delegations \
	$(jq -r .address simon_keypair.json) \
	--home ${HOME_DIR}/provider -o json)

echo $DE

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

VAL_PUBKEY=$(interchain-security-pd tendermint show-validator --home ${HOME_DIR}/provider2)
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