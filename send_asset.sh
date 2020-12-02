#!/bin/bash
shopt -s expand_aliases
alias e1-cli="$HOME/elements/src/elements-cli -datadir=$HOME/elementsdir1"
e1-cli sendtoaddress $1 $2 "" "" false false 1 UNSET $3
