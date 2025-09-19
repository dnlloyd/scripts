#!/usr/bin/env bash
# Script: show_pem_common_names.sh
# Purpose: Extract and display CNs from all certs in a PEM bundle

PEM_FILE="$1"

if [[ -z "$PEM_FILE" ]]
then
    echo "Usage: $0 <pem-file>"
    exit 1
fi

count=0
certfile=""

# Split the PEM file into individual certs
while IFS= read -r line
do
    if [[ $line == "-----BEGIN CERTIFICATE-----" ]]
    then
        count=$((count+1))
        certfile="/tmp/cert.$$.$count.pem"
        echo "$line" > "$certfile"
    elif [[ $line == "-----END CERTIFICATE-----" ]]
    then
        echo "$line" >> "$certfile"
    elif [[ -n $certfile ]]
    then
        echo "$line" >> "$certfile"
    fi
done < "$PEM_FILE"

# Loop over the temp cert files and extract CN
for f in /tmp/cert.$$.*.pem
do
    cn=$(openssl x509 -in "$f" -noout -subject 2>/dev/null | sed -n 's/.*CN=\([^/]*\).*/\1/p')
    echo "Common Name: $cn"
    rm -f "$f"
done
