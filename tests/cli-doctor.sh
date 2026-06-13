#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Expected file to exist: $path" >&2
    exit 1
  fi
}

assert_no_path() {
  local path="$1"
  if [ -e "$path" ]; then
    echo "Expected path to be absent: $path" >&2
    exit 1
  fi
}

stub_bin="$TMP_ROOT/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/claude" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  --version)
    echo "Claude Code 1.0.0"
    ;;
  plugins)
    exit 0
    ;;
  *)
    echo "claude stub"
    ;;
esac
STUB
chmod +x "$stub_bin/claude"

install_home="$TMP_ROOT/home"
mkdir -p "$install_home"

PATH="$stub_bin:$PATH" HOME="$install_home" node "$ROOT/bin/axel-setup.js" \
  --user-name "CI Bot" \
  --profile minimal \
  --skip-plugins \
  --skip-gsd \
  --no-launchd >/dev/null

doctor_output="$(node "$ROOT/bin/axel-setup.js" doctor --home "$install_home")"
printf '%s\n' "$doctor_output" | grep -q "AXEL Doctor"
printf '%s\n' "$doctor_output" | grep -q "PASS"

diff_output="$(node "$ROOT/bin/axel-setup.js" diff --home "$install_home")"
printf '%s\n' "$diff_output" | grep -q "AXEL Diff"
printf '%s\n' "$diff_output" | grep -q "MATCH commands/daily.md"
printf '%s\n' "$diff_output" | grep -q "PRESENT settings.json (merge-managed)"

uninstall_dry_run_output="$(node "$ROOT/bin/axel-setup.js" uninstall --home "$install_home")"
printf '%s\n' "$uninstall_dry_run_output" | grep -q "Mode: dry-run"
printf '%s\n' "$uninstall_dry_run_output" | grep -q "WOULD REMOVE commands/daily.md"
assert_file "$install_home/.claude/commands/daily.md"

printf '\n# local customization\n' >>"$install_home/.claude/commands/daily.md"
PATH="$stub_bin:$PATH" HOME="$install_home" node "$ROOT/bin/axel-setup.js" \
  --user-name "CI Bot" \
  --profile minimal \
  --skip-plugins \
  --skip-gsd \
  --no-launchd >/dev/null

assert_file "$install_home/.claude/axel-upgrades/MANIFEST.md"
assert_file "$install_home/.claude/axel-upgrades/REVIEW.md"

review_output="$(node "$ROOT/bin/axel-setup.js" review-upgrades --home "$install_home")"
printf '%s\n' "$review_output" | grep -q "AXEL Upgrade Review"
printf '%s\n' "$review_output" | grep -q "Target: claude"
printf '%s\n' "$review_output" | grep -q "commands"
printf '%s\n' "$review_output" | grep -q "daily.md"

rm "$install_home/.claude/hooks/enforce-agent-model.jq"

set +e
missing_output="$(node "$ROOT/bin/axel-setup.js" doctor --home "$install_home" 2>&1)"
missing_status=$?
set -e

if [ "$missing_status" -eq 0 ]; then
  echo "Doctor should fail when a manifest file is missing" >&2
  exit 1
fi

printf '%s\n' "$missing_output" | grep -q "MISSING"

codex_home="$TMP_ROOT/codex-home"
codex_root="$TMP_ROOT/codex-root"
mkdir -p "$codex_home"

PATH="$stub_bin:$PATH" HOME="$codex_home" CODEX_HOME="$codex_root" node "$ROOT/bin/axel-setup.js" \
  --target codex \
  --user-name "CI Bot" \
  --profile minimal >/dev/null

codex_doctor_output="$(node "$ROOT/bin/axel-setup.js" doctor --target codex --codex-home "$codex_root")"
printf '%s\n' "$codex_doctor_output" | grep -q "Target: codex"
printf '%s\n' "$codex_doctor_output" | grep -q "PASS AGENTS.md"

rm "$codex_root/AGENTS.md"

set +e
codex_missing_output="$(node "$ROOT/bin/axel-setup.js" doctor --target codex --codex-home "$codex_root" 2>&1)"
codex_missing_status=$?
set -e

if [ "$codex_missing_status" -eq 0 ]; then
  echo "Codex doctor should fail when a manifest file is missing" >&2
  exit 1
fi

printf '%s\n' "$codex_missing_output" | grep -q "MISSING AGENTS.md"

generic_home="$TMP_ROOT/generic-home"
generic_output="$TMP_ROOT/generic-output"
mkdir -p "$generic_home"

PATH="$stub_bin:$PATH" HOME="$generic_home" node "$ROOT/bin/axel-setup.js" \
  --target generic \
  --output "$generic_output" \
  --user-name "CI Bot" \
  --profile minimal >/dev/null

generic_doctor_output="$(node "$ROOT/bin/axel-setup.js" doctor --target generic --output "$generic_output")"
printf '%s\n' "$generic_doctor_output" | grep -q "Target: generic"
printf '%s\n' "$generic_doctor_output" | grep -q "PASS AGENTS.md"
if [ -e "$generic_home/.claude" ]; then
  echo "Generic target should not write Claude config" >&2
  exit 1
fi

generic_review_output_dir="$TMP_ROOT/generic-review-output"

PATH="$stub_bin:$PATH" HOME="$generic_home" node "$ROOT/bin/axel-setup.js" \
  --target generic \
  --output "$generic_review_output_dir" \
  --user-name "CI Bot" \
  --profile minimal >/dev/null

printf '\n# local runtime edit\n' >>"$generic_review_output_dir/AGENTS.md"

PATH="$stub_bin:$PATH" HOME="$generic_home" node "$ROOT/bin/axel-setup.js" \
  --target generic \
  --output "$generic_review_output_dir" \
  --user-name "CI Bot" \
  --profile minimal >/dev/null

assert_file "$generic_review_output_dir/axel-upgrades/MANIFEST.md"
assert_file "$generic_review_output_dir/axel-upgrades/REVIEW.md"

generic_review_output="$(node "$ROOT/bin/axel-setup.js" review-upgrades --target generic --output "$generic_review_output_dir")"
printf '%s\n' "$generic_review_output" | grep -q "AXEL Upgrade Review"
printf '%s\n' "$generic_review_output" | grep -q "Target: generic"
printf '%s\n' "$generic_review_output" | grep -q "instructions"
printf '%s\n' "$generic_review_output" | grep -q "AGENTS.md"

generic_diff_output="$(node "$ROOT/bin/axel-setup.js" diff --target generic --output "$generic_output")"
printf '%s\n' "$generic_diff_output" | grep -q "MATCH AGENTS.md"
printf '%s\n' "$generic_diff_output" | grep -q "PRESENT axel-manifest.json (manifest)"

generic_uninstall_dry_run="$(node "$ROOT/bin/axel-setup.js" uninstall --target generic --output "$generic_output")"
printf '%s\n' "$generic_uninstall_dry_run" | grep -q "Mode: dry-run"
printf '%s\n' "$generic_uninstall_dry_run" | grep -q "WOULD REMOVE AGENTS.md"
assert_file "$generic_output/AGENTS.md"

generic_uninstall_apply="$(node "$ROOT/bin/axel-setup.js" uninstall --target generic --output "$generic_output" --apply)"
printf '%s\n' "$generic_uninstall_apply" | grep -q "Mode: apply"
printf '%s\n' "$generic_uninstall_apply" | grep -q "REMOVE AGENTS.md"
assert_no_path "$generic_output/AGENTS.md"
assert_no_path "$generic_output/commands/daily.md"
assert_no_path "$generic_output/axel-manifest.json"
