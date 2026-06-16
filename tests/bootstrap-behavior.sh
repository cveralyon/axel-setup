#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

make_stub_bin() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat >"$bin_dir/claude" <<'STUB'
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
  cat >"$bin_dir/npx" <<'STUB'
#!/usr/bin/env bash
echo "npx should not run for the default safe profile" >&2
exit 42
STUB
  chmod +x "$bin_dir/claude" "$bin_dir/npx"
}

run_bootstrap() {
  local home_dir="$1"
  local bin_dir="$2"
  shift 2
  PATH="$bin_dir:$PATH" HOME="$home_dir" bash "$ROOT/bootstrap.sh" "$@"
}

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
make_stub_bin "$stub_bin"

dry_home="$TMP_ROOT/dry-home"
mkdir -p "$dry_home"
run_bootstrap "$dry_home" "$stub_bin" --dry-run --user-name "CI Bot"
assert_no_path "$dry_home/.claude"

default_home="$TMP_ROOT/default-home"
mkdir -p "$default_home"
run_bootstrap "$default_home" "$stub_bin" \
  --user-name "CI Bot" \
  --user-context "CI smoke test" \
  --language english

assert_file "$default_home/.claude/axel-manifest.json"
jq -e '.profile == "core"' "$default_home/.claude/axel-manifest.json" >/dev/null
jq -e '.permissions.defaultMode != "bypassPermissions"' "$default_home/.claude/settings.json" >/dev/null
jq -e '(.permissions.allow // []) | index("Bash(*)") | not' "$default_home/.claude/settings.json" >/dev/null
assert_no_path "$default_home/.claude/tools/session-server.js"
assert_no_path "$default_home/.claude/keybindings.json"
assert_no_path "$default_home/.claude/get-shit-done"

install_home="$TMP_ROOT/install-home"
mkdir -p "$install_home"
run_bootstrap "$install_home" "$stub_bin" \
  --user-name "CI Bot" \
  --user-context "CI smoke test" \
  --language english \
  --profile minimal \
  --skip-plugins \
  --skip-gsd \
  --no-launchd

assert_file "$install_home/.claude/skills/ui-ux-pro-max/data/colors.csv"
assert_file "$install_home/.claude/skills/ui-ux-pro-max/scripts/search.py"
assert_no_path "$install_home/.claude/skills/ui-ux-pro-max/scripts/__pycache__"
assert_file "$install_home/.claude/axel-manifest.json"
assert_no_path "$install_home/.claude/get-shit-done"

jq -e '.profile == "minimal"' "$install_home/.claude/axel-manifest.json" >/dev/null
jq -e '.target == "claude"' "$install_home/.claude/axel-manifest.json" >/dev/null
jq -e '.permissions.defaultMode != "bypassPermissions"' "$install_home/.claude/settings.json" >/dev/null
jq -e '(.permissions.allow // []) | index("Bash(*)") | not' "$install_home/.claude/settings.json" >/dev/null

# Personal profile ELEVATES the safe-by-default template: bypassPermissions,
# Bash(*) in allow, and the dangerous-mode prompt suppressed. Skip the network
# and host-mutating steps so the test only exercises the settings elevation.
personal_home="$TMP_ROOT/personal-home"
mkdir -p "$personal_home"
run_bootstrap "$personal_home" "$stub_bin" \
  --user-name "CI Bot" \
  --user-context "CI smoke test" \
  --language english \
  --profile personal \
  --skip-plugins \
  --skip-monitor \
  --skip-keybindings \
  --skip-gsd \
  --no-launchd

assert_file "$personal_home/.claude/settings.json"
jq -e '.profile == "personal"' "$personal_home/.claude/axel-manifest.json" >/dev/null
jq -e '.permissions.defaultMode == "bypassPermissions"' "$personal_home/.claude/settings.json" >/dev/null
jq -e '(.permissions.allow // []) | index("Bash(*)")' "$personal_home/.claude/settings.json" >/dev/null
jq -e '.skipDangerousModePermissionPrompt == true' "$personal_home/.claude/settings.json" >/dev/null

# Cross-check: core (the default) must NOT be elevated — proves the elevation is
# scoped to personal/full, not leaking into the safe-by-default profiles.
jq -e '.permissions.defaultMode != "bypassPermissions"' "$default_home/.claude/settings.json" >/dev/null

codex_dry_home="$TMP_ROOT/codex-dry-home"
codex_dry_root="$TMP_ROOT/codex-dry-root"
mkdir -p "$codex_dry_home"
PATH="$stub_bin:$PATH" HOME="$codex_dry_home" CODEX_HOME="$codex_dry_root" \
  bash "$ROOT/bootstrap.sh" \
  --target codex \
  --dry-run \
  --user-name "CI Bot"
assert_no_path "$codex_dry_root"
assert_no_path "$codex_dry_home/.claude"

codex_home="$TMP_ROOT/codex-home"
codex_root="$TMP_ROOT/codex-root"
mkdir -p "$codex_home"
PATH="$stub_bin:$PATH" HOME="$codex_home" CODEX_HOME="$codex_root" \
  bash "$ROOT/bootstrap.sh" \
  --target codex \
  --user-name "CI Bot" \
  --profile minimal

assert_file "$codex_root/AGENTS.md"
assert_file "$codex_root/skills/model-routing/SKILL.md"
assert_file "$codex_root/skills/ui-ux-pro-max/data/colors.csv"
assert_file "$codex_root/commands/daily.md"
assert_file "$codex_root/agents/excelsior-verifier.md"
assert_file "$codex_root/axel-manifest.json"
assert_no_path "$codex_home/.claude"
jq -e '.target == "codex"' "$codex_root/axel-manifest.json" >/dev/null

generic_home="$TMP_ROOT/generic-home"
generic_output="$TMP_ROOT/generic-output"
mkdir -p "$generic_home"
PATH="$stub_bin:$PATH" HOME="$generic_home" \
  bash "$ROOT/bootstrap.sh" \
  --target generic \
  --output "$generic_output" \
  --user-name "CI Bot" \
  --profile minimal

assert_file "$generic_output/AGENTS.md"
assert_file "$generic_output/skills/model-routing/SKILL.md"
assert_file "$generic_output/commands/daily.md"
assert_file "$generic_output/agents/excelsior-verifier.md"
assert_file "$generic_output/axel-manifest.json"
assert_no_path "$generic_home/.claude"
jq -e '.target == "generic"' "$generic_output/axel-manifest.json" >/dev/null
