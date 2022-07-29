#!/bin/bash
set -eux 

# Home directory
H="."
PDIR=${H}/p
CDIR=${H}/c
PBIN=interchain-security-pd
CBIN=interchain-security-cd

HANDLE=fizz

### EXTRA ACTIONS ###

$CBIN tx hello create-post footitle barcontent --from $HANDLE --keyring-backend test --home $CDIR --chain-id consumer
$CBIN q hello posts --home $CDIR