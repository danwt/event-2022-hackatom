# Interchain Security Workshop HackATOM 2022

Welcome to Interchain Security! Interchain Security enables you to create new blockchain applications of unlimited complexity which can communicate through IBC - all while sharing the security of the Cosmos Hub!

This readme will show you how to get started developing and testing your own Consumer app chain.

Please see our [landing page](https://interchainsecurity.dev/) and [development repository](https://github.com/cosmos/interchain-security/tree/danwt/hackatom) for more information. More resources can be found at the bottom of the page.

Have fun!

## Developing a Consumer Chain

These instructions show you how to create a custom Consumer chain application and test it with a provider chain.

## Installation

These are instructions for developing an interchain-security consumer chain on Linux/OSX.

### Prerequisites

To create a consumer and test it live, provider and consumer chain binaries and some utilities are required.

### Chain binaries

```bash
# Get the interchain security repo
git clone -b danwt/hackatom https://github.com/cosmos/interchain-security.git;
# install the provider and consumer starter binaries
cd interchain-security && make install;
```

You can modify the consumer app in interchain-security/app/consumer.

### Hermes Relayer

V1^ of the Hermes IBC packet relayer can be installed following directions [on the website](https://hermes.informal.systems/installation.html). The simplest way for Linux/OSX users is to download the binary for your architecture directly ([[instructions]](https://hermes.informal.systems/installation.html#install-by-downloading), [[releases]](https://github.com/informalsystems/ibc-rs/releases)).

### Utils for scripts

```bash
brew install jq;
brew install dasel;
```

### NodeJs, for running the browser chain explorer

```bash
brew install node@16
npm install --global yarn;
```

### Check everything is installed

This script will check that all prerequisites are available.

```bash
bash prerequisites.sh
```

## Running provider and consumer chains

You can run the chains and relay packets between them. The scripts help with this

```bash
cd net;
chmod u+x 0_killAndClean.sh
chmod u+x 1_launch.sh
chmod u+x 2_relay.sh
chmod u+x 3_delegate.sh
chmod u+x 4_createBlogPost.sh
# Kill any existing process and clean up existing directories and configurations
./0_killAndClean.sh
# Launch a provider and consumer chain
# The script uses the handle fizz for monikers, key names, ect...
./1_launch.sh
# Start Hermes relayer
./2_relay.sh
# Delegate some extra tokens to the provider validator (demo purposes only, optional)
./3_delegate.sh
# Talk to the Consumer app and create a new blog post (demo purposes only, optional)
./4_createBlogPost.sh
```

I recommend taking a look at the scripts to see what is going on. For playing with the cli, try the following aliases.

```bash
alias pbin="interchain-security-pd"
alias cbin="interchain-security-cd"
```

## Running the explorer

The chain explorer web site can be served locally on `localhost:8080`.

```bash
cd explorer;
yarn install;
yarn serve;
```

## Additional resources

- <https://interchainsecurity.dev/>
- <https://github.com/cosmos/interchain-security/tree/danwt/hackatom>
- <https://github.com/danwt/hackatom>
- <https://github.com/cosmos/ibc/tree/marius/ccv/spec/app/ics-028-cross-chain-validation>
- <https://github.com/Ethernal-Tech/consumer-chain-tool>
- <https://github.com/sainoe/IS-testnet>
