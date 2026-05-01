# AGENTS.md

## Scope

This repository contains a small shell utility for inspecting local Codex CLI session transcripts under `~/.codex/sessions`.

Primary script:

- `get_codex_sessions.sh`

User-facing documentation:

- `README.md`

The script prints a table of Codex session IDs, working directories, and the first meaningful user prompt/conversation text from each `rollout-*.jsonl` session file.

## Goals

When modifying this repo, preserve these behaviors:

- Do not mutate or delete anything under `~/.codex`.
- Treat `~/.codex/sessions/**/*.jsonl` as read-only input.
- Keep output useful for quickly identifying sessions to resume with `codex resume <SESSION_ID>`.
- Prefer portable macOS-friendly shell commands.
- Keep dependencies minimal. The expected external dependency is `jq`.
- Keep `README.md` aligned with any user-facing changes to usage, dependencies, output columns, or safety behavior.

## Safety Rules

Do not add code that:

- Deletes, truncates, rewrites, or renames Codex session files.
- Uploads, exfiltrates, or sends transcript contents anywhere.
- Prints full session transcripts by default.
- Includes secrets, tokens, API keys, or environment dumps in output.
- Assumes all session content is safe to expose without user intent.

Codex session transcripts may contain private code, prompts, paths, internal project names, command output, credentials accidentally pasted by a user, or other sensitive material. Default output must remain summarized and bounded.

## Implementation Guidelines

Use Bash with strict mode:

```bash
set -euo pipefail
```

Be careful with pipelines under `pipefail`. Avoid patterns like:

```bash
jq ... | head -n 1
```

because `head` can close the pipe early and cause `jq` to receive `SIGPIPE`, which may terminate the script under `pipefail`.

Prefer making `jq` select a single result itself, for example:

```jq
[
  .[]
  | ...
]
| first // ""
```

For JSONL session files, prefer slurping with:

```bash
jq -r -s '...' "$file"
```

so the script can inspect the whole session and emit exactly one row per file.

## Conversation Extraction

The conversation/title field should be the first meaningful user prompt, not Codex-injected boilerplate.

Filter out synthetic or low-value entries such as:

- `<environment_context>`
- `<permissions instructions>`
- `<user_instructions>`
- `Filesystem sandboxing defines...`
- `You are ChatGPT...`
- `# Instructions`
- `System message:`
- `# Files mentioned by the user:`
- `# In app browser (IAB):`
- empty image-only payloads like `<image> </image>`

Keep the conversation output bounded. A 120-character limit is reasonable unless intentionally changed.

## Output Format

Default output should be a readable table with these columns:

```text
ID  CWD  CONVERSATION
```

The `ID` should be extracted from filenames like:

```text
rollout-2026-04-30T12-53-28-019ddf86-38f4-7f22-86be-5e7e59f47267.jsonl
```

Expected ID:

```text
019ddf86-38f4-7f22-86be-5e7e59f47267
```

The `CWD` should come from the first available `.payload.cwd` value in the session.

The `CONVERSATION` should be single-line text with whitespace collapsed.

## Testing

Before committing changes, run:

```bash
shellcheck get_codex_sessions.sh
./get_codex_sessions.sh
```

If `shellcheck` is unavailable, at minimum run:

```bash
bash -n get_codex_sessions.sh
./get_codex_sessions.sh
```

Verify:

- The script prints one row per session, not one row per transcript event.
- The first column contains UUID-like session IDs.
- The second column contains working directories.
- The third column does not start with Codex boilerplate.
- The script does not stop after the first matching session.
- The script handles sessions with no usable conversation text by printing an empty conversation field rather than failing.

## Manual Debugging Helper

For a problematic session file, inspect candidate text fields without dumping the full transcript:

```bash
f="$HOME/.codex/sessions/YYYY/MM/DD/rollout-...jsonl"

jq -r -s '
  def textish:
    if type == "string" then .
    elif type == "array" then [ .[] | textish ] | join(" ")
    elif type == "object" then
      (.text? // .content? // .message? // .input? // empty | textish)
    else empty end;

  [
    .[]
    | [
        .type?,
        .role?,
        .payload.type?,
        .payload.role?,
        (
          [
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
        )
      ]
    | @tsv
  ][0:30][]
' "$f" | nl -ba
```

## Style Preferences

- Keep the script direct and readable.
- Use descriptive variable names: `file`, `session_id`, `cwd`, `conversation` are preferred over cryptic names in new code.
- Avoid clever one-liners when they make shell quoting or `jq` logic harder to maintain.
- Prefer explicit filters over broad regexes that may hide legitimate user prompts.
- Keep comments concise and useful.

## Future Enhancements

Reasonable future additions:

- `--json` output mode.
- `--csv` output mode.
- `--no-header` flag.
- `--limit N` for display length.
- `--session-dir DIR` to inspect a non-default Codex home.
- `--grep PATTERN` to filter conversation text or CWD.

Any enhancement must preserve the default safe behavior: read-only access to sessions and bounded transcript output.
