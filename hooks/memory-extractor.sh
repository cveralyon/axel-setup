#!/bin/bash
# Extract key decisions and learnings from session and persist to memory.
# Runs async from Stop hook. Uses Sonnet for quality extraction.
#
# Ghost-session cleanup: Claude Code v2.1.x has a bug where
# --no-session-persistence does NOT prevent the JSONL from being written to
# ~/.claude/projects/. The workaround is to run the subprocess from a temporary
# cwd (so its JSONL lands in a bucket unique to this hook) and rm -rf both the
# tmp cwd and its projects/ bucket when done. Memory output still lands in
# ~/.claude/memory/, which is completely unaffected.

set -e

# Guard: prevent recursive invocation. This script spawns `claude -p`, which
# fires Stop hooks again when it finishes. Without this guard the hook loops
# infinitely (each ghost session triggering another extraction).
if [ -n "$CLAUDE_MEMORY_EXTRACTOR" ]; then
  exit 0
fi

# Rate limit: debounce consecutive commits — skip if run within last 5 minutes.
LAST_RUN_FILE="$HOME/.claude/memory/.last_extraction"
if [ -f "$LAST_RUN_FILE" ]; then
  LAST_TS=$(stat -f %m "$LAST_RUN_FILE" 2>/dev/null || stat -c %Y "$LAST_RUN_FILE" 2>/dev/null)
  NOW_TS=$(date +%s)
  if [ -n "$LAST_TS" ] && [ $((NOW_TS - LAST_TS)) -lt 300 ]; then
    exit 0
  fi
fi
mkdir -p "$HOME/.claude/memory"
touch "$LAST_RUN_FILE"

# Bootstrap substitutes these placeholders at install time via --user-context
# and --language flags. The `case` fallback kicks in when the script runs
# without bootstrap: sed never replaced the token, so it still starts with
# `{{` and ends with `}}`. (We cannot compare against the literal token here
# — bootstrap's sed would rewrite both sides of the comparison at install.)
USER_CONTEXT="{{USER_CONTEXT}}"
case "$USER_CONTEXT" in "{{"*"}}"|"") USER_CONTEXT="a software engineer" ;; esac
ASSISTANT_LANGUAGE="{{ASSISTANT_LANGUAGE}}"
case "$ASSISTANT_LANGUAGE" in "{{"*"}}"|"") ASSISTANT_LANGUAGE="english" ;; esac

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

MEMORY_DIR="$HOME/.claude/memory"
DECISIONS_DIR="$MEMORY_DIR/decisions"
TIMESTAMP=$(date +%Y-%m-%d)

mkdir -p "$DECISIONS_DIR"

