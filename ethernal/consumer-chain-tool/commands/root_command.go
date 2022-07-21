package commands

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

const (
	ToolName                      = "consumer-chain-tool"
	PrepareProposalCmdName        = "prepare-proposal"
	VerifyProposalCmdName         = "verify-proposal"
	FinalizeGenesisCmdName        = "finalize-genesis"
	PrepareProposalCmdParamsCount = 10
	VerifyProposalCmdParamsCount  = 7
	FinalizeGenesisCmdParamsCount = 7
	ConsumerBinary                = "wasmd_consumer"
	CosmWasmBinary                = "wasmd"
	SmartContractsLocation        = "smart-contracts-location"
	ConsumerChainId               = "consumer-chain-id"
	MultisigAddress               = "multisig-address"
	ToolOutputLocation            = "tool-output-location"
	ProposalId                    = "proposal-id"
	ProposalTitle                 = "proposal-title"
	ProposalDescription           = "proposal-description"
	ProposalRevisionHeight        = "proposal-revision-height"
	ProposalRevisionNumber        = "proposal-revision-number"
	ProposalSpawnTime             = "proposal-spawn-time"
	ProposalDeposit               = "proposal-deposit"
	ProposalGenesisHash           = "proposal-genesis-hash"
	ProposalBinaryHash            = "proposal-binary-hash"
	ProviderNodeAddress           = "provider-node-address"
	ProviderBinaryPath            = "provider-binary-path"
)

func init() {
	cobra.EnableCommandSorting = false
}

func Execute() {
	var rootCmd = &cobra.Command{
		Use:   ToolName,
		Short: fmt.Sprintf(ToolShortDesc, ToolName),
		Long:  ToolLongDesc,
	}

	rootCmd.CompletionOptions.DisableDefaultCmd = true

	rootCmd.AddCommand(
		NewPrepareProposalCommand(),
		NewVerifyProposalCommand(),
		NewFinalizeGenesisCommand())

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "An error occured while executing command: '%s'", err)
		os.Exit(1)
	}
}

func RunCmdAndPrintOutput(bashCmd *exec.Cmd) {
	cmdReader, err := bashCmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}
	bashCmd.Stderr = bashCmd.Stdout

	if err := bashCmd.Start(); err != nil {
		log.Fatal(err)
	}

	scanner := bufio.NewScanner(cmdReader)

	for scanner.Scan() {
		out := scanner.Text()
		fmt.Println(out)
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
}

const (
	ToolShortDesc = "%s - prepare and verify proposal and genesis file for a new Interchain Security enabled CosmWasm consumer chain"
	ToolLongDesc  = `The purpose of the tool is to produce output in a form of proposal and genesis files and in that manner simplify the process of starting the CosmWasm consumer chain with the pre-deployed wasm codes. Process of creating output data should be done in following steps:
    1. The proposer runs prepare-proposal tool command which generates genesis.json file with wasm section containing the pre-deployed codes and proposal.json file which contains hashes of genesis and consumer binary files. Description of a proposal might contain a link to the location from where genesis file, source code of wasm contracts and consumer binary can be downloaded  
    2. The proposer manually submits the proposal to the provider chain
    3. Validators optionally can run verify-proposal command of the tool to check if the hash of downloaded genesis matches the one from proposal and decide whether to vote for proposal
    4. Finally, validators run finalize-genesis command, which generate a final genesis file by adding ccvconsumer section in it. Validators can then use such genesis for running the consumer chain`
)
