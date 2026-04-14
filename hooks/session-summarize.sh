#!/bin/bash
# Final session summarizer: compiles checkpoints + conversation into
# one coherent session summary. Uses Sonnet for quality. Runs async from Stop hook.
#
# Ghost-session cleanup: Claude Code v2.1.x has a bug where
# --no-session-persistence does NOT prevent the JSONL from being written to
# ~/.claude/projects/. The workaround is to run the subprocess from a temporary
# cwd (so its JSONL lands in a bucket unique to this hook) and rm -rf both the
# tmp cwd and its projects/ bucket when done. The summary output still lands in
# ~/.claude/sessions/, which is what session-restore reads on the next startup.

set -e
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

PROJECT_NAME=$(basename "${CWD:-$(pwd)}")
SESSION_DIR="$HOME/.claude/sessions"
CHECKPOINT_DIR="$SESSION_DIR/checkpoints"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
SESSION_FILE="$SESSION_DIR/${PROJECT_NAME}_${TIMESTAMP}.md"

# Bootstrap substitutes these placeholders at install time via --user-name,
# --user-context and --language flags. The `case` fallback kicks in when the
# script runs without bootstrap: sed never replaced the token, so it still
# starts with `{{` and ends with `}}`. (We cannot compare against the literal
# token here — bootstrap's sed would rewrite both sides of the comparison.)
USER_NAME="{{USER_NAME}}"
case "$USER_NAME" in "{{"*"}}"|"") USER_NAME=$(whoami) ;; esac
USER_CONTEXT="{{USER_CONTEXT}}"
case "$USER_CONTEXT" in "{{"*"}}"|"") USER_CONTEXT="a software engineer" ;; esac
ASSISTANT_LANGUAGE="{{ASSISTANT_LANGUAGE}}"
case "$ASSISTANT_LANGUAGE" in "{{"*"}}"|"") ASSISTANT_LANGUAGE="english" ;; esac

mkdir -p "$SESSION_DIR"

# 1. Gather checkpoint summaries from this session
CHECKPOINTS=""
TODAY=$(date +%Y-%m-%d)
if [ -d "$CHECKPOINT_DIR" ]; then
  for f in $(ls -t "$CHECKPOINT_DIR"/${PROJECT_NAME}_${TODAY}*.md 2>/dev/null | head -10); do
    CP_CONTENT=$(sed -n '/^---$/,/^---$/!p' "$f" 2>/dev/null)
    if [ -n "$CP_CONTENT" ]; then
      CHECKPOINTS="$CHECKPOINTS
--- Checkpoint ---
$CP_CONTENT
"
    fi
  done
fi

# 2. Extract conversation from transcript
CONVERSATION=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  CONVERSATION=$(cat "$TRANSCRIPT" | \
    jq -r 'select(.type == "human" or .type == "assistant") |
      if .type == "human" then "USER: " + (.message // .content // "" | tostring)[:500]
      elif .type == "assistant" then "CLAUDE: " + (.message // .content // "" | tostring)[:500]
      else empty end' 2>/dev/null | tail -80 | head -c 30000)
fi

# 3. Git state
GIT_INFO=""
if cd "$CWD" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  COMMITS=$(git log --oneline -10 2>/dev/null)
  MODIFIED=$(git diff --name-only 2>/dev/null | head -20)
  GIT_INFO="Branch: $BRANCH
Commits: $COMMITS
Modified: $MODIFIED"
fi

# Skip if nothing to summarize
if [ -z "$CHECKPOINTS" ] && [ -z "$CONVERSATION" ] && [ -z "$GIT_INFO" ]; then
  exit 0
fi

# 4. Compile final summary with Sonnet (cwd-isolated — see header comment)
{
  HOOK_TMP=$(mktemp -d 2>/dev/null)
  HOOK_TMP_REAL=$(cd "$HOOK_TMP" 2>/dev/null && pwd -P)
  SUMMARY=$(cd "$HOOK_TMP" 2>/dev/null && printf "You are an assistant that summarizes programming work sessions for %s (%s). Compile a coherent final summary. Respond in %s.

You have 2 sources:
- Checkpoints (partial summaries made during the session)
- Recent conversation (user and assistant messages)

Generate a structured summary with:
1. **Session objective** — what the user wanted to accomplish
2. **What was done** — concrete actions, modified files, tools used
3. **Key decisions** — technical and architecture decisions, and why
4. **Status at close** — how things ended, what's left to do
5. **Important context** — anything the next session needs to know
6. **User feedback** — if the user corrected or confirmed an approach

Maximum 30 lines. No intro, straight to content. If checkpoints cover everything, synthesize and add what's missing from the conversation.

Checkpoints:
%s

Recent conversation:
%s

Git:
%s" "$USER_NAME" "$USER_CONTEXT" "$ASSISTANT_LANGUAGE" "$CHECKPOINTS" "$CONVERSATION" "$GIT_INFO" | claude -p --model sonnet 2>/dev/null)

  # Cleanup the ghost session JSONL bucket that claude -p created.
  # Claude slugifies the cwd by replacing any non-alphanumeric char with '-',
  # so use pwd -P (resolved physical path) and the same regex to reconstruct it.
  if [ -n "$HOOK_TMP_REAL" ]; then
    GHOST_SLUG=$(echo "$HOOK_TMP_REAL" | sed 's|[^a-zA-Z0-9]|-|g')
    rm -rf "$HOOK_TMP" "$HOME/.claude/projects/${GHOST_SLUG}" 2>/dev/null
  fi

  if [ -z "$SUMMARY" ]; then
    SUMMARY="## Checkpoints
$CHECKPOINTS

## Recent conversation
$(echo "$CONVERSATION" | head -c 5000)"
  fi

  cat > "$SESSION_FILE" << ENDOFFILE
---
project: $PROJECT_NAME
directory: $CWD
date: $(date +%Y-%m-%d)
time: $(date +%H:%M)
session_id: $SESSION_ID
---

# Session: $PROJECT_NAME — $(date +%Y-%m-%d) $(date +%H:%M)

$SUMMARY

## Git
- **Branch:** $(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || echo "N/A")
$(cd "$CWD" 2>/dev/null && git log --oneline -5 2>/dev/null | sed 's/^/- /' || echo "- N/A")
ENDOFFILE

  # Cleanup sessions (keep 30) and old checkpoints
  ls -t "$SESSION_DIR"/${PROJECT_NAME}_*.md 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null
  find "$CHECKPOINT_DIR" -name "${PROJECT_NAME}_*.md" -mtime +7 -delete 2>/dev/null

  # Reset counters for next session
  rm -f "/tmp/claude-checkpoint-counter-${PROJECT_NAME}"
  rm -f "/tmp/claude-last-checkpoint-${PROJECT_NAME}"
  rm -f "/tmp/claude-session-log-${PROJECT_NAME}.md"

} &

exit 0
