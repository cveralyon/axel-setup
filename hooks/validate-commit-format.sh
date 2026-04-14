#!/bin/bash
# Validates commit message format: tipo (Modelo/Archivo): Mensaje
# Reads $TOOL_INPUT as JSON, extracts the command, then validates the commit message
# Valid types: feat|fix|chore|refactor|test|docs|style|perf|ci|build|revert

TOOL_JSON="$TOOL_INPUT"

# Extract the command field from the Bash tool JSON input
CMD=$(echo "$TOOL_JSON" | jq -r '.command // empty' 2>/dev/null)
[ -z "$CMD" ] && CMD="$TOOL_JSON"

# Only check git commit commands
echo "$CMD" | grep -qE 'git commit' || exit 0

# Extract commit message from -m flag
# Handles: -m "msg", -m 'msg', -m "$(cat <<'EOF'\nmsg\nEOF\n)"
MSG=$(echo "$CMD" | sed -n 's/.*-m[[:space:]]*["'\'']\{0,1\}\(.*\)/\1/p' | sed 's/["'\'']\{0,1\}[[:space:]]*$//' | head -1)

# For heredoc pattern: extract the first content line
if echo "$MSG" | grep -q '<<'; then
  MSG=$(echo "$CMD" | tr '\n' '|' | sed 's/.*<<[^|]*|//' | sed 's/|.*//' | sed 's/^[[:space:]]*//')
fi

# If we couldn't extract a message, skip validation (might be --amend or interactive)
[ -z "$MSG" ] && exit 0

# Validate format: tipo (Scope): message
if ! echo "$MSG" | grep -qE '^(feat|fix|chore|refactor|test|docs|style|perf|ci|build|revert)\s*\('; then
  echo "WARNING: Formato de commit incorrecto." >&2
  echo "Esperado: tipo (Modelo/Archivo): Mensaje" >&2
  echo "Tipos válidos: feat|fix|chore|refactor|test|docs|style|perf|ci|build|revert" >&2
  echo "Recibido: $MSG" >&2
  exit 1
fi

exit 0
