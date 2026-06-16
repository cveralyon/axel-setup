#!/bin/bash
# UserPromptSubmit hook: log each user prompt during the session for context
# persistence. Appends to a temp file that session-save.sh reads at the end.
# Reads the hook payload as JSON from stdin and extracts .prompt.

INPUT=$(cat)

PROJECT_NAME=$(basename "$(pwd)")
SESSION_LOG="/tmp/claude-session-log-${PROJECT_NAME}.md"

USER_TEXT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

if [ -n "$USER_TEXT" ]; then
  TIMESTAMP=$(date +%H:%M)
  # Truncate long prompts to keep the log manageable
  TRUNCATED=$(printf '%s' "$USER_TEXT" | head -c 500)
  echo "### [$TIMESTAMP] User" >> "$SESSION_LOG"
  echo "$TRUNCATED" >> "$SESSION_LOG"
  echo "" >> "$SESSION_LOG"
fi

exit 0
