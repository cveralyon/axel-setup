#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
BASH_BIN="${BASH}"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

make_stub() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'STUB'
#!/bin/sh
exit 0
STUB
  chmod +x "$path"
}

make_stub_bin() {
  local bin_dir="$1"
  shift
  mkdir -p "$bin_dir"

  local cmd
  for cmd in "$@"; do
    if [ "$cmd" = "npx" ]; then
      cat >"$bin_dir/npx" <<'STUB'
#!/bin/sh
: "${AXEL_SETUP_STUB_OUTPUT:?}"
printf '%s\n' "$@" >"$AXEL_SETUP_STUB_OUTPUT"
STUB
      chmod +x "$bin_dir/npx"
    else
      make_stub "$bin_dir/$cmd"
    fi
  done
}

run_installer() {
  local bin_dir="$1"
  shift
  PATH="$bin_dir" \
    AXEL_SETUP_NPX="$bin_dir/npx" \
    AXEL_SETUP_PACKAGE="github:cveralyon/axel-setup" \
    "$BASH_BIN" "$ROOT/install.sh" "$@"
}

expect_failure() {
  local name="$1"
  local expected="$2"
  shift 2

  local output
  if output="$("$@" 2>&1)"; then
    echo "Expected failure for $name" >&2
    exit 1
  fi

  case "$output" in
    *"$expected"*) ;;
    *)
      echo "Expected failure for $name to mention: $expected" >&2
      echo "$output" >&2
      exit 1
      ;;
  esac
}

assert_line() {
  local expected="$1"
  local file="$2"
  if ! grep -Fx -- "$expected" "$file" >/dev/null; then
    echo "Expected $file to contain line: $expected" >&2
    exit 1
  fi
}

delegation_bin="$TMP_ROOT/delegation-bin"
delegation_output="$TMP_ROOT/delegation-args.txt"
make_stub_bin "$delegation_bin" zsh jq node npx claude
AXEL_SETUP_STUB_OUTPUT="$delegation_output" run_installer "$delegation_bin" \
  --dry-run \
  --profile core \
  --user-name "CI Bot"

assert_line "-y" "$delegation_output"
assert_line "github:cveralyon/axel-setup" "$delegation_output"
assert_line "--dry-run" "$delegation_output"
assert_line "--profile" "$delegation_output"
assert_line "core" "$delegation_output"

codex_bin="$TMP_ROOT/codex-bin"
codex_output="$TMP_ROOT/codex-args.txt"
make_stub_bin "$codex_bin" zsh jq node npx
AXEL_SETUP_STUB_OUTPUT="$codex_output" run_installer "$codex_bin" \
  --target codex \
  --dry-run
assert_line "--target" "$codex_output"
assert_line "codex" "$codex_output"

missing_node_bin="$TMP_ROOT/missing-node-bin"
make_stub_bin "$missing_node_bin" zsh jq npx claude
expect_failure "missing node" "Node.js is required" \
  env PATH="$missing_node_bin" AXEL_SETUP_NPX="$missing_node_bin/npx" "$BASH_BIN" "$ROOT/install.sh"

missing_jq_bin="$TMP_ROOT/missing-jq-bin"
make_stub_bin "$missing_jq_bin" zsh node npx claude
expect_failure "missing jq" "jq is required" \
  env PATH="$missing_jq_bin" AXEL_SETUP_NPX="$missing_jq_bin/npx" "$BASH_BIN" "$ROOT/install.sh"

missing_zsh_bin="$TMP_ROOT/missing-zsh-bin"
make_stub_bin "$missing_zsh_bin" jq node npx claude
expect_failure "missing zsh" "zsh is required" \
  env PATH="$missing_zsh_bin" AXEL_SETUP_NPX="$missing_zsh_bin/npx" "$BASH_BIN" "$ROOT/install.sh"

missing_claude_bin="$TMP_ROOT/missing-claude-bin"
make_stub_bin "$missing_claude_bin" zsh jq node npx
expect_failure "missing claude" "Claude Code CLI is required" \
  env PATH="$missing_claude_bin" AXEL_SETUP_NPX="$missing_claude_bin/npx" "$BASH_BIN" "$ROOT/install.sh"
