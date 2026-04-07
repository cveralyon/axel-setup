#!/usr/bin/env bash
# session-cost-log.sh
# Runs from Stop hook. Reads last-known stats persisted by statusline
# and appends one line to ~/.claude/session-costs.log
# CSV columns:
#   date,time,session_id,project,cost_usd,input_tokens,output_tokens,ctx_used_pct,five_h_end_pct,five_h_session_pct,model

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
LOG_FILE="$HOME/.claude/session-costs.log"
STATS_FILE="$HOME/.claude/session-stats-${SESSION_ID}.json"
START_FILE="$HOME/.claude/session-stats-${SESSION_ID}-start.json"

[ -z "$SESSION_ID" ] && exit 0

# Bootstrap log file with header if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
  echo "date,time,session_id,project,cost_usd,input_tokens,output_tokens,ctx_used_pct,five_h_end_pct,five_h_session_pct,model" > "$LOG_FILE"
fi

# Read persisted stats (written by statusline on each update)
[ ! -f "$STATS_FILE" ] && exit 0
STATS=$(cat "$STATS_FILE")

# Skip if cost is zero (no real work done)
COST=$(echo "$STATS" | jq -r '.cost_usd // 0')
if [ "$(echo "$COST == 0" | bc -l 2>/dev/null)" = "1" ] || [ "$COST" = "0" ]; then
  rm -f "$STATS_FILE" "$START_FILE"
  exit 0
fi

# Extract fields
PROJECT=$(basename "${CWD:-$(pwd)}")
INPUT_TOK=$(echo "$STATS" | jq -r '.total_input_tokens // 0')
OUTPUT_TOK=$(echo "$STATS" | jq -r '.total_output_tokens // 0')
CTX_PCT=$(echo "$STATS" | jq -r '.ctx_used_pct // 0' | xargs printf "%.1f")
FIVE_H_END=$(echo "$STATS" | jq -r '.five_h_pct // 0')
MODEL=$(echo "$STATS" | jq -r '.model // ""' | sed 's/Claude //')
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

# Calculate per-session 5h% delta
FIVE_H_START=0
if [ -f "$START_FILE" ]; then
  FIVE_H_START=$(jq -r '.five_h_pct_start // 0' "$START_FILE" 2>/dev/null || echo 0)
fi
FIVE_H_DELTA=$(awk "BEGIN {
  d = $FIVE_H_END - $FIVE_H_START
  if (d < 0) d = 0
  printf \"%.1f\", d
}" 2>/dev/null)

FIVE_H_END_FMT=$(printf "%.1f" "$FIVE_H_END")

# Append row
echo "${DATE},${TIME},${SESSION_ID:0:8},${PROJECT},${COST},${INPUT_TOK},${OUTPUT_TOK},${CTX_PCT},${FIVE_H_END_FMT},${FIVE_H_DELTA},${MODEL}" >> "$LOG_FILE"

# Clean up temp files
rm -f "$STATS_FILE" "$START_FILE"

exit 0
