#!/bin/bash
# Compile full session context on Stop for persistence between sessions
# Combines: user prompts + actions taken + git state → structured session file

SESSION_DIR="$HOME/.claude/sessions"
mkdir -p "$SESSION_DIR"

PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
SESSION_FILE="$SESSION_DIR/${PROJECT_NAME}_${TIMESTAMP}.md"
SESSION_LOG="/tmp/claude-session-log-${PROJECT_NAME}.md"

# --- Git State ---
GIT_INFO=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  LAST_COMMITS=$(git log --oneline -5 2>/dev/null)
  MODIFIED=$(git diff --name-only 2>/dev/null | head -20)
  STAGED=$(git diff --cached --name-only 2>/dev/null | head -20)
  GIT_INFO="## Estado Git
- **Branch:** $BRANCH

**Últimos commits:**
\`\`\`
$LAST_COMMITS
\`\`\`"

  if [ -n "$MODIFIED" ]; then
    GIT_INFO="$GIT_INFO

**Archivos modificados (sin commit):**
\`\`\`
$MODIFIED
\`\`\`"
  fi

  if [ -n "$STAGED" ]; then
    GIT_INFO="$GIT_INFO

**Archivos staged:**
\`\`\`
$STAGED
\`\`\`"
  fi
fi

# --- Conversation Log ---
CONVERSATION=""
if [ -f "$SESSION_LOG" ]; then
  CONVERSATION="## Conversación y Acciones

$(cat "$SESSION_LOG")"
fi

# --- Write session file ---
cat > "$SESSION_FILE" << ENDOFFILE
---
project: $PROJECT_NAME
directory: $PROJECT_DIR
date: $(date +%Y-%m-%d)
time: $(date +%H:%M)
---

# Sesión: $PROJECT_NAME — $(date +%Y-%m-%d) $(date +%H:%M)

$CONVERSATION

$GIT_INFO

## Directorio
$PROJECT_DIR
ENDOFFILE

# Cleanup: keep last 20 session files per project
ls -t "$SESSION_DIR"/${PROJECT_NAME}_*.md 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null

# Clear the temp log for next session
rm -f "$SESSION_LOG"

exit 0
