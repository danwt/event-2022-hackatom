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
killall hermes 2> /dev/null || true
killall interchain-security-pd &> /dev/null || true
rm -rf ${HOME_DIR}/provider
# Clean start
killall interchain-security-cd &> /dev/null || true
rm -rf ${HOME_DIR}/consumer
rm -f consumer-proposal.json
rm -f simon_cons_keypair.json
rm -f simon_keypair.json

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
dasel put string -f ${HOME_DIR}/provider/config/config.toml consensus.timeout_commit 3s
dasel put string -f ${HOME_DIR}/provider/config/config.toml consensus.timeout_propose 1s
dasel put bool -f ${HOME_DIR}/provider/config/app.toml .api.enable true
dasel put bool -f ${HOME_DIR}/provider/config/app.toml .api.enabled-unsafe-cors true

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