#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin and prints a compact status line

input=$(cat)

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

if [ -f "$cwd/.nvmrc" ]; then
  node_ver="node:$(cat "$cwd/.nvmrc" | tr -d '[:space:]')"
elif command -v node &>/dev/null; then
  node_ver="node:$(node --version 2>/dev/null | sed 's/v//')"
fi

if [ -f "$cwd/.ruby-version" ]; then
  ruby_ver="ruby:$(cat "$cwd/.ruby-version" | tr -d '[:space:]')"
elif command -v ruby &>/dev/null; then
  ruby_ver="ruby:$(ruby --version 2>/dev/null | awk '{print $2}')"
fi

# --- Context window ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# --- Model short name ---
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/Claude //' | sed 's/ (.*)//')

# --- Assemble pieces ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RESET='\033[0m'

parts=()
parts+=("$(printf "${CYAN}%s${RESET}" "$dir")")

if [ -n "$branch" ]; then
  parts+=("$(printf "${GREEN}(%s)${RESET}" "$branch")")
fi

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

if [ -n "$model" ]; then
  parts+=("$(printf "${BLUE}%s${RESET}" "$model")")
fi

if [ -n "$remaining" ]; then
  ctx_int=$(printf "%.0f" "$remaining")
  if [ "$ctx_int" -le 20 ]; then
    ctx_color='\033[0;31m'
  else
    ctx_color='\033[0;32m'
  fi
  parts+=("$(printf "${ctx_color}ctx:%s%%${RESET}" "$ctx_int")")
fi

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
