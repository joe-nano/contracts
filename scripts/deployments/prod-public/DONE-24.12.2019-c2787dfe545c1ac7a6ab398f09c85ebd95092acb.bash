#!/usr/bin/env bash

spinner() {
    chars="/-\|"

    for (( j=0; j< $1; j++ )); do
      for (( i=0; i<${#chars}; i++ )); do
        sleep 0.5
        echo -en "${chars:$i:1}" "\r"
      done
    done
}

spinner 2

echo "Generating bytecodes for changes on public network"
echo "Acquisition and Donation patch to 1.0.2"
echo "Destination for execution: 0x75aa29aecdb5552ae139c6f28bbeb1a594b23728"
cd ../..
python3 generate_bytecode.py approveNewCampaign DONATION 1.0.2
python3 generate_bytecode.py approveNewCampaign TOKEN_SELL 1.0.2
