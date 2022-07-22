SRC_ADDR=$($PBIN keys show\
    fizz \
    --home ${H}/p 
    --keyring-backend test\
    --output json\
    | jq '.address')

# Get local account addresses to receive tokens
ACC_ADDR=$($PBIN keys show\
    $HANDLE \
    --home $PDIR\
    --keyring-backend test\
    --output json\
    | jq '.address')