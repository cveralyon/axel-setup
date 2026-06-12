#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "Checking shell syntax"
while IFS= read -r -d '' file; do
  if head -n 1 "$file" | grep -q "zsh"; then
    zsh -n "$file"
  else
    bash -n "$file"
  fi
done < <(find . -path ./.git -prune -o -type f -name "*.sh" -print0)

echo "Checking Node CLI syntax"
node --check bin/axel-setup.js

echo "Checking jq filters"
while IFS= read -r -d '' file; do
  jq -n -f "$file" >/dev/null
done < <(find . -path ./.git -prune -o -type f -name "*.jq" -print0)

echo "Checking JSON files"
jq empty package.json templates/settings.json templates/keybindings.json

echo "Running bootstrap dry run smoke test"
bash scripts/ci/bootstrap-dry-run.sh

echo "Checking npm package contents"
npm pack --dry-run >/dev/null
