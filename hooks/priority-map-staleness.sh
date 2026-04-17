#!/bin/bash
# SessionStart hook — warns if priority-map.md is stale (>14 days) or missing.
# Output is injected into the session's initial context.

PRIORITY_MAP="$HOME/.claude/memory/priority-map.md"
MAX_AGE_DAYS=14

if [[ ! -f "$PRIORITY_MAP" ]]; then
  echo "⚠️  priority-map.md does not exist at ~/.claude/memory/ — skills like sprint-status/daily/eod-review will run without it"
  exit 0
fi

if [[ "$(uname)" == "Darwin" ]]; then
  FILE_MTIME=$(stat -f %m "$PRIORITY_MAP")
else
  FILE_MTIME=$(stat -c %Y "$PRIORITY_MAP")
fi

NOW=$(date +%s)
AGE_SECONDS=$((NOW - FILE_MTIME))
AGE_DAYS=$((AGE_SECONDS / 86400))

if (( AGE_DAYS > MAX_AGE_DAYS )); then
  echo "⚠️  priority-map.md is ${AGE_DAYS} days old (threshold: ${MAX_AGE_DAYS}). Review and refresh current-sprint P0/P1 before running /daily or /sprint-status."
elif (( AGE_DAYS >= 7 )); then
  echo "ℹ️  priority-map.md is ${AGE_DAYS} days old — consider a refresh if sprint focus changed."
fi

exit 0
