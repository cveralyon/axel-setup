#!/bin/bash
# Log significant tool actions during session for context persistence
# Captures: file edits, bash commands, agent launches — the "what was done"

PROJECT_NAME=$(basename "$(pwd)")
SESSION_LOG="/tmp/claude-session-log-${PROJECT_NAME}.md"
TIMESTAMP=$(date +%H:%M)

TOOL_NAME_VAR="${TOOL_NAME:-unknown}"

# Parse tool input for meaningful context
case "$TOOL_NAME_VAR" in
  Edit|Write)
    FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null)
    if [ -n "$FILE_PATH" ]; then
      echo "- [$TIMESTAMP] **$TOOL_NAME_VAR**: \`$(basename "$FILE_PATH")\`" >> "$SESSION_LOG"
    fi
    ;;
  Bash)
    CMD=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command','')[:120])" 2>/dev/null)
    if [ -n "$CMD" ]; then
      echo "- [$TIMESTAMP] **Bash**: \`$CMD\`" >> "$SESSION_LOG"
    fi
    ;;
  Agent)
    DESC=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))" 2>/dev/null)
    if [ -n "$DESC" ]; then
      echo "- [$TIMESTAMP] **Agent**: $DESC" >> "$SESSION_LOG"
    fi
    ;;
  *)
    # Skip less important tools (Read, Glob, Grep, etc.) to keep log concise
    ;;
esac

exit 0
