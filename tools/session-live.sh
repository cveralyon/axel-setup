#!/usr/bin/env bash
# session-live.sh — live terminal dashboard for Claude Code usage
# Run with: watch -n 10 -c ~/.claude/session-live.sh
# Or standalone (loops itself): ~/.claude/session-live.sh --loop

LOG_FILE="$HOME/.claude/session-costs.log"
STATS_DIR="$HOME/.claude"
TODAY=$(date +%Y-%m-%d)
NOW=$(date '+%H:%M:%S')
LOOP_MODE="${1:-}"

# ANSI
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
RED='\033[0;31m'; MAGENTA='\033[0;35m'; BLUE='\033[0;34m'; WHITE='\033[0;37m'
BG_DARK='\033[48;5;235m'

bar() {
  local pct="${1:-0}"; local width="${2:-20}"
  local filled=$(awk "BEGIN {printf \"%.0f\", $pct * $width / 100}")
  local empty=$(( width - filled ))
  local color
  if   awk "BEGIN {exit !($pct >= 80)}"; then color="$RED"
  elif awk "BEGIN {exit !($pct >= 50)}"; then color="$YELLOW"
  else color="$GREEN"; fi
  printf "${color}"
  printf '█%.0s' $(seq 1 $filled 2>/dev/null); printf '░%.0s' $(seq 1 $empty 2>/dev/null)
  printf "${RESET} ${DIM}%.0f%%${RESET}" "$pct"
}

hr() { printf "${DIM}%s${RESET}\n" "$(printf '─%.0s' $(seq 1 ${1:-70}))"; }

clear

# ── Header ──────────────────────────────────────────────────────────────────
printf "${BOLD}${CYAN}  Claude Code — Usage Monitor${RESET}  ${DIM}actualizado: %s${RESET}\n" "$NOW"
hr 70
echo ""

# ── Active sessions ──────────────────────────────────────────────────────────
printf "${BOLD}  SESIONES ACTIVAS${RESET}\n"
echo ""

ACTIVE_COUNT=0
# Find stats files modified in last 2 hours (active sessions)
while IFS= read -r stats_file; do
  [ -f "$stats_file" ] || continue
  # Skip start files
  [[ "$stats_file" == *"-start.json" ]] && continue

  session_id=$(jq -r '.session_id // ""' "$stats_file" 2>/dev/null)
  [ -z "$session_id" ] && continue

  proj=$(jq -r '.cwd // ""' "$stats_file" 2>/dev/null | xargs basename 2>/dev/null)
  cost=$(jq -r '.cost_usd // 0' "$stats_file" 2>/dev/null)
  in_tok=$(jq -r '.total_input_tokens // 0' "$stats_file" 2>/dev/null)
  out_tok=$(jq -r '.total_output_tokens // 0' "$stats_file" 2>/dev/null)
  ctx_pct=$(jq -r '.ctx_used_pct // 0' "$stats_file" 2>/dev/null)
  five_h=$(jq -r '.five_h_pct // 0' "$stats_file" 2>/dev/null)

  # Per-session 5h delta
  start_file="${stats_file%-start.json}-start.json"
  # Actually: stats file is session-stats-{id}.json, start file is session-stats-{id}-start.json
  start_file="$STATS_DIR/session-stats-${session_id}-start.json"
  five_h_start=0
  [ -f "$start_file" ] && five_h_start=$(jq -r '.five_h_pct_start // 0' "$start_file" 2>/dev/null)
  five_h_delta=$(awk "BEGIN {d=$five_h-$five_h_start; printf \"%.1f\", (d<0?0:d)}")

  total_tok=$(awk "BEGIN {printf \"%.0f\", ($in_tok+$out_tok)/1000}")

  printf "  ${CYAN}%-18s${RESET} ${DIM}%s${RESET}\n" "$proj" "${session_id:0:8}"
  printf "  Costo:   ${YELLOW}\$%-8s${RESET}  Tokens: ${WHITE}%sk${RESET}\n" "$cost" "$total_tok"
  printf "  Ctx:     "; bar "$ctx_pct" 18; echo ""
  printf "  5h acum: "; bar "$five_h" 18; echo ""
  printf "  5h esta sesión: ${CYAN}%s%%${RESET}\n" "$five_h_delta"
  echo ""
  ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
done < <(find "$STATS_DIR" -maxdepth 1 -name "session-stats-*.json" ! -name "*-start.json" -newer "$STATS_DIR/settings.json" -mmin -120 2>/dev/null | sort)

if [ "$ACTIVE_COUNT" -eq 0 ]; then
  printf "  ${DIM}(sin sesiones activas en las últimas 2h)${RESET}\n"
  echo ""
fi

# ── Today's closed sessions ──────────────────────────────────────────────────
hr 70
printf "${BOLD}  HOY — %s${RESET}\n" "$TODAY"
echo ""

