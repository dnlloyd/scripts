#!/usr/bin/env bash
set -euo pipefail

{
  printf 'ID\tCWD\tCONVERSATION\n'

  find "${HOME}/.codex/sessions" -name 'rollout-*.jsonl' -print0 |
  while IFS= read -r -d '' session_file
  do
    id="$(basename "${session_file}" .jsonl | sed -E 's/^rollout-[0-9T:-]+-//')"

    cwd="$(
      jq -r -s '
        [
          .[]
          | .payload.cwd?
        ]
        | map(select(. != null and . != ""))
        | first // ""
      ' "${session_file}" 2>/dev/null
    )"

    convo="$(
      jq -r -s '
        def textish:
          if type == "string" then .
          elif type == "array" then [ .[] | textish ] | join(" ")
          elif type == "object" then
            (
              .text?
              // .content?
              // .message?
              // .input?
              // empty
              | textish
            )
          else empty end;

        [
          .[]
          | select(
              (.role? == "user")
              or (.payload.role? == "user")
              or (.payload.message.role? == "user")
              or (.type? == "user_message")
              or (.payload.type? == "user_message")
              or (.type? == "message" and .role? == "user")
              or (.payload.type? == "message" and .payload.role? == "user")
            )
          | [
              .content?,
              .message?,
              .payload.content?,
              .payload.message.content?,
              .payload.text?,
              .payload.message?
            ]
          | map(textish)
          | join(" ")
          | gsub("[[:space:]]+"; " ")
          | select(length > 0)
          | select(test("^<(environment_context|permissions instructions|user_instructions)>"; "i") | not)
          | select(test("^(Filesystem sandboxing defines|You are ChatGPT|# Instructions|System message:)"; "i") | not)
          | select(test("^# Files mentioned by the user:"; "i") | not)
          | select(test("^# In app browser \\(IAB\\):"; "i") | not)
          | select(test("^<image>\\s*</image>$"; "i") | not)
        ]
        | first // ""
      ' "${session_file}" 2>/dev/null |
      cut -c1-120
    )"

    printf '%s\t%s\t%s\n' "${id}" "${cwd}" "${convo}"
  done | sort
} | column -t -s $'\t'
