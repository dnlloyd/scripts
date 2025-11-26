#!/usr/bin/env zsh
# ca_bundle_report.sh
# Validate and summarize a PEM CA bundle (one or more certs).
# macOS/BSD-friendly, no GNU awk/sed required.

# set -euo pipefail
# set -x

print_usage() {
  cat <<'EOF'
Usage:
  ca_bundle_report.zsh [options] <bundle.pem>

Options:
  -c, --show-cn     Display identifiers for each certificate
      --long        With -c, show extended details (serial, fingerprint)
  -h, --help        Show this help

Examples:
  ca_bundle_report.zsh cacerts.pem
  ca_bundle_report.zsh --show-cn cacerts.pem
  ca_bundle_report.zsh --show-cn --long cacerts.pem
EOF
}

# --- Parse args ---
SHOW_CN=false
LONG=false

if (( $# == 0 )); then
  print_usage >&2
  exit 1
fi

args=()
while (( $# > 0 )); do
  case "${1:-}" in
    -c|--show-cn) SHOW_CN=true; shift ;;
    --long) LONG=true; shift ;;
    -h|--help) print_usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; print_usage >&2; exit 2 ;;
     *) args+=("$1"); shift ;;
  esac
done

if (( ${#args[@]} != 1 )); then
  echo "Error: exactly one PEM bundle path is required." >&2
  print_usage >&2
  exit 2
fi

BUNDLE="${args[1]}"
if [[ ! -r "$BUNDLE" ]]; then
  echo "Error: cannot read file: $BUNDLE" >&2
  exit 3
fi

# --- Prep temp workspace ---
TMPDIR="$(mktemp -d -t pemsplit.XXXXXX)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# --- Split bundle into individual cert files (BEGIN/END CERTIFICATE blocks) ---
count=0
outfile=""

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "-----BEGIN CERTIFICATE-----" ]]; then
    (( count++ )) || true
    outfile="$TMPDIR/cert_${count}.pem"
    print -r -- "$line" > "$outfile"
  elif [[ -n "${outfile:-}" ]]; then
    print -r -- "$line" >> "$outfile"
    if [[ "$line" == "-----END CERTIFICATE-----" ]]; then
      outfile=""
    fi
  fi
done < "$BUNDLE"


if (( count == 0 )); then
  echo "No 'BEGIN CERTIFICATE' blocks found in: $BUNDLE" >&2
  exit 4
fi

# --- Validate each cert with openssl ---
valid=0
invalid=0
typeset -A errors  # key=index -> error message



for i in {1..$count}; do
  f="$TMPDIR/cert_${i}.pem"
  if ! errout="$(openssl x509 -inform pem -in "$f" -noout 2>&1)"; then
    ((invalid++))
    # Keep a short, first-line error for the report
    errors[$i]="${errout%%$'\n'*}"
  else
    ((valid++))
  fi
done

# --- Report ---
echo "File:            $BUNDLE"
echo "Certificates:    $count"
echo "Valid:           $valid"
echo "Invalid:         $invalid"
echo ""

if (( invalid > 0 )); then
  echo "Invalid details:"
  for i in ${(on)${(k)errors}}; do
    echo "  #$i: ${errors[$i]}"
  done
fi

########################################
# --- Helpers to identify a certificate nicely ---

# Get Subject CN (may be empty)
_get_subject_cn() {
  openssl x509 -in "$1" -noout -subject 2>/dev/null \
  | sed -n 's/.*CN=\([^,/]*\).*/\1/p'
}

# Get first SAN entry (DNS, email, or IP). Works by parsing -text for macOS/LibreSSL.
_get_first_san() {
  # Pull the SAN block lines after "Subject Alternative Name", stop at next "X509v3" or blank.
  openssl x509 -in "$1" -noout -text 2>/dev/null \
  | awk '
      /Subject Alternative Name/ {insan=1; next}
      insan && /^ *X509v3/ {insan=0}
      insan && NF {print}
    ' \
  | sed 's/^ *//; s/, */\n/g' \
  | sed -n 's/^DNS:\(.*\)$/DNS:\1/p; s/^IP Address:\(.*\)$/IP:\1/p; s/^email:\(.*\)$/EMAIL:\1/p' \
  | head -n 1
}

_get_issuer_cn() {
  openssl x509 -in "$1" -noout -issuer 2>/dev/null \
  | sed -n 's/.*CN=\([^,/]*\).*/\1/p'
}

_get_subject_dn() {
  # RFC2253 gives a compact, predictable DN format
  openssl x509 -in "$1" -noout -subject -nameopt RFC2253 2>/dev/null \
  | sed 's/^subject= *//'
}

_get_notafter() {
  openssl x509 -in "$1" -noout -enddate 2>/dev/null \
  | sed 's/^notAfter=//'
}

_get_serial() {
  openssl x509 -in "$1" -noout -serial 2>/dev/null \
  | sed 's/^serial=//'
}

_get_fingerprint_sha256() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null \
  | sed 's/^SHA256 Fingerprint=//'
}

describe_cert() {
  local f="$1"
  local subj_cn san first_id issuer_cn notafter serial fp

  subj_cn="$(_get_subject_cn "$f")"
  san="$(_get_first_san "$f")"
  issuer_cn="$(_get_issuer_cn "$f")"
  notafter="$(_get_notafter "$f")"
  serial="$(_get_serial "$f")"
  fp="$(_get_fingerprint_sha256 "$f")"

  if [[ -n "$subj_cn" ]]; then
    first_id="CN:$subj_cn"
  elif [[ -n "$san" ]]; then
    first_id="$san"
  else
    first_id="$(_get_subject_dn "$f")"
    [[ -z "$first_id" ]] && first_id="(no Subject)"
  fi

  if $LONG; then
    print -- "${first_id} | Issuer:${issuer_cn:-?} | Expires:${notafter:-?} | Serial:${serial:-?} | SHA256:${fp:-?}"
  else
    print -- "${first_id} | Issuer:${issuer_cn:-?} | Expires:${notafter:-?}"
  fi
}


# --- Optional: show identifiers (CN -> SAN -> Subject) plus key metadata ---
if $SHOW_CN; then
  echo "Certificate identifiers:"
  for i in {1..$count}; do
    f="$TMPDIR/cert_${i}.pem"
    if openssl x509 -in "$f" -noout >/dev/null 2>&1; then
      # printf "#%d: " "$i"
      describe_cert "$f"
    else
      echo "#$i: (invalid certificate)"
    fi
  done
fi
