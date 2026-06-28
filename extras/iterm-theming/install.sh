#!/usr/bin/env bash
# ============================================================================
# AXEL extra — iTerm2 session theming (optional, cosmetic).
#
# Gives each iTerm2 session a distinct, stable tab color, a prominent badge
# (current dir + git branch), and convenience commands (tabname, tabcolor).
# Ships an opt-in "Claude" profile with a bigger badge, confirm-before-closing,
# and unlimited scrollback. The tab title is left to your program (e.g. Claude
# Code sets the task name); `tabname` lets you pin a custom one.
#
# Scope: macOS + iTerm2 ONLY. This is the one AXEL component that writes outside
# ~/.claude (to ~/.config/iterm, ~/.zshrc, and iTerm2 DynamicProfiles), which is
# why it ships as a separate opt-in extra and is NOT run by bootstrap.sh.
#
# Safe: additive and idempotent. Backs up ~/.zshrc before editing it, and only
# appends its block once (guarded by markers).
#
# Usage:
#   bash install.sh [--dry-run] [--skip-shell-integration]
# ============================================================================
set -euo pipefail

DRY_RUN=false
SKIP_SHELL_INTEGRATION=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --skip-shell-integration) SKIP_SHELL_INTEGRATION=true; shift ;;
    -h|--help)
      echo "Usage: bash install.sh [--dry-run] [--skip-shell-integration]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/iterm"
DYNPROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ZSHRC="$HOME/.zshrc"
SHELL_INTEGRATION="$HOME/.iterm2_shell_integration.zsh"
MARKER_START="# >>> axel iterm-theming >>>"

info() { printf '\033[0;34m[iterm-theming]\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m[warn]\033[0m %s\n' "$1"; }

run() {
  if $DRY_RUN; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# --- Guards ---------------------------------------------------------------
if [ "$(uname -s)" != "Darwin" ]; then
  warn "This add-on is macOS + iTerm2 only. Detected $(uname -s). Aborting."
  exit 0
fi
if [ "${TERM_PROGRAM:-}" != "iTerm.app" ]; then
  warn "TERM_PROGRAM is '${TERM_PROGRAM:-unset}', not 'iTerm.app'."
  warn "Install will continue, but the theming only takes effect inside iTerm2."
fi

# --- 1. Shell module ------------------------------------------------------
info "Installing shell module -> $CONFIG_DIR/claude-iterm.zsh"
run mkdir -p "$CONFIG_DIR"
run cp "$SCRIPT_DIR/claude-iterm.zsh" "$CONFIG_DIR/claude-iterm.zsh"

# --- 2. iTerm2 dynamic profile -------------------------------------------
info "Installing iTerm2 dynamic profile -> $DYNPROFILES_DIR/claude.json"
run mkdir -p "$DYNPROFILES_DIR"
run cp "$SCRIPT_DIR/claude.json" "$DYNPROFILES_DIR/claude.json"

# --- 3. iTerm2 shell integration (third-party, optional) -----------------
if $SKIP_SHELL_INTEGRATION; then
  info "Skipping iTerm2 shell integration (--skip-shell-integration)."
elif [ -f "$SHELL_INTEGRATION" ]; then
  info "iTerm2 shell integration already present, leaving as-is."
elif $DRY_RUN; then
  printf '[dry-run] curl -fsSL https://iterm2.com/shell_integration/zsh -o %s\n' "$SHELL_INTEGRATION"
else
  info "Fetching iTerm2 shell integration -> $SHELL_INTEGRATION"
  if ! curl -fsSL https://iterm2.com/shell_integration/zsh -o "$SHELL_INTEGRATION"; then
    warn "Could not download shell integration (offline?). Skipping; theming still works."
  fi
fi

# --- 4. ~/.zshrc wiring (idempotent, backed up) --------------------------
if [ -f "$ZSHRC" ] && grep -qF "$MARKER_START" "$ZSHRC"; then
  info "$ZSHRC already wired (marker present), leaving as-is."
elif $DRY_RUN; then
  printf '[dry-run] back up %s and append the axel iterm-theming source block\n' "$ZSHRC"
else
  info "Wiring $ZSHRC (a timestamped backup is created first)."
  if [ -f "$ZSHRC" ]; then
    cp "$ZSHRC" "$ZSHRC.bak.$(date +%Y%m%d%H%M%S)"
  fi
  {
    echo ""
    cat <<'BLOCK'
# >>> axel iterm-theming >>>
# iTerm2 session theming (AXEL extra). Remove this block to revert.
DISABLE_AUTO_TITLE="true"
[[ -f "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"
[[ -f "$HOME/.config/iterm/claude-iterm.zsh" ]] && source "$HOME/.config/iterm/claude-iterm.zsh"
# <<< axel iterm-theming <<<
BLOCK
  } >> "$ZSHRC"
fi

info "Done."
echo
info "Next steps:"
info "  1. Open a new iTerm2 tab (or run: exec zsh) to load it."
info "  2. Optional, for the bigger badge + confirm-before-closing + unlimited"
info "     scrollback: iTerm2 Settings > Profiles > select 'Claude' > Other"
info "     Actions > Set as Default."
info "  Commands: 'tabname <name>' pins a tab name; 'tabcolor <1-20>' forces a color."
