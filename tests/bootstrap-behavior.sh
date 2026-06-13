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
  chmod +x "$bin_dir/claude"
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
