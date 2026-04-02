#!/bin/zsh
# PostToolUse hook: Auto-lint/fix files after Edit or Write.
# Uses HOOK_TOOL_INPUT (JSON stdin) for richer context when available,
# falls back to TOOL_INPUT_FILE_PATH env var.

# Try to extract file path from JSON stdin first, then env var
FILE=""
if [ -n "$TOOL_INPUT_FILE_PATH" ]; then
  FILE="$TOOL_INPUT_FILE_PATH"
elif [ -n "$HOOK_TOOL_INPUT" ]; then
  FILE=$(echo "$HOOK_TOOL_INPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('file_path',''))" 2>/dev/null)
fi

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

# Ruby files — rubocop autocorrect
if [[ "$FILE" == *.rb ]] && [[ -f Gemfile ]]; then
  bundle exec rubocop --autocorrect "$FILE" --format simple 2>/dev/null | tail -5

# TypeScript/JavaScript — eslint fix
elif [[ "$FILE" == *.ts ]] || [[ "$FILE" == *.tsx ]] || [[ "$FILE" == *.js ]] || [[ "$FILE" == *.jsx ]]; then
  if [[ -f node_modules/.bin/eslint ]]; then
    npx eslint --fix "$FILE" 2>/dev/null | tail -5
  fi

# Python — ruff fix (fast, modern linter)
elif [[ "$FILE" == *.py ]]; then
  if command -v ruff >/dev/null 2>&1; then
    ruff check --fix "$FILE" 2>/dev/null | tail -5
  elif command -v autopep8 >/dev/null 2>&1; then
    autopep8 --in-place "$FILE" 2>/dev/null
  fi

# ERB templates — erb lint
elif [[ "$FILE" == *.erb ]] && [[ -f Gemfile ]]; then
  if bundle show erb_lint >/dev/null 2>&1; then
    bundle exec erblint --autocorrect "$FILE" 2>/dev/null | tail -3
  fi
fi

exit 0
