#!/bin/bash

# Usage
# set-env-vars-for-command.sh <some command>

set -e 

# remove /env_vars if it exists
[ -e /env_vars ] && rm /env_vars

for filename in /vault/secrets/*; do
    echo "process $filename"
    echo "$(cat $filename | jq '.data' | jq -r "to_entries|map(\"\(.key)=\(.value|@sh)\")|.[]")" >> /env_vars
    export MY_SECRET="fakesecret"
done

eval $(cat /env_vars) $@