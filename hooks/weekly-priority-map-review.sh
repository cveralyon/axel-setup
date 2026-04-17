#!/bin/bash
# Weekly priority-map review — intended to run every Monday 9am via LaunchAgent/cron.
# Analyzes git activity from the last 7 days + current priority-map and writes
# an update proposal. Does not modify priority-map directly — user reviews and applies.
#
# Configuration (env vars):
#   PRIORITY_MAP_REPOS — space-separated list of absolute repo paths to scan.
#                        Example: "$HOME/work/api $HOME/work/web"
#                        If unset/empty, the git-evidence section is skipped.

set -e

MEMORY_DIR="$HOME/.claude/memory"
PRIORITY_MAP="$MEMORY_DIR/priority-map.md"
ARCHIVE="$MEMORY_DIR/MEMORY-archive.md"
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/priority-map-review.log"

TIMESTAMP=$(date +%Y-%m-%d)
PROPOSAL_FILE="$MEMORY_DIR/priority-map.proposed-${TIMESTAMP}.md"
REVIEW_SUMMARY="$MEMORY_DIR/priority-map-review-${TIMESTAMP}.md"

echo "=== priority-map review $(date) ===" >> "$LOG_FILE"

if [[ ! -f "$PRIORITY_MAP" ]]; then
  echo "ERROR: priority-map.md does not exist at $MEMORY_DIR" >> "$LOG_FILE"
  exit 1
fi

# Anti-recursion guard: prevents infinite loops if this hook is wired into a
# lifecycle event that fires during the claude -p subprocess below.
if [[ -n "$CLAUDE_HOOK_RUNNING" ]]; then
  echo "SKIP: CLAUDE_HOOK_RUNNING set — avoiding recursion" >> "$LOG_FILE"
  exit 0
fi
export CLAUDE_HOOK_RUNNING=1

# Isolated JSONL session to avoid polluting /resume history.
ISOLATED_SESSION_DIR=$(mktemp -d)
export CLAUDE_SESSION_DIR="$ISOLATED_SESSION_DIR"

# Collect git evidence from the last 7 days across configured repos.
REPOS="${PRIORITY_MAP_REPOS:-}"
GIT_EVIDENCE=$(
  if [[ -z "$REPOS" ]]; then
    echo "(PRIORITY_MAP_REPOS not set — skipping git evidence collection)"
  else
    for repo in $REPOS; do
      [ -d "$repo/.git" ] || continue
      repo_name=$(basename "$repo")
      echo "## $repo_name"
      cd "$repo" 2>/dev/null && {
        git fetch origin --quiet 2>/dev/null || true
        echo "### Merged PRs last 7 days"
        git log --first-parent origin/main --since="7 days ago" --pretty=format:'- %s' 2>/dev/null | head -30
        echo ""
        echo "### New branches (not merged to main)"
        if [[ "$(uname)" == "Darwin" ]]; then
          SEVEN_DAYS_AGO=$(date -v-7d +%Y-%m-%d)
        else
          SEVEN_DAYS_AGO=$(date -d '7 days ago' +%Y-%m-%d)
        fi
        git for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:short)' refs/remotes/origin 2>/dev/null | awk -v d="$SEVEN_DAYS_AGO" '$2 >= d {print "- " $0}' | head -20
        echo ""
      }
    done
  fi
)

PROMPT=$(cat <<PROMPT_EOF
It's Monday morning. Your task: review the user's priority-map.md and propose an update based on recent git activity.

**Input 1 — current priority-map:**
\`\`\`
$(cat "$PRIORITY_MAP")
\`\`\`

**Input 2 — git activity last 7 days (tracked repos):**
\`\`\`
$GIT_EVIDENCE
\`\`\`

**Input 3 — current archive:**
\`\`\`
$(cat "$ARCHIVE" 2>/dev/null || echo "empty")
\`\`\`

**Expected output — write TWO files:**

1. \`$REVIEW_SUMMARY\` — short analysis summary:
   - P0 items in the priority-map that look CLOSED based on git (matching merged PR)
   - P1 items in the priority-map that look CLOSED based on git
   - New items detected in git that should be promoted to P0/P1 (large features, recent PRs with no card in the map)
   - P0/P1 items with NO activity in 7 days → flag as stale
   - Concrete question at the end: "Confirm moving items [X, Y, Z] to archive and adding [A, B] to P0/P1?"

2. \`$PROPOSAL_FILE\` — full proposal for the new priority-map.md:
   - Same structure as current
   - Closed items removed
   - New items added in the matching bucket
   - 'Updated:' field set to $TIMESTAMP
   - 'Sprint:' field only if you can infer it from context, otherwise leave it
   - Do NOT overwrite \`$PRIORITY_MAP\` directly — only the .proposed file

**Rules:**
- Conservative: if an item does not clearly match a merged PR, do NOT move it to the archive.
- If there isn't enough evidence to propose changes → write "No changes suggested — priority-map looks up to date" in the review summary.
- Do not invent new P0s without git evidence.
PROMPT_EOF
)

# Resolve claude CLI: prefer PATH, fall back gracefully if not found.
CLAUDE_BIN=$(command -v claude || true)
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "ERROR: claude CLI not found in PATH" >> "$LOG_FILE"
  rm -rf "$ISOLATED_SESSION_DIR"
  exit 1
fi

echo "Running claude -p..." >> "$LOG_FILE"
"$CLAUDE_BIN" -p "$PROMPT" \
  --allowed-tools "Read,Write,Edit,Bash,Glob,Grep" \
  >> "$LOG_FILE" 2>&1 || {
  echo "ERROR: claude -p failed" >> "$LOG_FILE"
  /usr/bin/osascript -e 'display notification "claude -p failed — check ~/.claude/logs/priority-map-review.log" with title "Priority Map Review"' 2>/dev/null || true
  rm -rf "$ISOLATED_SESSION_DIR"
  exit 1
}

rm -rf "$ISOLATED_SESSION_DIR"

# Notify via macOS notification center (no-op on Linux).
if [[ -f "$REVIEW_SUMMARY" ]]; then
  /usr/bin/osascript -e "display notification \"Review $REVIEW_SUMMARY and $PROPOSAL_FILE\" with title \"Priority Map Review — Monday\" sound name \"Purr\"" 2>/dev/null || true
  echo "OK — files generated: $REVIEW_SUMMARY, $PROPOSAL_FILE" >> "$LOG_FILE"
else
  /usr/bin/osascript -e 'display notification "Review produced no files — check ~/.claude/logs/priority-map-review.log" with title "Priority Map Review"' 2>/dev/null || true
  echo "WARNING: claude -p finished but $REVIEW_SUMMARY is missing" >> "$LOG_FILE"
fi

echo "=== end $(date) ===" >> "$LOG_FILE"
exit 0