# Extract conversation from transcript if available
CONVERSATION=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  CONVERSATION=$(cat "$TRANSCRIPT" | \
    jq -r 'select(.type == "human" or .type == "assistant") |
      if .type == "human" then "USER: " + (.message // .content // "" | tostring)[:500]
      elif .type == "assistant" then "CLAUDE: " + (.message // .content // "" | tostring)[:500]
      else empty end' 2>/dev/null | tail -60 | head -c 25000)
fi

# Fallback: use checkpoints + latest session summary
if [ -z "$CONVERSATION" ] || [ ${#CONVERSATION} -lt 200 ]; then
  PROJECT_NAME=$(basename "${CWD:-$(pwd)}")
  SESSION_DIR="$HOME/.claude/sessions"
  CHECKPOINT_DIR="$SESSION_DIR/checkpoints"
  TODAY=$(date +%Y-%m-%d)

  CHECKPOINTS=""
  if [ -d "$CHECKPOINT_DIR" ]; then
    for f in $(ls -t "$CHECKPOINT_DIR"/${PROJECT_NAME}_${TODAY}*.md 2>/dev/null | head -10); do
      CP_CONTENT=$(sed -n '/^---$/,/^---$/!p' "$f" 2>/dev/null)
      if [ -n "$CP_CONTENT" ]; then
        CHECKPOINTS="$CHECKPOINTS
$CP_CONTENT
---
"
      fi
    done
  fi

  LATEST_SUMMARY=""
  LATEST_FILE=$(ls -t "$SESSION_DIR"/${PROJECT_NAME}_${TODAY}*.md 2>/dev/null | head -1)
  if [ -n "$LATEST_FILE" ] && [ -f "$LATEST_FILE" ]; then
    LATEST_SUMMARY=$(cat "$LATEST_FILE" | head -c 10000)
  fi

  CONVERSATION="$CHECKPOINTS
$LATEST_SUMMARY"
fi

# Skip if no meaningful content
if [ -z "$CONVERSATION" ] || [ ${#CONVERSATION} -lt 200 ]; then
  exit 0
fi

# Read current MEMORY.md for dedup context
CURRENT_MEMORY=""
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
  CURRENT_MEMORY=$(cat "$MEMORY_DIR/MEMORY.md")
fi

# Use Sonnet to extract decisions worth remembering
{
  PROMPT=$(printf 'You are an intelligent memory extractor for a programming assistant. Analyze the session conversation and determine if there is valuable information that should persist in memory for future sessions. Respond in %s.

The user is %s.

MEMORY TYPES:
- user: info about the user (role, preferences, skills, personal context)
- feedback: corrections or confirmations about how to work (dos and donts)
- project: technical decisions, architecture changes, project state, team info
- reference: where to find info in external systems (URLs, IDs, channels)

STRICT RULES:
- Only extract NON-OBVIOUS information that cannot be derived by reading the code.
- DEDUPLICATION: walk the full MEMORY.md index before creating anything. If a topic is already covered by an existing memory — even under a different name, or as part of a consolidated entry — do NOT create a new one. What matters is whether the INFORMATION is already captured, not whether the filename matches.
- For feedback and project types, include **Why:** and **How to apply:** lines.
- If nothing significant to persist, respond EXACTLY: NOTHING
- If something exists, respond in JSON array format (max 2 entries per session).
- Filenames must be descriptive: type_topic.md (e.g.: project_people_finder_v2.md).
- Keep index_line descriptions under 60 characters.

JSON format when there is something:
[{"filename": "type_topic.md", "name": "Descriptive name", "description": "One line for MEMORY.md index", "type": "user|feedback|project|reference", "content": "Full memory content", "index_line": "- [Name](type_topic.md) — short description"}]

Current memory (to avoid duplicates):
%s

Session conversation:
%s' "$ASSISTANT_LANGUAGE" "$USER_CONTEXT" "$CURRENT_MEMORY" "$CONVERSATION")

  HOOK_TMP=$(mktemp -d 2>/dev/null)
  HOOK_TMP_REAL=$(cd "$HOOK_TMP" 2>/dev/null && pwd -P)
  EXTRACTION=$(cd "$HOOK_TMP" 2>/dev/null && printf '%s' "$PROMPT" | CLAUDE_MEMORY_EXTRACTOR=1 claude -p --model sonnet 2>/dev/null)

  # Cleanup the ghost session JSONL bucket that claude -p created.
  # Claude slugifies the cwd by replacing any non-alphanumeric char with '-',
  # so use pwd -P (resolved physical path) and the same regex to reconstruct it.
  if [ -n "$HOOK_TMP_REAL" ]; then
    GHOST_SLUG=$(echo "$HOOK_TMP_REAL" | sed 's|[^a-zA-Z0-9]|-|g')
    rm -rf "$HOOK_TMP" "$HOME/.claude/projects/${GHOST_SLUG}" 2>/dev/null
  fi

  if [ -z "$EXTRACTION" ] || echo "$EXTRACTION" | grep -qi "NOTHING"; then
    exit 0
  fi

  # Extract JSON from response
  JSON_EXTRACTION=$(echo "$EXTRACTION" | sed -n '/^\[/,/^\]/p' | head -c 10000)
  if [ -z "$JSON_EXTRACTION" ]; then
    JSON_EXTRACTION=$(echo "$EXTRACTION" | sed -n '/```json/,/```/p' | sed '1d;$d' | head -c 10000)
  fi
  if [ -z "$JSON_EXTRACTION" ]; then
    JSON_EXTRACTION="$EXTRACTION"
  fi

  # Validate JSON
  if ! echo "$JSON_EXTRACTION" | jq '.' >/dev/null 2>&1; then
    exit 0
  fi

  # Process each memory entry
  ENTRIES=$(echo "$JSON_EXTRACTION" | jq -r 'length')
  for i in $(seq 0 $((ENTRIES - 1))); do
    FILENAME=$(echo "$JSON_EXTRACTION" | jq -r ".[$i].filename")
    NAME=$(echo "$JSON_EXTRACTION" | jq -r ".[$i].name")
    DESC=$(echo "$JSON_EXTRACTION" | jq -r ".[$i].description")
    TYPE=$(echo "$JSON_EXTRACTION" | jq -r ".[$i].type")
    CONTENT=$(echo "$JSON_EXTRACTION" | jq -r ".[$i].content")
    INDEX_LINE=$(echo "$JSON_EXTRACTION" | jq -r ".[$i].index_line")

    if [ -z "$FILENAME" ] || [ "$FILENAME" = "null" ]; then
      continue
    fi

    FILEPATH="$MEMORY_DIR/$FILENAME"

    # Don't overwrite manually curated memory files
    if [ -f "$FILEPATH" ] && [[ "$FILENAME" != decisions/* ]]; then
      continue
    fi

    cat > "$FILEPATH" << ENDOFFILE
---
name: $NAME
description: $DESC
type: $TYPE
auto_extracted: true
date: $TIMESTAMP
session_id: $SESSION_ID
---

$CONTENT
ENDOFFILE

    # Add to MEMORY.md index if not already there
    if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
      if ! grep -qF "$FILENAME" "$MEMORY_DIR/MEMORY.md"; then
        echo "$INDEX_LINE" >> "$MEMORY_DIR/MEMORY.md"
      fi
    fi
  done

  # Cleanup: keep only last 20 decision files
  if [ -d "$DECISIONS_DIR" ]; then
    ls -t "$DECISIONS_DIR"/*.md 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null
  fi

  # Run dedup check
  QUIET=true zsh "$HOME/.claude/hooks/memory-dedup.sh" 2>/dev/null || true

} &

exit 0
