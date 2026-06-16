#!/usr/bin/env sh
set -eu

AXEL_PACKAGE="${AXEL_SETUP_PACKAGE:-axel-setup@0.3.0}"
AXEL_NPX="${AXEL_SETUP_NPX:-npx}"

die() {
  printf '%s\n' "AXEL install error: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "$2"
  fi
}

uses_non_claude_target() {
  target="claude"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target=*)
        target="${1#*=}"
        ;;
      --target)
        shift
        target="${1:-claude}"
        ;;
    esac
    [ "$#" -gt 0 ] || break
    shift
  done

  [ "$target" = "codex" ] || [ "$target" = "generic" ]
}

require_command zsh "zsh is required. Install Xcode Command Line Tools or a zsh package before running AXEL."
require_command jq "jq is required. On macOS, install it with: brew install jq"
require_command node "Node.js is required because the packaged AXEL CLI runs through npx. Install Node 18 or newer."
require_command "$AXEL_NPX" "npx is required. Install npm with Node.js, then rerun this installer."

if ! uses_non_claude_target "$@" && [ "${AXEL_SETUP_SKIP_CLAUDE_CHECK:-false}" != "true" ]; then
  require_command claude "Claude Code CLI is required for the default target. Install Claude Code, pass --target codex or --target generic, or set AXEL_SETUP_SKIP_CLAUDE_CHECK=true."
fi

exec "$AXEL_NPX" -y "$AXEL_PACKAGE" "$@"
