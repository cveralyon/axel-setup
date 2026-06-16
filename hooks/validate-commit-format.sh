#!/bin/bash
# PreToolUse hook (Bash): validates commit message format before the command runs.
# Reads the hook payload as JSON from stdin, extracts .tool_input.command,
# then validates the commit message.
# Valid types: feat|fix|chore|refactor|test|docs|style|perf|ci|build|revert
# Exit codes: 0 = allow, 2 = block (stderr shown to the model).

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Fallback: if stdin was not JSON, treat the whole payload as the command.
[ -z "$CMD" ] && CMD="$INPUT"

# Only check git commit commands
printf '%s' "$CMD" | grep -qE 'git commit' || exit 0

# Extract commit message from -m flag
# Handles: -m "msg", -m 'msg', -m "$(cat <<'EOF'\nmsg\nEOF\n)"
MSG=$(printf '%s' "$CMD" | sed -n 's/.*-m[[:space:]]*["'\'']\{0,1\}\(.*\)/\1/p' | sed 's/["'\'']\{0,1\}[[:space:]]*$//' | head -1)

# For heredoc pattern: extract the first content line
if printf '%s' "$MSG" | grep -q '<<'; then
  MSG=$(printf '%s' "$CMD" | tr '\n' '|' | sed 's/.*<<[^|]*|//' | sed 's/|.*//' | sed 's/^[[:space:]]*//')
fi

# If we couldn't extract a message, skip validation (might be --amend or interactive)
[ -z "$MSG" ] && exit 0

# Validate format: tipo (Scope): message
if ! printf '%s' "$MSG" | grep -qE '^(feat|fix|chore|refactor|test|docs|style|perf|ci|build|revert)\s*\('; then
  echo "BLOCKED: Commit format is incorrect." >&2
  echo "Required: type (Scope): Descriptive message" >&2
  echo "Canonical example: feat (AuthController): add OAuth2 login flow" >&2
  echo "Valid types: feat|fix|chore|refactor|test|docs|style|perf|ci|build|revert" >&2
  echo "Do not use --no-verify to bypass this check. Fix the message instead." >&2
  echo "Got: $MSG" >&2
  exit 2
fi

exit 0
