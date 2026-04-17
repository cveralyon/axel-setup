#!/bin/bash
# Auto-name session based on user's first prompt.
# Uses hookSpecificOutput.sessionTitle (Claude Code v2.1.94+).
#
# Strategy:
#   1st prompt: regex fallback immediately + launch LLM synthesis in background
#   2nd+ prompt: if LLM result ready, replace title with synthesized version
#   Final flag set once synthesized title is applied.
#
# Requires: jq, claude CLI in PATH.
# Guard env var: CLAUDE_HOOK_RUNNING (prevents recursion when background
# `claude -p` re-enters UserPromptSubmit).

[ -n "$CLAUDE_HOOK_RUNNING" ] && exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

[ -z "$PROMPT" ] || [ -z "$SESSION_ID" ] && exit 0

STATE_DIR="$HOME/.claude/session-env"
mkdir -p "$STATE_DIR" 2>/dev/null

FINAL_FLAG="$STATE_DIR/titled-${SESSION_ID}.flag"
LAUNCHED_FLAG="$STATE_DIR/title-launched-${SESSION_ID}.flag"
TITLE_FILE="$STATE_DIR/title-${SESSION_ID}.txt"

[ -f "$FINAL_FLAG" ] && exit 0

# Language of the synthesized title. Override via AXEL_TITLE_LANGUAGE env var.
# Default injected at install time; leave as placeholder when editing directly.
TITLE_LANGUAGE="${AXEL_TITLE_LANGUAGE:-{{ASSISTANT_LANGUAGE}}}"
case "$TITLE_LANGUAGE" in "{{"*"}}"|"") TITLE_LANGUAGE="english" ;; esac

# --- Helpers ---

emit_title() {
  local t="$1"
  t=$(printf '%s' "$t" | sed 's/"/\\"/g')
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "sessionTitle": "$t"
  }
}
EOF
}

