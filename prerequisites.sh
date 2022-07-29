if ! jq --version | grep -q "jq-1"; 
then
  echo "Require jq 1.0^";
  exit 1;
fi

echo "jq version is 1.0^ - OK."

if ! hermes --version | grep -q "hermes 1.0"; 
then
  echo "Require hermes 1.0^";
  exit 1;
fi

echo "hermes version is 1.0^ - OK."

if ! dasel --version | grep -q "dasel version 1."; 
then
  echo "Require dasel 1.^";
  exit 1;
fi

echo "dasel version is 1.^ - OK."

if ! node --version | grep -q "v16"; 
then
  echo "Require node 16.^";
  exit 1;
fi

echo "node version is 16.^ - OK."

if ! interchain-security-pd | grep -q "Stargate Cosmos"; 
then
  echo "Require interchain-security-pd (provider binary)"
  exit 1;
fi

echo "interchain-security-pd is available - OK."

if ! interchain-security-cd | grep -q "Stargate Cosmos"; 
then
  echo "Require interchain-security-cd (consumer binary)"
  exit 1;
fi

echo "interchain-security-cd is available - OK."
