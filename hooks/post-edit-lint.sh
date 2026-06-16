#!/bin/zsh
# PostToolUse hook (Edit|Write): auto-lint/fix files after Edit or Write.
# Reads the hook payload as JSON from stdin and extracts .tool_input.file_path.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

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
