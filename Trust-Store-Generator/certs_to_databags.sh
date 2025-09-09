#!/bin/bash

SOURCE_DIR="${1:-pem}"

for pem_file in $SOURCE_DIR/*.pem
do
  base64_cert=$(base64 -i $pem_file)
  fname="$(basename "$pem_file")"
  base_name="${fname%.*}"

  cat > "databags/${base_name}.json" <<EOF
{
  "id": "${base_name}",
  "data": "${base64_cert}",
  "format": "base64"
}
EOF

done
