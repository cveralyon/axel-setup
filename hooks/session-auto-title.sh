#!/bin/bash
# Auto-name session based on user's first prompt.
# Uses hookSpecificOutput.sessionTitle (Claude Code v2.1.94+).
# Idempotency via a flag file in ~/.claude/session-env/ — avoids slow find recursion.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

[ -z "$PROMPT" ] || [ -z "$SESSION_ID" ] && exit 0

# Idempotency: skip if we already titled this session
FLAG_DIR="$HOME/.claude/session-env"
FLAG_FILE="$FLAG_DIR/titled-${SESSION_ID}.flag"
mkdir -p "$FLAG_DIR" 2>/dev/null
[ -f "$FLAG_FILE" ] && exit 0

# --- Smart title extraction ---

# 1. Flatten to single line, collapse whitespace
CLEAN=$(echo "$PROMPT" | tr '\n' ' ' | sed 's/[[:space:]]\{2,\}/ /g' | sed 's/^[[:space:]]*//')

# 2. Strip leading assistant names ("Axel, ...", "Claude, ...")
#    BSD sed supports the I suffix for case-insensitive matching.
ASSISTANT_RE='^(axel|claude|assistant|asistente|bot)[,.:;!? ]+'
CLEAN=$(echo "$CLEAN" | sed -E "s/$ASSISTANT_RE//I" | sed 's/^[[:space:]]*//')

# 3. Strip leading filler/greetings (ES + EN) — run twice to catch chains like "ok dale,"
FILLER_RE='^(hola|hey|oye|dale|ok|bueno|bien|mira|vamos a|quiero que|necesito que|por favor|please|hi|hello|can you|could you|I need you to|I want you to)[,.:;!? ]*'
CLEAN=$(echo "$CLEAN" | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//' | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//')

# 4. Strip leading greeting questions ("¿cómo estás?", "qué tal?", "how are you?")
GREETING_Q_RE='^[¿?]*(cómo estás|como estas|qué tal|que tal|cómo va|como va|how are you|hows it going)[?!.,;: ]*'
CLEAN=$(echo "$CLEAN" | sed -E "s/$GREETING_Q_RE//I" | sed 's/^[[:space:]]*//')

# 5. Re-apply filler after greeting removal ("Axel, ¿cómo estás? Oye, quiero que...")
CLEAN=$(echo "$CLEAN" | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//' | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//')

# 6. Strip leading slash commands (e.g., /commit, /review-pr 123)
CLEAN=$(echo "$CLEAN" | sed -E 's/^\/[a-zA-Z0-9_:-]+[[:space:]]*//')

# 7. Extract first meaningful clause:
#    - Up to first period, question mark, exclamation, or newline
FIRST_SENTENCE=$(echo "$CLEAN" | sed -E 's/[.?!].*//' | head -1)

# If result is very long, cut at comma or dash after 25+ chars
if [ ${#FIRST_SENTENCE} -gt 55 ]; then
  SHORT=$(echo "$FIRST_SENTENCE" | cut -c1-55 | sed -E 's/(.*[,;:—–-]).*/\1/' | sed 's/[,;:—–-]$//')
  # Only use shorter version if it's still meaningful (>15 chars)
  [ ${#SHORT} -gt 15 ] && FIRST_SENTENCE="$SHORT"
fi

# 5. Truncate at word boundary if still too long
if [ ${#FIRST_SENTENCE} -gt 55 ]; then
  FIRST_SENTENCE=$(echo "$FIRST_SENTENCE" | cut -c1-55 | sed 's/[[:space:]][^[:space:]]*$//')
fi

# 6. Capitalize first letter (awk for macOS compat — BSD sed lacks \U)
TITLE=$(echo "$FIRST_SENTENCE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}' | sed 's/[[:space:]]*$//')

# 7. Fallback: if title is too short, use first 40 chars of original
if [ ${#TITLE} -lt 5 ]; then
  TITLE=$(echo "$CLEAN" | cut -c1-40 | sed 's/[[:space:]][^[:space:]]*$//')
fi

# Escape quotes for JSON safety
TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')

[ -z "$TITLE" ] && exit 0

# Mark as titled so we don't re-run on subsequent prompts
touch "$FLAG_FILE" 2>/dev/null

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "sessionTitle": "$TITLE"
  }
}
EOF

exit 0
