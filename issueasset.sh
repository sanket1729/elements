#!/bin/bash
shopt -s expand_aliases
alias e1-cli="$HOME/elements/src/elements-cli -datadir=$HOME/elementsdir1"
ASSET_ADDR=$1
TOKEN_ADDR=$(e1-cli getnewaddress "" legacy)
ASSET_AMOUNT=$2
TOKEN_AMOUNT=1
RAWTX=$(e1-cli createrawtransaction '''[]''' '''{"''data''":"''00''"}''')
FRT=$(e1-cli fundrawtransaction $RAWTX)
HEXFRT=$(echo $FRT | jq '.hex' | tr -d '"')
RIA=$(e1-cli rawissueasset $HEXFRT '''[{"''asset_amount''":'$ASSET_AMOUNT', "''asset_address''":"'''$ASSET_ADDR'''", "''token_amount''":'$TOKEN_AMOUNT', "''token_address''":"'''$TOKEN_ADDR'''", "''blind''":false}]''')
echo $RIA | jq '.[0].hex' | tr -d '"' > $3
echo $RIA | jq '.[0].asset' | tr -d '"'