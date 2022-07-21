#!/bin/bash
set -eu

#bash finalize_genesis.sh $HOME/wasm_contracts wasm wasm1ykqt29d4ekemh5pc0d2wdayxye8yqupttf6vyz $HOME/tool_output_step2 1 "tcp://localhost:26658" "$HOME/cosmwasm_consumer/interchain-security-pd"

WASM_CONTRACTS="$1" #TODO: once SC compiling is solved, it should point to the output of step1.sh where source code of SCs are stored
CONSUMER_CHAIN_ID="$2"
CONSUMER_CHAIN_MULTISIG_ADDRESS="$3"
TOOL_OUTPUT_DIR="$4"
PROPOSAL_ID="$5"
PROVIDER_NODE_ADDRESS="$6"
PROVIDER_BINARY_PATH="$7"
CONSUMER_CHAIN_BINARY="wasmd_consumer"
WASM_BINARY="wasmd"
TOOL_OUTPUT="$TOOL_OUTPUT_DIR"/$(date +"%Y-%m-%d_%H-%M-%S")
CREATE_OUTPUT_SUBFOLDER="false"
LOG="$TOOL_OUTPUT"/log_file.txt

# Delete all generated data.
clean_up () {
    rm -f "$TOOL_OUTPUT"/consumer_section.json
	rm -f "$TOOL_OUTPUT"/sha256hashes.json
	rm -f "$TOOL_OUTPUT"/proposal_info.json
} 
trap clean_up EXIT
 
# Create directories if they don't exist.
mkdir -p "$TOOL_OUTPUT"

# Query the proposal to get the hashes from the chain
if ! "$PROVIDER_BINARY_PATH" q gov proposal $PROPOSAL_ID --node "$PROVIDER_NODE_ADDRESS" --output json > "$TOOL_OUTPUT"/proposal_info.json; 
then
  echo "Failed to query proposal with id $PROPOSAL_ID! Verify proposal failed. Please check the $LOG for more details."
  exit 1
fi

PROPOSAL_GENESIS_HASH=$(jq -r ".content.genesis_hash" "$TOOL_OUTPUT"/proposal_info.json)
PROPOSAL_BINARY_HASH=$(jq -r ".content.binary_hash" "$TOOL_OUTPUT"/proposal_info.json)
PROPOSAL_SPAWN_TIME=$(jq -r ".content.spawn_time" "$TOOL_OUTPUT"/proposal_info.json)

if [ "$PROPOSAL_GENESIS_HASH" == null ] || [ "$PROPOSAL_BINARY_HASH" == null ] ||[ "$PROPOSAL_SPAWN_TIME" == null ]; 
then
  echo "Invalid proposal data on the provider chain!"
  exit 1
fi

if ! bash verify_proposal.sh "$WASM_CONTRACTS" "$CONSUMER_CHAIN_ID" $CONSUMER_CHAIN_MULTISIG_ADDRESS $CONSUMER_CHAIN_BINARY $WASM_BINARY "$TOOL_OUTPUT" $CREATE_OUTPUT_SUBFOLDER $PROPOSAL_GENESIS_HASH $PROPOSAL_BINARY_HASH $PROPOSAL_SPAWN_TIME; 
then
	echo "Error while verifying proposal! Finalize genesis failed. Please check the $LOG for more details."
	exit 1
fi

if ! "$PROVIDER_BINARY_PATH" q provider consumer-genesis "$CONSUMER_CHAIN_ID" --node "$PROVIDER_NODE_ADDRESS" --output json > "$TOOL_OUTPUT"/consumer_section.json; 
then
	echo "Failed to get consumer genesis for the chain-id '$CONSUMER_CHAIN_ID'! Finalize genesis failed. Please check the $LOG for more details."
	exit 1
fi

jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]' "$TOOL_OUTPUT"/genesis.json "$TOOL_OUTPUT"/consumer_section.json > "$TOOL_OUTPUT"/genesis_consumer.json && \
	mv "$TOOL_OUTPUT"/genesis_consumer.json "$TOOL_OUTPUT"/genesis.json

echo "Finalize genesis succeded!"
echo "Output data is saved at $TOOL_OUTPUT"