#!/bin/zsh
# Memory dedup check — hash-based duplicate detection + orphan cleanup
# Inspired by Claw Code's hash-based instruction file dedup.
# Uses zsh for associative array support on macOS.
#
# Run standalone: zsh memory-dedup.sh
# Exit codes: 0 = clean/fixed

MEMORY_DIR="${MEMORY_DIR:-$HOME/.claude/memory}"
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
LOG_FILE="$HOME/.claude/logs/memory-dedup.log"
QUIET="${QUIET:-false}"

mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date +%H:%M:%S)] $1" >> "$LOG_FILE"; [[ "$QUIET" == "true" ]] || echo "$1"; }

found_issues=0

# --- 1. Content-based duplicate detection ---
typeset -A hash_map

for f in "$MEMORY_DIR"/*.md(N); do
  [[ ! -f "$f" ]] && continue
  local BASENAME="${f:t}"
  [[ "$BASENAME" == "MEMORY.md" ]] && continue

  local BODY=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$f")
  [[ -z "$BODY" ]] && continue
  local HASH=$(echo "$BODY" | md5 -q)

  if [[ -n "${hash_map[$HASH]}" ]]; then
    local EXISTING="${hash_map[$HASH]}"
    log "DUPLICATE: $BASENAME has identical content to $EXISTING"

    if grep -qF "$EXISTING" "$MEMORY_INDEX" 2>/dev/null; then
      log "  -> Removing $BASENAME (keeping indexed $EXISTING)"
      rm "$f"
      found_issues=1
    elif grep -qF "$BASENAME" "$MEMORY_INDEX" 2>/dev/null; then
      log "  -> Removing $EXISTING (keeping indexed $BASENAME)"
      rm "$MEMORY_DIR/$EXISTING"
      hash_map[$HASH]="$BASENAME"
      found_issues=1
    else
      if [[ "$f" -nt "$MEMORY_DIR/$EXISTING" ]]; then
        log "  -> Removing $EXISTING (keeping newer $BASENAME)"
        rm "$MEMORY_DIR/$EXISTING"
        hash_map[$HASH]="$BASENAME"
      else
        log "  -> Removing $BASENAME (keeping newer $EXISTING)"
        rm "$f"
      fi
      found_issues=1
    fi
  else
    hash_map[$HASH]="$BASENAME"
  fi
done

# --- 2. Semantic duplicate detection (same frontmatter name) ---
typeset -A name_map

for f in "$MEMORY_DIR"/*.md(N); do
  [[ ! -f "$f" ]] && continue
  local BASENAME="${f:t}"
  [[ "$BASENAME" == "MEMORY.md" ]] && continue

  local NAME=$(awk '/^name:/{sub(/^name: */, ""); print; exit}' "$f")
  [[ -z "$NAME" ]] && continue
  local NAME_LOWER="${NAME:l}"

  if [[ -n "${name_map[$NAME_LOWER]}" ]]; then
    local EXISTING="${name_map[$NAME_LOWER]}"
    [[ "$BASENAME" == "$EXISTING" ]] && continue
    log "SAME NAME: $BASENAME and $EXISTING share name \"$NAME\""
    log "  -> Manual review recommended (content may differ)"
    found_issues=1
  else
    name_map[$NAME_LOWER]="$BASENAME"
  fi
done

# --- 3. Orphan detection (files not in MEMORY.md index) ---
if [[ -f "$MEMORY_INDEX" ]]; then
  for f in "$MEMORY_DIR"/*.md(N); do
    [[ ! -f "$f" ]] && continue
    local BASENAME="${f:t}"
    [[ "$BASENAME" == "MEMORY.md" ]] && continue

    if ! grep -qF "$BASENAME" "$MEMORY_INDEX"; then
      log "ORPHAN: $BASENAME not in MEMORY.md index"

      local NAME=$(awk '/^name:/{sub(/^name: */, ""); print; exit}' "$f")
      local DESC=$(awk '/^description:/{sub(/^description: */, ""); print; exit}' "$f")
      if [[ -n "$NAME" ]] && [[ -n "$DESC" ]]; then
        local INDEX_LINE="- [$NAME]($BASENAME) — $DESC"
        echo "$INDEX_LINE" >> "$MEMORY_INDEX"
        log "  -> Auto-indexed: $INDEX_LINE"
      else
        log "  -> Cannot auto-index (missing name/description frontmatter)"
      fi
      found_issues=1
    fi
  done
fi

# --- 4. Dead link detection ---
if [[ -f "$MEMORY_INDEX" ]]; then
  grep -oE '\([^)]+\.md\)' "$MEMORY_INDEX" | tr -d '()' | while read -r fname; do
    if [[ ! -f "$MEMORY_DIR/$fname" ]]; then
      log "DEAD LINK: $fname referenced in MEMORY.md but file missing"
      sed -i '' "/${fname//\//\\/}/d" "$MEMORY_INDEX" 2>/dev/null
      log "  -> Removed dead link from MEMORY.md"
      found_issues=1
    fi
  done
fi

[[ $found_issues -eq 0 ]] && log "Memory check: all clean ($(ls "$MEMORY_DIR"/*.md 2>/dev/null | grep -v MEMORY.md | wc -l | tr -d ' ') files)"

exit 0
