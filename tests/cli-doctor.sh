#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

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
