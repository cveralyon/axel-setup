#!/bin/bash
# PostToolUse hook: log significant tool actions during the session for context
# persistence. Captures file edits, bash commands, and agent launches — the
# "what was done". Reads the hook payload as JSON from stdin.

INPUT=$(cat)

PROJECT_NAME=$(basename "$(pwd)")
SESSION_LOG="/tmp/claude-session-log-${PROJECT_NAME}.md"
TIMESTAMP=$(date +%H:%M)

TOOL_NAME_VAR=$(printf '%s' "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)

# Parse tool input for meaningful context
case "$TOOL_NAME_VAR" in
  Edit|Write)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    if [ -n "$FILE_PATH" ]; then
      echo "- [$TIMESTAMP] **$TOOL_NAME_VAR**: \`$(basename "$FILE_PATH")\`" >> "$SESSION_LOG"
    fi
    ;;
  Bash)
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null | head -c 120)
    if [ -n "$CMD" ]; then
      echo "- [$TIMESTAMP] **Bash**: \`$CMD\`" >> "$SESSION_LOG"
    fi
    ;;
  Agent)
    DESC=$(printf '%s' "$INPUT" | jq -r '.tool_input.description // empty' 2>/dev/null)
    if [ -n "$DESC" ]; then
      echo "- [$TIMESTAMP] **Agent**: $DESC" >> "$SESSION_LOG"
    fi
    ;;
  *)
    # Skip less important tools (Read, Glob, Grep, etc.) to keep log concise
    ;;
esac

exit 0
