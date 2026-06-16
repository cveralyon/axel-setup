#!/bin/bash
# Restore recent session context on SessionStart
# Shows what was discussed, what was done, and current git state

SESSION_DIR="$HOME/.claude/sessions"
PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Find the 3 most recent sessions for this project (for broader context)
SESSIONS=$(ls -t "$SESSION_DIR"/${PROJECT_NAME}_*.md 2>/dev/null | head -3)

if [ -z "$SESSIONS" ]; then
  exit 0
fi

LATEST=$(printf '%s' "$SESSIONS" | head -1)
SESSION_DATE=$(grep "^date:" "$LATEST" 2>/dev/null | cut -d' ' -f2)
SESSION_TIME=$(grep "^time:" "$LATEST" 2>/dev/null | cut -d' ' -f2)

echo "=== Contexto de sesiones anteriores ($PROJECT_NAME) ==="
echo ""

# Show the latest session in full
echo "### Última sesión: $SESSION_DATE $SESSION_TIME"
# Skip frontmatter, show content
sed -n '/^---$/,/^---$/!p' "$LATEST" | head -80
echo ""

# Show previous sessions as one-liners
OTHERS=$(printf '%s' "$SESSIONS" | tail -n +2)
if [ -n "$OTHERS" ]; then
  echo "### Sesiones anteriores:"
  for f in $OTHERS; do
    DATE=$(grep "^date:" "$f" 2>/dev/null | cut -d' ' -f2)
    TIME=$(grep "^time:" "$f" 2>/dev/null | cut -d' ' -f2)
    # Language-agnostic summary: take the body after the frontmatter, drop the
    # leading H1 title and any markdown headings/blank lines, then keep the
    # first real content line. Works regardless of the summary language.
    SUMMARY=$(sed -n '/^---$/,/^---$/!p' "$f" 2>/dev/null \
      | grep -vE '^[[:space:]]*$|^#' \
      | head -1 \
      | head -c 100)
    echo "- **$DATE $TIME**: $SUMMARY"
  done
fi

echo ""
echo "=== Fin contexto previo ==="

exit 0
