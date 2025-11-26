#!/usr/bin/env bash
#
# Simple network monitor using ping/curl driven by a JSON config.
# Requires: jq, ping, curl
#
# Usage:
#   ./hello.sh endpoints.json
#
# JSON format:
# [
#   { "endpoint": "192.168.0.1", "check_type": "ping" },
#   { "endpoint": "https://google.com"", "check_type": "curl" }
# ]

set -o errexit
set -o nounset
set -o pipefail

CONFIG_FILE="${1:-}"

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
  echo "Usage: $0 <config.json>"
  exit 1
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

# Tunables
PING_COUNT="${PING_COUNT:-3}"        # how many ICMP echo requests per check
PING_TIMEOUT="${PING_TIMEOUT:-1}"    # seconds per ping request
CURL_TIMEOUT="${CURL_TIMEOUT:-3}"    # seconds for curl --max-time
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"  # seconds between monitoring rounds
OUTPUT_DIR="${OUTPUT_DIR:-.}"        # dir for any logging or other output

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Attempting to install..."
  yum install -y jq || { echo "Failed to install jq via yum"; exit 1; }
  echo "jq successfully installed."
fi

# Load endpoints & check types into arrays
mapfile -t ENDPOINTS < <(jq -r '.[].endpoint' "$CONFIG_FILE")
mapfile -t CHECK_TYPES < <(jq -r '.[].check_type' "$CONFIG_FILE")

if [[ "${#ENDPOINTS[@]}" -eq 0 ]]; then
  echo "No endpoints found in $CONFIG_FILE"
  exit 1
fi

echo "Loaded ${#ENDPOINTS[@]} checks from $CONFIG_FILE"
echo "Press Ctrl+C to stop."
echo

monitor_ping() {
  local endpoint="$1"
  local ts
  ts="$(date '+%F %T')"

  # Run ping and extract packet loss
  local output loss
  if ! output="$(ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$endpoint" 2>&1)"; then
    # ping command failed (DNS error, etc.)
    printf "%s [PING] %-40s %bFAILED (ping error)%b\n" \
      "$ts" "$endpoint" "$RED" "$RESET"
    return
  fi

  loss="$(
    awk -F', ' '/packets transmitted/ {print $3}' <<<"$output" \
      | awk '{print $1}' \
      | tr -d '%'
  )"

  if [[ -z "$loss" ]]; then
    # Couldn't parse loss line – treat as error
    printf "%s [PING] %-40s %bFAILED (no stats)%b\n" \
      "$ts" "$endpoint" "$RED" "$RESET"
    return
  fi

  if (( loss == 0 )); then
    printf "%s [PING] %-40s %bOK (%s%% packet loss)%b\n" \
      "$ts" "$endpoint" "$GREEN" "$loss" "$RESET"
  else
    # Highlight packet loss in red
    printf "%s [PING] %-40s %bISSUE (%s%% packet loss)%b\n" \
      "$ts" "$endpoint" "$RED" "$loss" "$RESET"
  fi
}

monitor_curl() {
  local endpoint="$1"
  local ts
  ts="$(date '+%F %T')"

  # -f fail on HTTP errors, -s silent, -S show errors, --max-time timeout
  if curl -fsS --max-time "$CURL_TIMEOUT" "$endpoint" -o /dev/null 2>$OUTPUT_DIR/net_monitor_curl.err; then
    printf "%s [CURL] %-40s %bOK%b\n" \
      "$ts" "$endpoint" "$GREEN" "$RESET"
  else
    local rc=$?
    local msg="ERROR"

    # curl exit code 28 == timeout
    if [[ $rc -eq 28 ]]; then
      msg="TIMEOUT"
    fi

    # grab a one-line error message if present
    local err
    err="$(tr '\n' ' ' <${OUTPUT_DIR}/net_monitor_curl.err | sed 's/  */ /g')"
    rm -f "${OUTPUT_DIR}/net_monitor_curl.err"

    printf "%s [CURL] %-40s %b%s (rc=%d)%b %s\n" \
      "$ts" "$endpoint" "$RED" "$msg" "$rc" "$RESET" "$err"
  fi
}

trap 'echo; echo "Stopping monitor..."; exit 0' INT TERM

while true; do
  for i in "${!ENDPOINTS[@]}"; do
    endpoint="${ENDPOINTS[$i]}"
    check_type="${CHECK_TYPES[$i]}"

    case "$check_type" in
      ping)
        monitor_ping "$endpoint"
        ;;
      curl)
        monitor_curl "$endpoint"
        ;;
      *)
        ts="$(date '+%F %T')"
        printf "%s [UNKNOWN] %-40s %bUnsupported check_type: %s%b\n" \
          "$ts" "$endpoint" "$YELLOW" "$check_type" "$RESET"
        ;;
    esac
  done

  echo
  sleep "$SLEEP_SECONDS"
done
