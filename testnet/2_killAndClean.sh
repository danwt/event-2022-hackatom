# Home directory
H="."

PBIN=interchain-security-pd
CBIN=interchain-security-cd
# Clean start
killall hermes 2> /dev/null || true
killall $PBIN &> /dev/null || true
killall $CBIN &> /dev/null || true
hermes keys delete --chain provider --all
hermes keys delete --chain consumer --all
rm -rf ${H}/p
rm -rf ${H}/c
rm -f proposal.json
rm -f fizz_keypair_c.json
rm -f fizz_keypair_p.json
rm -f hermes.log