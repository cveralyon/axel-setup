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