regex_title() {
  local p="$1"
  local CLEAN
  CLEAN=$(printf '%s' "$p" | tr '\n' ' ' | sed 's/[[:space:]]\{2,\}/ /g' | sed 's/^[[:space:]]*//')
  local ASSISTANT_RE='^(axel|claude|assistant|asistente|bot)[,.:;!? ]+'
  CLEAN=$(printf '%s' "$CLEAN" | sed -E "s/$ASSISTANT_RE//I" | sed 's/^[[:space:]]*//')
  local FILLER_RE='^(hola|hey|oye|dale|ok|bueno|bien|mira|vamos a|quiero que|necesito que|por favor|please|hi|hello|can you|could you|I need you to|I want you to)[,.:;!? ]*'
  CLEAN=$(printf '%s' "$CLEAN" | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//' | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//')
  local GREETING_Q_RE='^[¿?]*(cómo estás|como estas|qué tal|que tal|cómo va|como va|how are you|hows it going)[?!.,;: ]*'
  CLEAN=$(printf '%s' "$CLEAN" | sed -E "s/$GREETING_Q_RE//I" | sed 's/^[[:space:]]*//')
  CLEAN=$(printf '%s' "$CLEAN" | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//' | sed -E "s/$FILLER_RE//I" | sed 's/^[[:space:]]*//')
  CLEAN=$(printf '%s' "$CLEAN" | sed -E 's/^\/[a-zA-Z0-9_:-]+[[:space:]]*//')
  local FIRST
  FIRST=$(printf '%s' "$CLEAN" | sed -E 's/[.?!].*//' | head -1)
  if [ ${#FIRST} -gt 55 ]; then
    local SHORT
    SHORT=$(printf '%s' "$FIRST" | cut -c1-55 | sed -E 's/(.*[,;:—–-]).*/\1/' | sed 's/[,;:—–-]$//')
    [ ${#SHORT} -gt 15 ] && FIRST="$SHORT"
  fi
  if [ ${#FIRST} -gt 55 ]; then
    FIRST=$(printf '%s' "$FIRST" | cut -c1-55 | sed 's/[[:space:]][^[:space:]]*$//')
  fi
  local TITLE
  TITLE=$(printf '%s' "$FIRST" | awk '{print toupper(substr($0,1,1)) substr($0,2)}' | sed 's/[[:space:]]*$//')
  if [ ${#TITLE} -lt 5 ]; then
    TITLE=$(printf '%s' "$CLEAN" | cut -c1-40 | sed 's/[[:space:]][^[:space:]]*$//')
  fi
  printf '%s' "$TITLE"
}

launch_synthesis_bg() {
  local prompt="$1"
  local outfile="$2"
  local lang="$3"

  (
    export CLAUDE_HOOK_RUNNING=1
    local HOOK_TMP
    HOOK_TMP=$(mktemp -d 2>/dev/null) || exit 0
    local HOOK_TMP_REAL
    HOOK_TMP_REAL=$(cd "$HOOK_TMP" 2>/dev/null && pwd -P)

    local SYSTEM_PROMPT="You extract session titles for coding sessions. Read the user's first message and synthesize a brief title that summarizes the TOPIC of the conversation, not the requested action.

RULES:
- Max 55 characters
- Language: ${lang}
- No emojis, no quotes, no trailing period
- Summarize the concrete TOPIC (product, feature, file, bug), not the leading verb
- Plain text, single line

Respond with ONLY the title, nothing else."

    local SYNTHESIS_PROMPT="User's first message:

${prompt:0:1500}"

    local TITLE
    TITLE=$( \
      cd "$HOOK_TMP" 2>/dev/null && \
      printf '%s' "$SYNTHESIS_PROMPT" | \
      timeout 45 claude -p \
        --model sonnet \
        --append-system-prompt "$SYSTEM_PROMPT" \
        2>/dev/null \
    )

    # Ghost JSONL cleanup: claude -p writes under ~/.claude/projects/<slug>
    # even with --no-session-persistence (bug in v2.1.x).
    if [ -n "$HOOK_TMP_REAL" ]; then
      local GHOST_SLUG
      GHOST_SLUG=$(printf '%s' "$HOOK_TMP_REAL" | sed 's|[^a-zA-Z0-9]|-|g')
      rm -rf "$HOOK_TMP" "$HOME/.claude/projects/${GHOST_SLUG}" 2>/dev/null
    fi

    TITLE=$(printf '%s' "$TITLE" | head -1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
    TITLE="${TITLE:0:55}"

    if [ -n "$TITLE" ] && [ ${#TITLE} -ge 5 ]; then
      printf '%s\n' "$TITLE" > "$outfile"
    fi
  ) &

  disown
}

cleanup_session_state() {
  rm -f "$TITLE_FILE" "$LAUNCHED_FLAG" 2>/dev/null
}

# --- Main logic ---

# Case 1: synthesized title ready -> apply + mark final + cleanup
if [ -f "$TITLE_FILE" ]; then
  SYNTH_TITLE=$(head -1 "$TITLE_FILE" 2>/dev/null)
  if [ -n "$SYNTH_TITLE" ] && [ ${#SYNTH_TITLE} -ge 5 ]; then
    touch "$FINAL_FLAG"
    cleanup_session_state
    emit_title "$SYNTH_TITLE"
    exit 0
  fi
fi

# Case 2: first prompt -> regex fallback + launch bg synthesis
if [ ! -f "$LAUNCHED_FLAG" ]; then
  touch "$LAUNCHED_FLAG"
  TITLE=$(regex_title "$PROMPT")
  [ -z "$TITLE" ] && exit 0
  launch_synthesis_bg "$PROMPT" "$TITLE_FILE" "$TITLE_LANGUAGE"
  emit_title "$TITLE"
  exit 0
fi

# Case 3: synthesis launched but not ready yet -> exit silently (regex title stays)
exit 0
