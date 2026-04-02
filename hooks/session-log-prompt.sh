#!/bin/bash
# Log each user prompt during the session for context persistence
# Appends to a temp file that session-save.sh reads at the end

PROJECT_NAME=$(basename "$(pwd)")
SESSION_LOG="/tmp/claude-session-log-${PROJECT_NAME}.md"

# Read user prompt from stdin (Claude Code passes it as JSON via $PROMPT)
USER_TEXT="$PROMPT"

if [ -z "$USER_TEXT" ]; then
  # Try reading from hook input
  USER_TEXT=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)
fi

if [ -n "$USER_TEXT" ]; then
  TIMESTAMP=$(date +%H:%M)
  # Truncate long prompts to keep log manageable
  TRUNCATED=$(echo "$USER_TEXT" | head -c 500)
  echo "### [$TIMESTAMP] Usuario" >> "$SESSION_LOG"
  echo "$TRUNCATED" >> "$SESSION_LOG"
  echo "" >> "$SESSION_LOG"
fi

exit 0
