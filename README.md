# Interchain Security Track - HackATOM 2022

| ⚛️ [Live Telegram Support Group](https://t.me/+oT1xkO8kBHJiZTdh) ⚛️ |
| -------- |

Welcome to Interchain Security! Interchain Security enables you to create new blockchain applications of unlimited complexity which can communicate through IBC - all while sharing the security of the Cosmos Hub – a ~$3 Billion market capitalization blockchain at the centre of the growing [Interchain](https://mapofzones.com/?testnet=false&period=24&tableOrderBy=ibcVolume&tableOrderSort=desc&zone=cosmoshub-4)!

This readme will show you how to get started both developing and testing your own Consumer application-specific blockchain ('appchain').

Please see our [landing page](https://interchainsecurity.dev/) and [development repository](https://github.com/cosmos/interchain-security/tree/danwt/hackatom) for more information. More resources can be found at the bottom of the page.

Have fun!

## Additional resources

- [Interchain Security Landing Page](https://interchainsecurity.dev/) 🚀🚀
- [Blog Post](https://informal.systems/2022/05/09/building-with-interchain-security/)
- [Interchain Security HackATOM branch](https://github.com/cosmos/interchain-security/tree/danwt/hackatom)
- [HackATOM workshop repo](https://github.com/danwt/hackatom)
- [Interchain Security Spec](https://github.com/cosmos/ibc/tree/marius/ccv/spec/app/ics-028-cross-chain-validation)
- [Ignite CLI (formerly 'Starport')](https://docs.ignite.com/)
- [Building Cosmos-SDK modules](https://github.com/cosmos/cosmos-sdk/tree/main/docs/building-modules)
- [Hermes IBC packet relayer docs](https://hermes.informal.systems/)
- [cosmwasm Consumer chain](https://github.com/Ethernal-Tech/consumer-chain-tool)
- [Interchain Security Testnet](https://github.com/sainoe/IS-testnet)

## Developing a Consumer Chain

These instructions show you how to create a custom Consumer chain and test it with a provider chain.

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

## Developing custom Consumer app logic

The `hackatom` branch of `cosmos-sdk/interchain-security` contains a `hello` module which can be used as a template module for implementing custom logic on top of the base Consumer app. Please take a look at `interchain-security/x/hello` for the module template, and the wiring in `interchain-security/app/consumer/app.go`. Ultimately the easiest way to create a Consumer app chain during the hackathon is to start from `interchain-security/app/consumer`.

The basis of the Consumer app chain is very close to what [Ignite CLI](https://docs.ignite.com/) gives you. Ignite (formerly 'Starport') is a tool that makes it very easy to create all the boilerplate needed for a brand new chain, module, query or transaction.

Please note, Consumer chains can run arbitrary application logic, this includes having a native token, governance, IBC communication and anything you can think of! So be creative, and definitely don't be concerned about scalability or security issues. Consumer chains will be run on different hardware, enabling full horizontal scalability, and security is shared from the Cosmos Hub.
