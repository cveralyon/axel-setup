#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin and prints a compact status line
# Also persists last-known stats for session cost logging

input=$(cat)

# --- Session ID (for per-session stat files) ---
session_id=$(echo "$input" | jq -r '.session_id // empty')

# --- Directory ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
if [ -n "$cwd" ]; then
  dir=$(basename "$cwd")
else
  dir=$(basename "$(pwd)")
fi

# --- Git branch (skip optional locks) ---
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
         || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

# --- Detect project type from cwd ---
node_ver=""
ruby_ver=""

# Node version — try .nvmrc in the cwd, then `node` on PATH
if [ -f "$cwd/.nvmrc" ]; then
  node_ver="node:$(cat "$cwd/.nvmrc" | tr -d '[:space:]')"
elif command -v node &>/dev/null; then
  node_ver="node:$(node --version 2>/dev/null | sed 's/v//')"
fi

# Ruby version — prefer .ruby-version in the cwd, then `ruby` on PATH
if [ -f "$cwd/.ruby-version" ]; then
  ruby_ver="ruby:$(cat "$cwd/.ruby-version" | tr -d '[:space:]')"
elif command -v ruby &>/dev/null; then
  ruby_ver="ruby:$(ruby --version 2>/dev/null | awk '{print $2}')"
fi

# --- Context window ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

# --- Cost ---
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# --- Rate limits ---
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# --- Model short name ---
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/Claude //' | sed 's/ (.*)//')

# --- Persist last-known stats for Stop hook ---
if [ -n "$session_id" ]; then
  stats_file="$HOME/.claude/session-stats-${session_id}.json"
  echo "$input" | jq -c '{
    session_id: .session_id,
    cwd: (.workspace.current_dir // .cwd),
    cost_usd: (.cost.total_cost_usd // 0),
    total_input_tokens: (.context_window.total_input_tokens // 0),
    total_output_tokens: (.context_window.total_output_tokens // 0),
    ctx_used_pct: (.context_window.used_percentage // 0),
    five_h_pct: (.rate_limits.five_hour.used_percentage // 0),
    five_h_resets: (.rate_limits.five_hour.resets_at // 0),
    model: (.model.display_name // ""),
    timestamp: now | todate
  }' > "$stats_file" 2>/dev/null

  # Save starting 5h% once (first non-zero value = baseline before this session)
  start_file="$HOME/.claude/session-stats-${session_id}-start.json"
  if [ ! -f "$start_file" ] && [ -n "$five_h_pct" ] && [ "$five_h_pct" != "0" ]; then
    echo "{\"five_h_pct_start\": $five_h_pct}" > "$start_file"
  fi
fi

# --- Colors (ANSI) ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

parts=()

# Directory
parts+=("$(printf "${CYAN}%s${RESET}" "$dir")")

# Git branch
if [ -n "$branch" ]; then
  parts+=("$(printf "${GREEN}(%s)${RESET}" "$branch")")
fi

# Project runtime versions (only show what's relevant to the project)
is_node=false
is_ruby=false
[ -f "$cwd/package.json" ] || [ -f "$cwd/pnpm-lock.yaml" ] || [ -f "$cwd/.nvmrc" ] && is_node=true
[ -f "$cwd/Gemfile" ] || [ -f "$cwd/.ruby-version" ] && is_ruby=true

if $is_node && [ -n "$node_ver" ]; then
  parts+=("$(printf "${YELLOW}%s${RESET}" "$node_ver")")
fi
if $is_ruby && [ -n "$ruby_ver" ]; then
  parts+=("$(printf "${MAGENTA}%s${RESET}" "$ruby_ver")")
fi

# Model
if [ -n "$model" ]; then
  parts+=("$(printf "${BLUE}%s${RESET}" "$model")")
fi

# Context remaining
if [ -n "$remaining" ]; then
  ctx_int=$(printf "%.0f" "$remaining")
  if [ "$ctx_int" -le 20 ]; then
    ctx_color="$RED"
  else
    ctx_color="$GREEN"
  fi
  parts+=("$(printf "${ctx_color}ctx:%s%%${RESET}" "$ctx_int")")
fi

# Cost — format: $1.26 (2 decimals if >= $0.10, 3 if smaller)
if [ -n "$cost_usd" ] && [ "$cost_usd" != "0" ]; then
  cost_big=$(awk "BEGIN {exit !($cost_usd >= 0.10)}" 2>/dev/null && echo 1 || echo 0)
  if [ "$cost_big" = "1" ]; then
    cost_fmt=$(printf "%.2f" "$cost_usd" 2>/dev/null)
  else
    cost_fmt=$(printf "%.3f" "$cost_usd" 2>/dev/null)
  fi
  parts+=("$(printf "${YELLOW}\$%s${RESET}" "$cost_fmt")")
fi

# Rate limit 5h — shows acum% and +delta% for this session
if [ -n "$five_h_pct" ] && [ "$five_h_pct" != "0" ]; then
  five_int=$(printf "%.0f" "$five_h_pct" 2>/dev/null)
  if [ "$five_int" -ge 80 ]; then
    rl_color="$RED"
  elif [ "$five_int" -ge 50 ]; then
    rl_color="$YELLOW"
  else
    rl_color="$DIM"
  fi

  # Per-session delta
  delta_str=""
  if [ -n "$session_id" ]; then
    start_file_check="$HOME/.claude/session-stats-${session_id}-start.json"
    if [ -f "$start_file_check" ]; then
      five_h_start_val=$(jq -r '.five_h_pct_start // 0' "$start_file_check" 2>/dev/null)
      five_h_delta_val=$(awk "BEGIN {d=$five_h_pct-$five_h_start_val; printf \"%.1f\", (d<0?0:d)}")
      delta_str=" (+${five_h_delta_val}%)"
    fi
  fi

  # Show reset time if close to limit
  reset_str=""
  if [ "$five_int" -ge 70 ] && [ -n "$five_h_resets" ] && [ "$five_h_resets" != "0" ]; then
    reset_time=$(date -r "$five_h_resets" '+%H:%M' 2>/dev/null || date -d "@$five_h_resets" '+%H:%M' 2>/dev/null)
    [ -n "$reset_time" ] && reset_str=" reset@${reset_time}"
  fi
  parts+=("$(printf "${rl_color}5h:%s%%%s%s${RESET}" "$five_int" "$delta_str" "$reset_str")")
fi

# Join with separator
sep=" | "
result=""
for part in "${parts[@]}"; do
  if [ -z "$result" ]; then
    result="$part"
  else
    result="$result$sep$part"
  fi
done

printf "%b\n" "$result"
