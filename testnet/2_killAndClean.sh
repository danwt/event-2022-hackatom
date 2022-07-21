# Home directory
H="."

PBIN=interchain-security-pd
CBIN=interchain-security-cd
# Clean start
killall hermes 2> /dev/null || true
killall $PBIN &> /dev/null || true
killall $CBIN &> /dev/null || true
rm -rf ${H}/provider
rm -rf ${H}/consumer
rm -f consumer-proposal.json
rm -f fizz_cons_keypair.json
rm -f fizz_keypair.json
rm -f hermeslog