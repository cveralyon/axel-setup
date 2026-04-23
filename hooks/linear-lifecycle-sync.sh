#!/bin/bash
# linear-lifecycle-sync.sh
# Auto-syncs Linear card state based on git/gh actions.
# Runs as PostToolUse Bash hook (async).
#
# Requirements:
#   - Linear MCP server connected (linear-server)
#   - claude CLI available (for the haiku sub-call)
#   - Tickets in commit messages follow the pattern: KEY-123
#     (configure TICKET_PATTERN below to match your team's prefix)
#
# Behavior:
#   git commit (KEY-123) → In Progress  (if currently Todo/Backlog)
#   gh pr create          → In Review
#   gh pr merge           → Done
#
# Bootstrap substitution: set REPO_PATH_FILTER to a regex matching your
# repo paths so the hook only fires in those directories.
# Example: '/home/user/projects/mycompany/'
# Leave empty ("") to run in all directories.
REPO_PATH_FILTER="{{REPO_PATH_FILTER}}"
case "$REPO_PATH_FILTER" in "{{"*"}}"|"") REPO_PATH_FILTER="" ;; esac

TICKET_PATTERN="{{TICKET_PATTERN}}"
case "$TICKET_PATTERN" in "{{"*"}}"|"") TICKET_PATTERN="[A-Z]+-[0-9]+" ;; esac

LINEAR_TEAM="{{LINEAR_TEAM}}"
case "$LINEAR_TEAM" in "{{"*"}}"|"") LINEAR_TEAM="your team" ;; esac

# Guard against recursive invocation (this script spawns claude -p)
if [ -n "$CLAUDE_LINEAR_SYNC" ]; then exit 0; fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Only run in configured repos (skip if filter is empty — runs everywhere)
if [ -n "$REPO_PATH_FILTER" ] && ! echo "$CWD" | grep -qE "$REPO_PATH_FILTER"; then exit 0; fi

# --- Detect action type ---
ACTION=""
TICKETS=""

if echo "$COMMAND" | grep -qE '(^|[[:space:]&;|(])git[[:space:]]+commit([[:space:]]|$)'; then
  ACTION="in_progress"
  TICKETS=$(echo "$COMMAND" | grep -oE "$TICKET_PATTERN" | sort -u | tr '\n' ' ' | sed 's/ $//')

elif echo "$COMMAND" | grep -qE '(^|[[:space:]&;|(])gh[[:space:]]+pr[[:space:]]+create'; then
  ACTION="in_review"
  TICKETS=$(echo "$COMMAND" | grep -oE "$TICKET_PATTERN" | sort -u | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$TICKETS" ]; then
    TICKETS=$(git -C "$CWD" log --not --remotes --pretty=format:"%s %b" 2>/dev/null \
      | grep -oE "$TICKET_PATTERN" | sort -u | tr '\n' ' ' | sed 's/ $//')
  fi

elif echo "$COMMAND" | grep -qE '(^|[[:space:]&;|(])gh[[:space:]]+pr[[:space:]]+merge'; then
  ACTION="done"
  TICKETS=$(echo "$COMMAND" | grep -oE "$TICKET_PATTERN" | sort -u | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$TICKETS" ]; then
    TICKETS=$(git -C "$CWD" log --not --remotes --pretty=format:"%s %b" 2>/dev/null \
      | grep -oE "$TICKET_PATTERN" | sort -u | tr '\n' ' ' | sed 's/ $//')
  fi
fi

[ -z "$ACTION" ] && exit 0
[ -z "$TICKETS" ] && exit 0

# --- Rate limit: 90s debounce per action type ---
RATE_FILE="$HOME/.claude/.linear_sync_${ACTION}"
if [ -f "$RATE_FILE" ]; then
  LAST=$(stat -f %m "$RATE_FILE" 2>/dev/null || stat -c %Y "$RATE_FILE" 2>/dev/null)
  NOW=$(date +%s)
  if [ -n "$LAST" ] && [ $((NOW - LAST)) -lt 90 ]; then exit 0; fi
fi
touch "$RATE_FILE"

# --- Determine target state label ---
case "$ACTION" in
  in_progress) TARGET="In Progress" ;;
  in_review)   TARGET="In Review" ;;
  done)        TARGET="Done" ;;
  *) exit 0 ;;
esac

PROMPT="You are a Linear lifecycle sync agent. Update card states silently and efficiently. No explanations, no headers — just one line per ticket.

Tickets to process: $TICKETS
Target state: $TARGET
Team: $LINEAR_TEAM

Instructions:
1. Call list_issue_statuses to find the state ID for '$TARGET' in the $LINEAR_TEAM team.
2. For each ticket, call get_issue to check its current state name.
3. Skip rules:
   - If target is 'In Progress' and current state is already In Progress, In Review, or Done → skip.
   - If target is 'In Review' and current state is already In Review or Done → skip.
   - If target is 'Done' and current state is already Done → skip.
4. For tickets that need updating, call save_issue with the new stateId.
5. Output format (one line per ticket):
   KEY-123 → In Progress
   KEY-456: already In Review, skipped"

HOOK_TMP=$(mktemp -d 2>/dev/null)
REAL_TMP=$(cd "$HOOK_TMP" 2>/dev/null && pwd -P)
RESULT=$(cd "$HOOK_TMP" 2>/dev/null && printf '%s' "$PROMPT" | CLAUDE_LINEAR_SYNC=1 claude -p --model haiku 2>/dev/null)
GHOST_SLUG=$(echo "$REAL_TMP" | sed 's|[^a-zA-Z0-9]|-|g')
rm -rf "$HOOK_TMP" "$HOME/.claude/projects/${GHOST_SLUG}" 2>/dev/null

mkdir -p "$HOME/.claude/logs"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$ACTION] $TICKETS → $RESULT" >> "$HOME/.claude/logs/linear-sync.log"

exit 0
