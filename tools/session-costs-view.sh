#!/usr/bin/env bash
# session-costs-view.sh
# Pretty-print the session costs log
# Usage:
#   ~/.claude/tools/session-costs-view.sh           → all sessions (last 30)
#   ~/.claude/tools/session-costs-view.sh today     → today only
#   ~/.claude/tools/session-costs-view.sh week      → last 7 days
#   ~/.claude/tools/session-costs-view.sh summary   → totals by day

LOG_FILE="$HOME/.claude/session-costs.log"
MODE="${1:-all}"
TODAY=$(date +%Y-%m-%d)
WEEK_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d 2>/dev/null)

if [ ! -f "$LOG_FILE" ]; then
  echo "No hay datos todavía. El log se crea al cerrar la primera sesión con actividad."
  exit 0
fi

# ANSI colors
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

# Filter rows based on mode (skip header)
case "$MODE" in
  today)
    DATA=$(tail -n +2 "$LOG_FILE" | grep "^${TODAY}")
    TITLE="Sesiones de hoy (${TODAY})"
    ;;
  week)
    DATA=$(tail -n +2 "$LOG_FILE" | awk -F',' -v cutoff="$WEEK_AGO" '$1 >= cutoff')
    TITLE="Últimos 7 días"
    ;;
  summary)
    echo -e "${BOLD}=== Resumen por día ===${RESET}"
    echo ""
    tail -n +2 "$LOG_FILE" | awk -F',' '
    {
      day[$1] += $5
      sessions[$1]++
      tokens[$1] += ($6 + $7)
      five_h_delta[$1] += $10
    }
    END {
      for (d in day) {
        printf "%s  sesiones: %2d  costo: $%.2f  tokens: %5dk  limite-5h usado: %.1f%%\n",
          d, sessions[d], day[d], tokens[d]/1000, five_h_delta[d]
      }
    }' | sort -r
    echo ""
    TOTAL=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$5} END {printf "%.2f", sum}')
    SESSIONS=$(tail -n +2 "$LOG_FILE" | wc -l | tr -d ' ')
    TOTAL_5H=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$10} END {printf "%.1f", sum}')
    echo -e "${BOLD}Total acumulado: \$${TOTAL} en ${SESSIONS} sesión(es) — ${TOTAL_5H}% del límite de 5h consumido en total${RESET}"
    exit 0
    ;;
  *)
    DATA=$(tail -n +2 "$LOG_FILE" | tail -30)
    TITLE="Últimas 30 sesiones"
    ;;
esac

if [ -z "$DATA" ]; then
  echo "Sin datos para el período seleccionado."
  exit 0
fi

echo -e "${BOLD}=== ${TITLE} ===${RESET}"
echo ""
# Header: date time session project cost in out ctx% 5h-acum% 5h-sesion%
printf "${BOLD}%-12s %-6s %-10s %-18s %7s %7s %7s %6s %8s %9s${RESET}\n" \
  "Fecha" "Hora" "Session" "Proyecto" "Costo" "In-tok" "Out-tok" "Ctx%" "5h-acum" "5h-sesion"
echo "────────────────────────────────────────────────────────────────────────────────────────────"

TOTAL_COST=0
TOTAL_5H_DELTA=0
while IFS=',' read -r date time sess proj cost in_tok out_tok ctx_pct five_h_end five_h_delta model; do
  # Color cost
  cost_cents=$(awk "BEGIN {printf \"%.0f\", ${cost:-0} * 100}" 2>/dev/null)
  if [ "${cost_cents:-0}" -gt 100 ]; then
    cost_color="$RED"
  elif [ "${cost_cents:-0}" -gt 30 ]; then
    cost_color="$YELLOW"
  else
    cost_color="$GREEN"
  fi

  # Color 5h acumulado
  five_end_int=$(printf "%.0f" "${five_h_end:-0}" 2>/dev/null)
  if [ "${five_end_int:-0}" -ge 80 ]; then
    five_end_color="$RED"
  elif [ "${five_end_int:-0}" -ge 50 ]; then
    five_end_color="$YELLOW"
  else
    five_end_color="$DIM"
  fi

  # Color 5h delta de esta sesión
  five_delta_int=$(printf "%.0f" "${five_h_delta:-0}" 2>/dev/null)
  if [ "${five_delta_int:-0}" -ge 20 ]; then
    five_delta_color="$RED"
  elif [ "${five_delta_int:-0}" -ge 10 ]; then
    five_delta_color="$YELLOW"
  else
    five_delta_color="$CYAN"
  fi

  in_k=$(awk "BEGIN {printf \"%.0f\", ${in_tok:-0}/1000}" 2>/dev/null)k
  out_k=$(awk "BEGIN {printf \"%.0f\", ${out_tok:-0}/1000}" 2>/dev/null)k

  printf "${DIM}%-12s %-6s${RESET} ${CYAN}%-10s${RESET} %-18s ${cost_color}%7s${RESET} %7s %7s %5s%% ${five_end_color}%7s%%${RESET} ${five_delta_color}%8s%%${RESET}\n" \
    "$date" "$time" "$sess" "${proj:0:18}" "\$$cost" "$in_k" "$out_k" "$ctx_pct" "$five_h_end" "$five_h_delta"

  TOTAL_COST=$(awk "BEGIN {printf \"%.2f\", $TOTAL_COST + ${cost:-0}}" 2>/dev/null)
  TOTAL_5H_DELTA=$(awk "BEGIN {printf \"%.1f\", $TOTAL_5H_DELTA + ${five_h_delta:-0}}" 2>/dev/null)
done <<< "$DATA"

echo "────────────────────────────────────────────────────────────────────────────────────────────"
COUNT=$(echo "$DATA" | wc -l | tr -d ' ')
echo -e "${BOLD}Total: \$${TOTAL_COST} en ${COUNT} sesión(es) — ${TOTAL_5H_DELTA}% del límite de 5h consumido${RESET}"
echo ""
echo -e "${DIM}Columna '5h-sesion' = cuánto del límite de 5h consumió esta sesión específica${RESET}"
echo -e "${DIM}Modos: $(basename "$0") [today|week|summary|all]${RESET}"
