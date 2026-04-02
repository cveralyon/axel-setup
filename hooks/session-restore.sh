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

LATEST=$(echo "$SESSIONS" | head -1)
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
OTHERS=$(echo "$SESSIONS" | tail -n +2)
if [ -n "$OTHERS" ]; then
  echo "### Sesiones anteriores:"
  for f in $OTHERS; do
    DATE=$(grep "^date:" "$f" 2>/dev/null | cut -d' ' -f2)
    TIME=$(grep "^time:" "$f" 2>/dev/null | cut -d' ' -f2)
    # Extract first user prompt as summary
    SUMMARY=$(grep -A1 "Usuario" "$f" 2>/dev/null | grep -v "Usuario" | grep -v "^--$" | head -1 | head -c 100)
    echo "- **$DATE $TIME**: $SUMMARY"
  done
fi

echo ""
echo "=== Fin contexto previo ==="

exit 0
