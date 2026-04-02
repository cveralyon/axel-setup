#!/bin/bash
# Periodic session checkpoint: every ~40 tool calls, summarize what's happened
# since the last checkpoint. Uses Sonnet for quality. Runs async — non-blocking.
# --no-session-persistence prevents ghost sessions (only affects THIS subprocess,
# NOT the main session or memory system).

PROJECT_NAME=$(basename "$(pwd)")
COUNTER_FILE="/tmp/claude-checkpoint-counter-${PROJECT_NAME}"
CHECKPOINT_DIR="$HOME/.claude/sessions/checkpoints"
LAST_CHECKPOINT="/tmp/claude-last-checkpoint-${PROJECT_NAME}"
SESSION_LOG="/tmp/claude-session-log-${PROJECT_NAME}.md"

mkdir -p "$CHECKPOINT_DIR"

# Increment counter
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Checkpoint every 40 tool calls
if [ $((COUNT % 40)) -ne 0 ]; then
  exit 0
fi

CHECKPOINT_NUM=$((COUNT / 40))
TIMESTAMP=$(date +%Y-%m-%d_%H%M)

# Gather recent actions from the session log (since last checkpoint)
LAST_LINE=0
if [ -f "$LAST_CHECKPOINT" ]; then
  LAST_LINE=$(cat "$LAST_CHECKPOINT")
fi

RECENT_ACTIONS=""
if [ -f "$SESSION_LOG" ]; then
  TOTAL_LINES=$(wc -l < "$SESSION_LOG")
  if [ "$TOTAL_LINES" -gt "$LAST_LINE" ]; then
    RECENT_ACTIONS=$(tail -n +"$((LAST_LINE + 1))" "$SESSION_LOG" | head -c 8000)
  fi
  echo "$TOTAL_LINES" > "$LAST_CHECKPOINT"
fi

# Git state since last checkpoint
GIT_DIFF=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  GIT_DIFF="Branch: $BRANCH | Recent: $(git log --oneline -5 2>/dev/null | tr '\n' ' ') | Modified: $(git diff --name-only 2>/dev/null | head -15 | tr '\n' ', ')"
fi

# Skip if nothing meaningful happened
if [ -z "$RECENT_ACTIONS" ] && [ -z "$GIT_DIFF" ]; then
  exit 0
fi

# Summarize this chunk with Sonnet in background
{
  SUMMARY=$(printf "Resume este checkpoint de trabajo (#%s) en español. Máximo 15 líneas. Sé conciso pero completo.\n\nIncluye: qué se hizo, decisiones tomadas, archivos clave, contexto importante.\n\nAcciones recientes:\n%s\n\nGit:\n%s" "$CHECKPOINT_NUM" "$RECENT_ACTIONS" "$GIT_DIFF" | claude -p --model sonnet --no-session-persistence 2>/dev/null)

  if [ -n "$SUMMARY" ]; then
    CHECKPOINT_FILE="$CHECKPOINT_DIR/${PROJECT_NAME}_${TIMESTAMP}_cp${CHECKPOINT_NUM}.md"
    cat > "$CHECKPOINT_FILE" << ENDOFFILE
---
project: $PROJECT_NAME
checkpoint: $CHECKPOINT_NUM
tool_calls: $COUNT
date: $(date +%Y-%m-%d)
time: $(date +%H:%M)
---

$SUMMARY
ENDOFFILE
  fi

  # Cleanup: keep last 50 checkpoints per project
  ls -t "$CHECKPOINT_DIR"/${PROJECT_NAME}_*.md 2>/dev/null | tail -n +51 | xargs rm -f 2>/dev/null

} &

exit 0
