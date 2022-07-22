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

killall hermes 2> /dev/null || true

# Delete all previous keys in relayer
hermes keys delete --chain provider --all
hermes keys delete --chain consumer --all

### RELAYER ###

# Setup Hermes in packet relayer mode
# (warning: trusting period may need to be modified
#   if changing unbonding period)

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
grpc_addr = "tcp://${CGRPCADDR}"
id = "consumer"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${CRPCLADDR}"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "14days"
websocket_addr = "ws://${CRPCLADDR}/websocket"

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
grpc_addr = "tcp://${PGRPCADDR}"
id = "provider"
key_name = "relayer"
max_gas = 2000000
rpc_addr = "http://${PRPCLADDR}"
rpc_timeout = "10s"
store_prefix = "ibc"
trusting_period = "14days"
websocket_addr = "ws://${PRPCLADDR}/websocket"

[chains.gas_price]
       denom = "stake"
       price = 0.00

[chains.trust_threshold]
       denominator = "3"
       numerator = "1"
EOF


# Add keys to hermes relayer
hermes keys add --key-file fizz_keypair_p.json --chain provider
hermes keys add --key-file fizz_keypair_c.json --chain consumer

sleep 5

hermes create connection\
    --a-chain consumer\
    --a-client 07-tendermint-0\
    --b-client 07-tendermint-0

hermes create channel\
    --a-chain consumer\
    --a-port consumer\
    --b-port provider\
    --order ordered\
    --channel-version 1\
    --a-connection connection-0

sleep 5

hermes --json start &> ${H}/hermes.log &

$PBIN q tendermint-validator-set --home ${H}/p
$CBIN q tendermint-validator-set --home ${H}/c

DELEGATIONS=$($PBIN q staking delegations \
	$(jq -r .address fizz_keypair_p.json) \
	--home ${H}/p -o json)

echo $DELEGATIONS

OPERATOR_ADDR=$(echo $DELEGATIONS | jq -r .delegation_responses[0].delegation.validator_address)

# delegate some more tokens to see power change
$PBIN tx staking delegate $OPERATOR_ADDR 8000000stake \
    --from fizz \
    --chain-id provider \
    --home ${H}/p \
    --keyring-backend test \
    -y -b block

sleep 13

$PBIN q tendermint-validator-set --home ${H}/p
$CBIN q tendermint-validator-set --home ${H}/c