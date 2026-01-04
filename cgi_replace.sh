#!/usr/bin/env zsh

# url_encode: Encode a string into CGI/URL-escaped form.
url_encode() {
  local string="$1"
  local encoded=""
  local char hex

  # Iterate byte-by-byte
  for (( i=1; i<=${#string}; i++ )); do
    char="${string[i]}"

    case "$char" in
      [a-zA-Z0-9.~_-])
        # Safe characters stay as-is
        encoded+="$char"
        ;;
      *)
        # Everything else becomes %HH
        hex=$(printf "%X" "'$char")
        encoded+="%$hex"
        ;;
    esac
  done

  print -r -- "$encoded"
}

# If input is piped or redirected, read from stdin
if [[ ! -t 0 ]]; then
  input=$(cat)
elif [[ -n "$1" ]]; then
  input="$1"
else
  print "Usage: $0 <string>" >&2
  exit 1
fi

url_encode "$input"
