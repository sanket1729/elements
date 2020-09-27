#!/bin/bash
shopt -s expand_aliases
alias e1-cli="$HOME/elements/src/elements-cli -datadir=$HOME/elementsdir1"
e1-cli decoderawtransaction $(e1-cli getrawtransaction $1)