if [ -f "$LOG_FILE" ]; then
  TODAY_DATA=$(tail -n +2 "$LOG_FILE" | grep "^${TODAY}")

  if [ -n "$TODAY_DATA" ]; then
    TOTAL_COST_TODAY=0
    TOTAL_5H_TODAY=0
    SESSION_COUNT_TODAY=0

    while IFS=',' read -r date time sess proj cost in_tok out_tok ctx_pct five_h_end five_h_delta model; do
      cost_cents=$(awk "BEGIN {printf \"%.0f\", ${cost:-0} * 100}")
      [ "${cost_cents:-0}" -gt 30 ] && c_color="$YELLOW" || c_color="$GREEN"
      [ "${cost_cents:-0}" -gt 100 ] && c_color="$RED"

      in_k=$(awk "BEGIN {printf \"%.0f\", ${in_tok:-0}/1000}")
      out_k=$(awk "BEGIN {printf \"%.0f\", ${out_tok:-0}/1000}")

      printf "  ${DIM}%s${RESET}  ${CYAN}%-16s${RESET}  ${c_color}\$%s${RESET}  %sk+%sk tok  ${DIM}5h:+%s%%${RESET}\n" \
        "$time" "${proj:0:16}" "$cost" "$in_k" "$out_k" "$five_h_delta"

      TOTAL_COST_TODAY=$(awk "BEGIN {printf \"%.3f\", $TOTAL_COST_TODAY + ${cost:-0}}")
      TOTAL_5H_TODAY=$(awk "BEGIN {printf \"%.1f\", $TOTAL_5H_TODAY + ${five_h_delta:-0}}")
      SESSION_COUNT_TODAY=$((SESSION_COUNT_TODAY + 1))
    done <<< "$TODAY_DATA"

    echo ""
    printf "  ${BOLD}Subtotal hoy: ${YELLOW}\$%s${RESET}${BOLD}  en %d sesión(es)  —  %s%% del límite de 5h${RESET}\n" \
      "$TOTAL_COST_TODAY" "$SESSION_COUNT_TODAY" "$TOTAL_5H_TODAY"
  else
    printf "  ${DIM}(sin sesiones cerradas hoy todavía)${RESET}\n"
  fi
else
  printf "  ${DIM}(sin datos aún)${RESET}\n"
fi

echo ""

# ── 7-day summary ────────────────────────────────────────────────────────────
hr 70
printf "${BOLD}  ÚLTIMOS 7 DÍAS${RESET}\n"
echo ""

if [ -f "$LOG_FILE" ]; then
  WEEK_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d 2>/dev/null)
  WEEK_DATA=$(tail -n +2 "$LOG_FILE" | awk -F',' -v cutoff="$WEEK_AGO" '$1 >= cutoff')

  if [ -n "$WEEK_DATA" ]; then
    echo "$WEEK_DATA" | awk -F',' -v CYAN="$CYAN" -v DIM="$DIM" -v YELLOW="$YELLOW" -v GREEN="$GREEN" -v BOLD="$BOLD" -v RESET="$RESET" '
    {
      day[$1] += $5; sessions[$1]++; tokens[$1] += ($6+$7)/1000; five_h[$1] += $10
    }
    END {
      for (d in day) arr[d]=d
      n = asorti(arr, sorted, "@val_str_desc")
      for (i=1; i<=n; i++) {
        d = sorted[i]
        printf "  %s%-12s%s  %2d ses  %s$%.3f%s  %5.0ftok  %s%.1f%%%s 5h\n",
          DIM, d, RESET, sessions[d], YELLOW, day[d], RESET, tokens[d], DIM, five_h[d], RESET
      }
    }' 2>/dev/null || \
    echo "$WEEK_DATA" | awk -F',' '{day[$1]+=$5; sessions[$1]++; tokens[$1]+=($6+$7)/1000; five_h[$1]+=$10}
      END {for(d in day) printf "  %-12s %2d ses  $%.3f  %5.0ftok  %.1f%% 5h\n", d, sessions[d], day[d], tokens[d], five_h[d]}' | sort -r

    echo ""
    WEEK_TOTAL=$(echo "$WEEK_DATA" | awk -F',' '{s+=$5} END {printf "%.3f",s}')
    WEEK_5H=$(echo "$WEEK_DATA" | awk -F',' '{s+=$10} END {printf "%.1f",s}')
    WEEK_SESS=$(echo "$WEEK_DATA" | wc -l | tr -d ' ')
    printf "  ${BOLD}Total 7d: ${YELLOW}\$%s${RESET}${BOLD}  %s sesiones  —  %s%% del límite de 5h acumulado${RESET}\n" \
      "$WEEK_TOTAL" "$WEEK_SESS" "$WEEK_5H"
  else
    printf "  ${DIM}(sin datos esta semana)${RESET}\n"
  fi
fi

echo ""
hr 70
printf "  ${DIM}Para dashboard web: bash ~/.claude/session-dashboard-gen.sh${RESET}\n"
printf "  ${DIM}Actualiza cada 10s con: watch -n 10 -c ~/.claude/session-live.sh${RESET}\n"
echo ""

# Loop mode
if [ "$LOOP_MODE" = "--loop" ]; then
  sleep 10
  exec "$0" --loop
fi
