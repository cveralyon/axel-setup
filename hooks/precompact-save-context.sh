#!/bin/zsh
# PreCompact hook: saves rich context before compaction discards messages.
# Extracts key files, pending work, decisions, and timeline.
# Pattern inspired by claw-code compact.rs — preserve what matters.

PROJECT_NAME=$(basename "$(pwd)")
CONTEXT_DIR="$HOME/.claude/sessions/context"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

mkdir -p "$CONTEXT_DIR"

# Read stdin for compaction context
INPUT=$(cat)
COMPACT_TYPE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('type','auto'))" 2>/dev/null || echo "auto")

CONTEXT_FILE="$CONTEXT_DIR/${PROJECT_NAME}_${TIMESTAMP}.md"

# --- Git state ---
GIT_STATE=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  RECENT_COMMITS=$(git log --oneline -10 2>/dev/null)
  MODIFIED=$(git diff --name-only 2>/dev/null | head -20)
  STAGED=$(git diff --cached --name-only 2>/dev/null | head -20)
  GIT_STATE="Branch: $BRANCH
Recent commits:
$RECENT_COMMITS
Modified files: $MODIFIED
Staged files: $STAGED"
fi

# --- Key files referenced in session ---
KEY_FILES=""
LOG_FILE="/tmp/claude-session-log-${PROJECT_NAME}.md"
if [ -f "$LOG_FILE" ]; then
  # Extract file paths mentioned in the session log (pattern: paths with extensions)
  KEY_FILES=$(grep -oE '[a-zA-Z0-9_/.-]+\.(rb|ts|tsx|js|jsx|py|rs|json|yml|yaml|md|sql|erb|rake)' "$LOG_FILE" 2>/dev/null | sort -u | head -15)
fi

# --- Pending work / TODOs ---
PENDING_WORK=""
if [ -f "$LOG_FILE" ]; then
  PENDING_WORK=$(grep -iE '(todo|next|pending|follow.up|remaining|fixme|hack|later)' "$LOG_FILE" 2>/dev/null | tail -10)
fi

# --- Recent session actions ---
SESSION_LOG=""
if [ -f "$LOG_FILE" ]; then
  SESSION_LOG=$(tail -40 "$LOG_FILE")
fi

# --- Active tasks (if GSD is running) ---
ACTIVE_TASKS=""
PLANNING_DIR="$(pwd)/.planning"
if [ -d "$PLANNING_DIR" ]; then
  # Find current phase
  CURRENT_PHASE=$(ls -d "$PLANNING_DIR"/phase-* 2>/dev/null | tail -1)
  if [ -n "$CURRENT_PHASE" ]; then
    ACTIVE_TASKS="Current phase: $(basename "$CURRENT_PHASE")"
    if [ -f "$CURRENT_PHASE/PLAN.md" ]; then
      # Extract incomplete tasks from plan
      INCOMPLETE=$(grep -E '^\s*-\s*\[ \]' "$CURRENT_PHASE/PLAN.md" 2>/dev/null | head -10)
      if [ -n "$INCOMPLETE" ]; then
        ACTIVE_TASKS="$ACTIVE_TASKS
Incomplete tasks:
$INCOMPLETE"
      fi
    fi
  fi
fi

# --- Decisions made (look for patterns in session) ---
DECISIONS=""
if [ -f "$LOG_FILE" ]; then
  DECISIONS=$(grep -iE '(decided|decision|chose|picked|went with|selected|agreed|confirmed)' "$LOG_FILE" 2>/dev/null | tail -5)
fi

# --- Memory files modified this session ---
MEMORY_CHANGES=""
MEMORY_DIR="$HOME/.claude/memory"
if [ -d "$MEMORY_DIR" ]; then
  # Files modified in the last 2 hours
  MEMORY_CHANGES=$(find "$MEMORY_DIR" -name "*.md" -mmin -120 -type f 2>/dev/null | while read f; do basename "$f"; done | head -10)
fi

cat > "$CONTEXT_FILE" << ENDOFFILE
---
project: $PROJECT_NAME
compact_type: $COMPACT_TYPE
date: $(date +%Y-%m-%d)
time: $(date +%H:%M)
---

# Pre-compact context snapshot

## Git state
$GIT_STATE

## Key files referenced
$KEY_FILES

## Pending work / TODOs
$PENDING_WORK

## Active tasks
$ACTIVE_TASKS

## Decisions made
$DECISIONS

## Memory files updated
$MEMORY_CHANGES

## Recent actions (last 40)
$SESSION_LOG
ENDOFFILE

# Keep only last 5 context snapshots per project
ls -t "$CONTEXT_DIR"/${PROJECT_NAME}_*.md 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null

# Output message to Claude about context being saved
echo '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"Se guardó un snapshot enriquecido del contexto antes de compactación en '"$CONTEXT_FILE"'. Incluye: archivos clave, trabajo pendiente, decisiones, tareas activas, y estado git. La memoria persistente en ~/.claude/memory/ sigue intacta."}}'

exit 0
