#!/bin/bash
# Trigger memory-extractor.sh after a real git commit.
# Runs from PostToolUse Bash hook (async).
# memory-extractor.sh has an internal 5-minute rate limit to batch consecutive commits.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only trigger after a real `git commit` (not git log, diff, status, etc.)
if ! echo "$COMMAND" | grep -qE '(^|[[:space:]&;|(])git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Forward the full hook payload to the extractor
echo "$INPUT" | bash "$HOME/.claude/hooks/memory-extractor.sh"
exit 0
