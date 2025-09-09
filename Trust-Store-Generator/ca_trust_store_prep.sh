#!/usr/bin/env bash

# Usage: ./ca_trust_store_prep.sh [SOURCE_DIR] [CA_CERTS_PATH]

# shellcheck disable=SC2312

set -u
SOURCE_DIR="${1:-.}"
CACERTS_FILE="${2:-cacerts}"

PEM_DEST_DIR="pem"
DER_DEST_DIR="der"
DATA_BAGS_DEST_DIR="data_bags"

mkdir -p "${PEM_DEST_DIR}"
mkdir -p "${DER_DEST_DIR}"
mkdir -p "${DATA_BAGS_DEST_DIR}"

find "${SOURCE_DIR}" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' file
do
  echo "${file}"
  echo "----------------------------------------------------------"

  file_name="$(basename "${file}")"
  base_file_name="${file_name%.*}"
  pem_output_file_path="${PEM_DEST_DIR}/${base_file_name}.pem"
  der_output_file_path="${DER_DEST_DIR}/${base_file_name}.der"
  lower_base_file_name=$(echo "${base_file_name}" | tr '[:upper:]' '[:lower:]')

  # Check if it looks like PEM text file
  # echo "DEBUG: Checking if PEM format"
  if grep -q "\-----BEGIN CERTIFICATE-----" "${file}" 2>/dev/null
  then
    # Confirm it’s valid PEM
    # echo "DEBUG: PEM format detected, verifying with openssl"
    if openssl x509 -in "${file}" -noout -text >/dev/null 2>&1
    then
      echo "Format=PEM"
      # Rename to .pem file extension
      # echo "DEBUG: Renaming to .pem file extension"
      cp -p "${file}" "${pem_output_file_path}"
      echo "[PEM] ${file_name} -> $(basename "${pem_output_file_path}")"
      
      # Convert to DER format
      # echo "DEBUG: Converting to DER format"
      openssl x509 -in "${file}" -outform der -out "${der_output_file_path}"
      echo "[PEM to DER] ${file_name} -> $(basename "${der_output_file_path}")"

      # Add cert to cacerts
      # echo "DEBUG: Checking if cert exists in Java cacerts"
      if keytool -storepass changeit -list -keystore "${CACERTS_FILE}" -alias "${lower_base_file_name}" >/dev/null 2>&1
      then
        echo "${base_file_name} exists in Java cacerts, skipping"
      else
        echo -e "Adding ${base_file_name} to Java ${CACERTS_FILE}"
        keytool -storepass changeit -noprompt -trustcacerts -importcert -file "${der_output_file_path}" -keystore "${CACERTS_FILE}" -alias "${lower_base_file_name}"
      fi

      # Create data bag item for ets_certificates
      # echo "DEBUG: Creating data bag item for ets_certificates"
      base64_cert=$(base64 -i "${file}")

      cat > "${DATA_BAGS_DEST_DIR}/${base_file_name}.json" <<EOF
{
  "id": "${base_file_name}",
  "data": "${base64_cert}",
  "format": "base64"
}
EOF

    fi
  fi

  # Check for DER format
  # echo "DEBUG: Checking if DER format"
  if openssl x509 -in "${file}" -inform der -noout -text >/dev/null 2>&1
  then
    echo "Format=DER"
    # Rename to .der file extension
    # echo "DEBUG: Renaming to .der file extension"
    cp -p "${file}" "${der_output_file_path}"
    echo "[DER] ${file_name} -> $(basename "${der_output_file_path}")"

    # Add cert to cacerts
    # echo "DEBUG: Checking if cert exists in Java cacerts"
    if keytool -storepass changeit -list -keystore "${CACERTS_FILE}" -alias "${lower_base_file_name}" >/dev/null 2>&1
    then
      echo "${base_file_name} exists in Java cacerts, skipping"
    else
      echo -e "Adding ${base_file_name} to Java ${CACERTS_FILE}"
      keytool -storepass changeit -noprompt -trustcacerts -importcert -file "${der_output_file_path}" -keystore "${CACERTS_FILE}" -alias "${lower_base_file_name}"
    fi

    # echo "DEBUG: DER format detected, converting to PEM"
    if openssl x509 -in "${file}" -inform der -out "${pem_output_file_path}" -outform pem >/dev/null 2>&1
    then
      # echo "DEBUG: Verifying PEM conversion was successful"
      touch -r "${file}" "${pem_output_file_path}" 2>/dev/null || true
      echo "[DER] ${file_name} -> $(basename "${pem_output_file_path}") (converted)"

      # echo "DEBUG: PEM conversion successful"

      # Create data bag item for ets_certificates
      # echo "DEBUG: Creating data bag item for ets_certificates"
      base64_cert=$(base64 -i "${pem_output_file_path}")

      cat > "${DATA_BAGS_DEST_DIR}/${base_file_name}.json" <<EOF
{
  "id": "${base_file_name}",
  "data": "${base64_cert}",
  "format": "base64"
}
EOF

      # echo "DEBUG: PEM conversion and data bag creation successful, continuing to next cert"
      echo ""
      continue
    else
      echo "[ERR] ${file_name} detected as DER but conversion to PEM failed" >&2
      # echo "DEBUG: Continuing to next cert"
      echo ""
      continue
    fi
  fi

  echo ""
done
