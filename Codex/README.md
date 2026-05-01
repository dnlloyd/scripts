# Codex Session Listing

`get_codex_sessions.sh` prints a compact table of local Codex CLI sessions so you can identify a session ID to resume.

This espacially helpful when `codex resume --all` does not show old sessions, possibly when switching from another model provider. 

If switching providers, it's recommend you do a `codex fork` to pull in your old session.

It reads Codex session transcript files under `${HOME}/.codex/sessions`, extracts the session ID, the first recorded working directory, and the first meaningful user prompt, then prints one row per session.

## Requirements

- Bash
- `jq`
- Standard Unix tools: `find`, `basename`, `sed`, `cut`, `sort`, and `column`

## Usage

From this directory:

```bash
./get_codex_sessions.sh
```

From the repository root:

```bash
Codex/get_codex_sessions.sh
```

## Output

The script prints a table with these columns:

```text
ID  CWD  CONVERSATION
```

- `ID` is the resumable Codex session ID extracted from the `rollout-*.jsonl` filename.
- `CWD` is the first non-empty working directory recorded in the session.
- `CONVERSATION` is the first meaningful user prompt, with whitespace collapsed and output limited to 120 characters.

Example:

```text
ID                                    CWD                         CONVERSATION
019ddf86-38f4-7f22-86be-5e7e59f47267 /Users/dan/github/project   Update the README for this script
```

You can pass the `ID` value to Codex resume commands, for example:

```bash
codex resume 019ddf86-38f4-7f22-86be-5e7e59f47267
```

## Safety

The script treats session files as read-only input. It does not mutate, delete, rename, upload, or send transcript contents anywhere.

Default output is intentionally summarized: it filters common Codex-injected boilerplate and does not print full transcripts.

## Validation

After editing the script, run:

```bash
shellcheck get_codex_sessions.sh
bash -n get_codex_sessions.sh
```

Optionally run the script locally and verify that it prints one row per session:

```bash
./get_codex_sessions.sh
```
