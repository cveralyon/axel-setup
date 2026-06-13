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

if command -v shellcheck >/dev/null 2>&1; then
  echo "Running shellcheck"
  while IFS= read -r -d '' file; do
    if head -n 1 "$file" | grep -q "zsh"; then
      continue
    fi
    shellcheck -S error "$file"
  done < <(find . -path ./.git -prune -o -type f -name "*.sh" -print0)
else
  echo "Skipping shellcheck (not installed)"
fi

if command -v shfmt >/dev/null 2>&1; then
  echo "Checking shell formatting"
  shfmt -d -i 2 -ci scripts/ci/*.sh tests/*.sh
else
  echo "Skipping shfmt (not installed)"
fi

echo "Checking Node CLI syntax"
node --check bin/axel-setup.js

echo "Checking jq filters"
while IFS= read -r -d '' file; do
  jq -n -f "$file" >/dev/null
done < <(find . -path ./.git -prune -o -type f -name "*.jq" -print0)

echo "Checking JSON files"
jq empty package.json axel-manifest.json templates/settings.json templates/keybindings.json

echo "Running bootstrap dry run smoke test"
bash scripts/ci/bootstrap-dry-run.sh

echo "Running bootstrap behavior tests"
bash tests/bootstrap-behavior.sh

echo "Running CLI doctor tests"
bash tests/cli-doctor.sh

echo "Running settings merge fixture tests"
bash tests/merge-settings.sh

echo "Checking npm package contents"
npm pack --dry-run >/dev/null
