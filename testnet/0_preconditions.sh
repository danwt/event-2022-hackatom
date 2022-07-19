if ! hermes --version | grep -q "hermes 1.0"; 
then
  echo "Require hermes 1.0";
  exit 1;
fi

echo "hermes version is 1.0 - OK."
