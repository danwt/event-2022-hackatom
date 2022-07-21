package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

func NewFinalizeGenesisCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:     getFinalizeCommandUsage(),
		Example: getFinalizeCommandExample(),
		Short:   FinalizeGenesisShortDesc,
		Long:    getFinalizeGenesisLongDesc(),
		Args:    cobra.ExactArgs(FinalizeGenesisCmdParamsCount),
		RunE: func(cmd *cobra.Command, args []string) error {
			inputs, err := NewFinalizeGenesisArgs(args)
			if err != nil {
				return err
			}

			bashCmd := exec.Command("/bin/bash", "finalize_genesis.sh",
				inputs.smartContractsLocation, inputs.consumerChainId, inputs.multisigAddress,
				inputs.toolOutputLocation, inputs.proposalId, inputs.providerNodeAddress, inputs.providerBinaryPath)

			RunCmdAndPrintOutput(bashCmd)

			return nil
		},
	}

	return cmd
}

func getFinalizeCommandUsage() string {
	return fmt.Sprintf("%s [%s] [%s] [%s] [%s] [%s] [%s] [%s]",
		FinalizeGenesisCmdName, SmartContractsLocation, ConsumerChainId,
		MultisigAddress, ToolOutputLocation, ProposalId, ProviderNodeAddress, ProviderBinaryPath)
}

func getFinalizeCommandExample() string {
	return fmt.Sprintf("%s %s %s %s %s %s %s %s %s",
		ToolName, FinalizeGenesisCmdName, "$HOME/wasm_contracts", "wasm", "wasm1ykqt29d4ekemh5pc0d2wdayxye8yqupttf6vyz",
		"$HOME/tool_output_step2", "1", "tcp://localhost:26657", "$HOME/gaiad")
}

func getFinalizeGenesisLongDesc() string {
	return fmt.Sprintf(FinalizeGenesisLongDesc, SmartContractsLocation, ConsumerChainId,
		MultisigAddress, ToolOutputLocation, ProposalId, ProviderNodeAddress, ProviderBinaryPath)
}

type FinalizeGenesisArgs struct {
	smartContractsLocation string
	consumerChainId        string
	multisigAddress        string
	toolOutputLocation     string
	proposalId             string
	providerNodeAddress    string
	providerBinaryPath     string
}

func NewFinalizeGenesisArgs(args []string) (*FinalizeGenesisArgs, error) {
	if len(args) != FinalizeGenesisCmdParamsCount {
		return nil, fmt.Errorf("unexpected number of arguments. Expected: %d, received: %d", FinalizeGenesisCmdParamsCount, len(args))
	}

	commandArgs := new(FinalizeGenesisArgs)
	var errors []string

	smartContractsLocation := strings.TrimSpace(args[0])
	if IsValidInputPath(smartContractsLocation) {
		commandArgs.smartContractsLocation = smartContractsLocation
	} else {
		errors = append(errors, fmt.Sprintf("Provided input path '%s' is not a valid directory.", smartContractsLocation))
	}

	consumerChainId := strings.TrimSpace(args[1])
	if IsValidString(consumerChainId) {
		commandArgs.consumerChainId = consumerChainId
	} else {
		errors = append(errors, fmt.Sprintf("Provided chain-id '%s' is not valid.", consumerChainId))
	}

	multisigAddress := strings.TrimSpace(args[2])
	if IsValidString(multisigAddress) {
		commandArgs.multisigAddress = multisigAddress
	} else {
		errors = append(errors, fmt.Sprintf("Provided multisig address '%s' is not valid.", multisigAddress))
	}

	toolOutputLocation := strings.TrimSpace(args[3])
	if IsValidOutputPath(toolOutputLocation) {
		commandArgs.toolOutputLocation = toolOutputLocation
	} else {
		errors = append(errors, fmt.Sprintf("Provided output path '%s' is not a valid directory.", toolOutputLocation))
	}

	proposalId := strings.TrimSpace(args[4])
	if isPositiveInt(proposalId) {
		commandArgs.proposalId = proposalId
	} else {
		errors = append(errors, fmt.Sprintf("Provided proposal id '%s' is not valid.", proposalId))
	}

	// TODO: not sure if we should validate node id with regex
	providerNodeAddress := strings.TrimSpace(args[5])
	if IsValidString(providerNodeAddress) {
		commandArgs.providerNodeAddress = providerNodeAddress
	} else {
		errors = append(errors, fmt.Sprintf("Provided provider node address '%s' is not valid.", providerNodeAddress))
	}

	providerBinaryPath := strings.TrimSpace(args[6])
	if IsValidFilePath(providerBinaryPath) {
		commandArgs.providerBinaryPath = providerBinaryPath
	} else {
		errors = append(errors, fmt.Sprintf("Provided provider binary path '%s' is not valid.", providerBinaryPath))
	}

	if len(errors) > 0 {
		return nil, fmt.Errorf(strings.Join(errors, "\n"))
	}

	return commandArgs, nil
}

const (
	FinalizeGenesisShortDesc = "Build the final genesis.json for Interchain Security consumer chain with CosmWasm smart contracts deployed"
	FinalizeGenesisLongDesc  = `This command takes the same inputs and goes through the same process as 'verify-proposal' command to verify the command inputs against the provided proposal.
It then queries the provider chain to obtain the consumer section for the chain ID and appends this data to the initial genesis.json, which results in Interchain Secuirty consumer-enabled genesis with CosmWasm smart contracts deployed.

Command arguments:
    %s - The location of the directory that contains CosmWasm smart contracts source code. TODO: add details about subdirectories structure and other things (Cargo.toml etc.)?
    %s - The chain ID of the consumer chain.
    %s - The multi-signature address that will have the permission to instantiate contracts from the set of predeployed codes.
    %s - The location of the directory where the resulting genesis.json and sha256hashes.json files will be saved.
    %s - The ID of the 'create consumer chain' proposal submitted to the provider chain, whose data will be used to verify if the inputs of this command match the ones from the proposal.
    %s - The address of the provider chain node in the following format: tcp://IP_ADDRESS:PORT_NUMBER. This address is used to query the provider chain to obtain the consumer section for the genesis file.
    %s - The location of the provider binary.`
)
