#!/usr/bin/env bash
# ============================================================================
# AXEL Onboarding Bootstrap — Claude Code Team Configuration
# Autonomous eXcelsior Engineering Layer
#
# ADDITIVE MODE: This script ONLY adds new things. It never overwrites
# existing files, hooks, memory, settings, or CLAUDE.md. Your personal
# configuration and memory are preserved completely.
#
# Usage: bash bootstrap.sh [--user-name "Tu Nombre"] [--dry-run]
#
# What this does:
#   1. Backs up your existing ~/.claude/ config (safety net)
#   2. ADDS hooks that don't already exist (never overwrites)
#   3. ADDS commands/skills/agents that don't already exist
#   4. Installs plugins you don't have yet (skips already-installed)
#   5. MERGES new hook wiring + features into your existing settings.json
#   6. Sets up memory directory structure (preserves all existing memory)
#   7. Offers a team CLAUDE.md only if you don't have one
#
# Prerequisites:
#   - Claude Code CLI installed (claude --version)
#   - Node.js >= 18 (for hook scripts)
#   - jq (for JSON processing in hooks and settings merge)
#   - python3 (for some hook scripts)
# ============================================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/pre-axel-$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
USER_NAME=""

# Counters
HOOKS_ADDED=0
HOOKS_UPGRADED=0
CMDS_ADDED=0
CMDS_UPGRADED=0
AGENTS_ADDED=0
AGENTS_UPGRADED=0
UPGRADES_DIR="$CLAUDE_DIR/axel-upgrades"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

log()     { printf "${GREEN}[AXEL]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${RESET} %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${RESET} %s\n" "$1" >&2; }
info()    { printf "${BLUE}[INFO]${RESET} %s\n" "$1"; }
skip()    { printf "${DIM}  skip: %s (already up to date)${RESET}\n" "$1"; }
upgrade() { printf "${YELLOW}  upgrade: %s (saved for review)${RESET}\n" "$1"; }

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --user-name) USER_NAME="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: bash bootstrap.sh [--user-name \"Tu Nombre\"] [--dry-run]"
      echo ""
      echo "This script is ADDITIVE — it only adds new things, never overwrites."
      echo "Your existing memory, settings, hooks, and CLAUDE.md are preserved."
      echo ""
      echo "Options:"
      echo "  --user-name NAME   Your name (used in session summaries)"
      echo "  --dry-run          Show what would be done without doing it"
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Prerequisites check ---
log "Checking prerequisites..."

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    error "$1 is required but not installed."
    return 1
  fi
}

MISSING=0
check_cmd "claude" || MISSING=1
check_cmd "node" || MISSING=1
check_cmd "jq" || MISSING=1
check_cmd "python3" || MISSING=1

if [ "$MISSING" -eq 1 ]; then
  error "Install missing prerequisites and try again."
  exit 1
fi

NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
  error "Node.js >= 18 required (found v$NODE_VER)"
  exit 1
fi

log "All prerequisites OK"

# --- Prompt for user name if not provided ---
if [ -z "$USER_NAME" ]; then
  printf "${BOLD}Enter your name (for session summaries): ${RESET}"
  read -r USER_NAME
  if [ -z "$USER_NAME" ]; then
    USER_NAME=$(whoami)
    warn "Using system username: $USER_NAME"
  fi
fi

# --- Dry run guard ---
run() {
  if $DRY_RUN; then
    info "[DRY RUN] $*"
  else
    "$@"
  fi
}

# Helper: copy file; if destination exists AND differs, save AXEL version for review
add_or_upgrade() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local added_var="$4"
  local upgraded_var="$5"
  local upgrade_subdir="$6"  # e.g., "hooks", "commands", "agents"

  if [ -f "$dest" ]; then
    # Check if files differ (content-based, ignoring whitespace)
    if ! diff -q "$src" "$dest" >/dev/null 2>&1; then
      # Different content — save AXEL version as upgrade proposal
      if $DRY_RUN; then
        info "[DRY RUN] Would propose upgrade: $label"
      else
        mkdir -p "$UPGRADES_DIR/$upgrade_subdir"
        cp "$src" "$UPGRADES_DIR/$upgrade_subdir/$(basename "$dest")"
      fi
      upgrade "$label"
      eval "$upgraded_var=\$((\$$upgraded_var + 1))"
    fi
    # Same content — nothing to do
  else
    if $DRY_RUN; then
      info "[DRY RUN] Would add: $label"
    else
      cp "$src" "$dest"
    fi
    eval "$added_var=\$((\$$added_var + 1))"
  fi
}

# --- Backup existing config (safety net, always) ---
if [ -d "$CLAUDE_DIR" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
  log "Creating safety backup at $BACKUP_DIR"
  run mkdir -p "$BACKUP_DIR"
  for item in settings.json settings.local.json keybindings.json; do
    [ -f "$CLAUDE_DIR/$item" ] && run cp "$CLAUDE_DIR/$item" "$BACKUP_DIR/$item"
  done
  [ -d "$CLAUDE_DIR/hooks" ] && run cp -r "$CLAUDE_DIR/hooks" "$BACKUP_DIR/hooks"
fi

# --- Create directory structure (mkdir -p is already additive) ---
log "Ensuring directory structure..."
for dir in hooks commands commands/gsd agents skills memory memory/decisions sessions sessions/checkpoints logs; do
  mkdir -p "$CLAUDE_DIR/$dir"
done

# ============================================================================
# 1. HOOKS — Only add new ones, never overwrite existing
# ============================================================================
log "Adding hooks..."

for hook_file in "$SCRIPT_DIR/hooks/"*; do
  [ -f "$hook_file" ] || continue
  BASENAME=$(basename "$hook_file")
  DEST="$CLAUDE_DIR/hooks/$BASENAME"

  # Hooks need USER_NAME substitution, so we use a temp file for comparison
  PROCESSED=$(mktemp)
  sed "s|{{USER_NAME}}|$USER_NAME|g" "$hook_file" > "$PROCESSED"

  if [ -f "$DEST" ]; then
    if ! diff -q "$PROCESSED" "$DEST" >/dev/null 2>&1; then
      if ! $DRY_RUN; then
        mkdir -p "$UPGRADES_DIR/hooks"
        cp "$PROCESSED" "$UPGRADES_DIR/hooks/$BASENAME"
      fi
      upgrade "$BASENAME"
      HOOKS_UPGRADED=$((HOOKS_UPGRADED + 1))
    fi
  else
    if ! $DRY_RUN; then
      cp "$PROCESSED" "$DEST"
      chmod +x "$DEST"
    else
      info "[DRY RUN] Would add hook: $BASENAME"
    fi
    HOOKS_ADDED=$((HOOKS_ADDED + 1))
  fi
  rm -f "$PROCESSED"
done

log "Hooks: $HOOKS_ADDED new, $HOOKS_UPGRADED upgrades available"

# ============================================================================
# 2. COMMANDS — Only add new ones
# ============================================================================
log "Adding commands..."

for cmd_file in "$SCRIPT_DIR/commands/"*.md; do
  [ -f "$cmd_file" ] || continue
  BASENAME=$(basename "$cmd_file")
  add_or_upgrade "$cmd_file" "$CLAUDE_DIR/commands/$BASENAME" "$BASENAME" "CMDS_ADDED" "CMDS_UPGRADED" "commands"
done

# GSD subcommands
GSD_ADDED=0
GSD_UPGRADED=0
if [ -d "$SCRIPT_DIR/commands/gsd" ]; then
  for cmd_file in "$SCRIPT_DIR/commands/gsd/"*.md; do
    [ -f "$cmd_file" ] || continue
    BASENAME=$(basename "$cmd_file")
    add_or_upgrade "$cmd_file" "$CLAUDE_DIR/commands/gsd/$BASENAME" "gsd/$BASENAME" "GSD_ADDED" "GSD_UPGRADED" "commands/gsd"
  done
fi

log "Commands: $CMDS_ADDED new, $CMDS_UPGRADED upgrades | GSD: $GSD_ADDED new, $GSD_UPGRADED upgrades"

# ============================================================================
# 3. AGENTS — Only add new ones
# ============================================================================
log "Adding agents..."

for agent_file in "$SCRIPT_DIR/agents/"*.md; do
  [ -f "$agent_file" ] || continue
  BASENAME=$(basename "$agent_file")
  add_or_upgrade "$agent_file" "$CLAUDE_DIR/agents/$BASENAME" "$BASENAME" "AGENTS_ADDED" "AGENTS_UPGRADED" "agents"
done

log "Agents: $AGENTS_ADDED new, $AGENTS_UPGRADED upgrades available"

# ============================================================================
# 4. SKILLS — Only add new skill directories
# ============================================================================
log "Adding skills..."

SKILLS_ADDED=0
SKILLS_UPGRADED=0
if [ -d "$SCRIPT_DIR/skills" ]; then
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    SKILL_NAME=$(basename "$skill_dir")
    if [ -d "$CLAUDE_DIR/skills/$SKILL_NAME" ]; then
      # Skill exists — check if SKILL.md differs
      if [ -f "$skill_dir/SKILL.md" ] && [ -f "$CLAUDE_DIR/skills/$SKILL_NAME/SKILL.md" ]; then
        if ! diff -q "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$SKILL_NAME/SKILL.md" >/dev/null 2>&1; then
          if ! $DRY_RUN; then
            mkdir -p "$UPGRADES_DIR/skills/$SKILL_NAME"
            cp -r "$skill_dir"* "$UPGRADES_DIR/skills/$SKILL_NAME/"
          fi
          upgrade "skill: $SKILL_NAME"
          SKILLS_UPGRADED=$((SKILLS_UPGRADED + 1))
        fi
      fi
    else
      run mkdir -p "$CLAUDE_DIR/skills/$SKILL_NAME"
      run cp -r "$skill_dir"* "$CLAUDE_DIR/skills/$SKILL_NAME/"
      SKILLS_ADDED=$((SKILLS_ADDED + 1))
    fi
  done
fi

# ============================================================================
# 5. PLUGINS — Install only those not already present
# ============================================================================
log "Installing plugins (skipping already-installed)..."

PLUGINS=(
  "frontend-design"
  "context7"
  "ruby-lsp"
  "typescript-lsp"
  "pyright-lsp"
  "code-simplifier"
  "hookify"
  "claude-md-management"
  "commit-commands"
  "pr-review-toolkit"
)

PLUGINS_ADDED=0
PLUGINS_SKIPPED=0

# Check which plugins are already installed
INSTALLED_PLUGINS=""
if [ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ]; then
  INSTALLED_PLUGINS=$(cat "$CLAUDE_DIR/plugins/installed_plugins.json")
fi

for plugin in "${PLUGINS[@]}"; do
  PLUGIN_KEY="${plugin}@claude-plugins-official"
  if echo "$INSTALLED_PLUGINS" | grep -q "\"$PLUGIN_KEY\"" 2>/dev/null; then
    skip "plugin: $plugin"
    PLUGINS_SKIPPED=$((PLUGINS_SKIPPED + 1))
  else
    if $DRY_RUN; then
      info "[DRY RUN] Would install plugin: $plugin"
    else
      log "  Installing $plugin..."
      claude plugins install "$plugin" 2>/dev/null || warn "Failed to install $plugin (may need manual install)"
    fi
    PLUGINS_ADDED=$((PLUGINS_ADDED + 1))
  fi
done

log "Plugins: $PLUGINS_ADDED added, $PLUGINS_SKIPPED already installed"

# ============================================================================
# 6. SETTINGS.JSON — MERGE, never replace
# ============================================================================
log "Merging settings.json (preserving all existing config)..."

AXEL_SETTINGS="$SCRIPT_DIR/templates/settings.json"
EXISTING_SETTINGS="$CLAUDE_DIR/settings.json"

if $DRY_RUN; then
  info "[DRY RUN] Would merge AXEL settings into existing settings.json"
elif [ ! -f "$EXISTING_SETTINGS" ]; then
  # No existing settings — just copy ours
  cp "$AXEL_SETTINGS" "$EXISTING_SETTINGS"
  log "  Created new settings.json (no existing config found)"
else
  # Deep merge using jq filter file (avoids shell escape issues)
  # Strategy: existing always wins for scalars; arrays/objects get unioned
  MERGE_FILTER="$SCRIPT_DIR/templates/merge-settings.jq"
  MERGED_FILE=$(mktemp)

  if jq -s -f "$MERGE_FILTER" "$EXISTING_SETTINGS" "$AXEL_SETTINGS" > "$MERGED_FILE" 2>/dev/null; then
    # Validate the output is valid JSON before replacing
    if jq '.' "$MERGED_FILE" >/dev/null 2>&1; then
      mv "$MERGED_FILE" "$EXISTING_SETTINGS"
      log "  Settings merged successfully (your existing config preserved)"
    else
      rm -f "$MERGED_FILE"
      warn "Settings merge produced invalid JSON — original preserved"
      cp "$AXEL_SETTINGS" "$CLAUDE_DIR/settings.axel-template.json"
    fi
  else
    rm -f "$MERGED_FILE"
    warn "Settings merge failed — your original settings.json is untouched"
    warn "AXEL settings saved to: $CLAUDE_DIR/settings.axel-template.json"
    cp "$AXEL_SETTINGS" "$CLAUDE_DIR/settings.axel-template.json"
  fi
fi

# ============================================================================
# 7. STATUSLINE — Add only if not present
# ============================================================================
if [ ! -f "$CLAUDE_DIR/statusline-command.sh" ]; then
  log "Adding statusline script..."
  run cp "$SCRIPT_DIR/templates/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
  run chmod +x "$CLAUDE_DIR/statusline-command.sh"
else
  skip "statusline-command.sh"
fi

# ============================================================================
# 7b. USAGE MONITOR — session cost log + live dashboard + web server
# ============================================================================
log "Setting up usage monitor..."

# Ensure tools dir exists
run mkdir -p "$CLAUDE_DIR/tools" "$CLAUDE_DIR/logs"

MONITOR_TOOLS=(session-server.js session-live.sh session-dashboard-gen.sh session-costs-view.sh)
MONITOR_ADDED=0
for tool in "${MONITOR_TOOLS[@]}"; do
  src="$SCRIPT_DIR/tools/$tool"
  dest="$CLAUDE_DIR/tools/$tool"
  [ -f "$src" ] || continue
  if [ ! -f "$dest" ]; then
    if ! $DRY_RUN; then cp "$src" "$dest" && chmod +x "$dest"; else info "[DRY RUN] Would add tool: $tool"; fi
    MONITOR_ADDED=$((MONITOR_ADDED + 1))
  else
    skip "tools/$tool"
  fi
done

# Install launchd service (macOS only) — auto-starts web monitor on login
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLIST_LABEL="com.${USERNAME:-$(whoami)}.claude-monitor"
  PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
  PLIST_SRC="$SCRIPT_DIR/templates/claude-monitor.plist"
  NODE_BIN=$(which node 2>/dev/null || echo "/usr/local/bin/node")

  if [ ! -f "$PLIST_DEST" ]; then
    if ! $DRY_RUN; then
      sed -e "s|{{USERNAME}}|${USERNAME:-$(whoami)}|g" \
          -e "s|{{HOME}}|$HOME|g" \
          -e "s|{{NODE_PATH}}|$NODE_BIN|g" \
          "$PLIST_SRC" > "$PLIST_DEST"
      launchctl load "$PLIST_DEST" 2>/dev/null && \
        log "  Usage monitor started at http://localhost:9119" || \
        warn "  launchd load failed — run manually: node ~/.claude/tools/session-server.js"
    else
      info "[DRY RUN] Would install launchd agent: $PLIST_LABEL"
    fi
  else
    skip "launchd agent: $PLIST_LABEL"
  fi
fi

log "Usage monitor: $MONITOR_ADDED tools added | Dashboard: http://localhost:9119"

# ============================================================================
# 8. KEYBINDINGS — Merge, not replace
# ============================================================================
if [ ! -f "$CLAUDE_DIR/keybindings.json" ]; then
  log "Adding keybindings..."
  run cp "$SCRIPT_DIR/templates/keybindings.json" "$CLAUDE_DIR/keybindings.json"
else
  skip "keybindings.json (preserving your custom bindings)"
fi

# ============================================================================
# 9. MEMORY SYSTEM — Only ensure structure exists, NEVER touch content
# ============================================================================
log "Ensuring memory system structure..."

mkdir -p "$CLAUDE_DIR/memory/decisions"

if [ ! -f "$CLAUDE_DIR/memory/MEMORY.md" ]; then
  if ! $DRY_RUN; then
    cat > "$CLAUDE_DIR/memory/MEMORY.md" << 'EOF'
# Memory Index

This file is automatically maintained. Each entry points to a memory file.
Memory types: user, feedback, project, reference.
EOF
  fi
  log "  Created MEMORY.md index (was missing)"
else
  MEMORY_COUNT=$(ls "$CLAUDE_DIR/memory/"*.md 2>/dev/null | grep -v MEMORY.md | wc -l | tr -d ' ')
  log "  Memory intact: $MEMORY_COUNT existing memories preserved"
fi

# ============================================================================
# 10. TEAM CLAUDE.MD — Offer only if not present
# ============================================================================
if [ ! -f "$HOME/CLAUDE.md" ]; then
  log "Creating starter CLAUDE.md..."
  run cp "$SCRIPT_DIR/templates/CLAUDE.md" "$HOME/CLAUDE.md"
  log "  Created ~/CLAUDE.md — customize it for your workflow"
else
  CLAUDE_MD_LINES=$(wc -l < "$HOME/CLAUDE.md" | tr -d ' ')
  log "  ~/CLAUDE.md preserved ($CLAUDE_MD_LINES lines)"
fi

# ============================================================================
# 11. GSD (Get Shit Done) package
# ============================================================================
if [ -d "$CLAUDE_DIR/get-shit-done" ]; then
  log "GSD already installed, skipping"
else
  log "Installing GSD (Get Shit Done) package..."
  if $DRY_RUN; then
    info "[DRY RUN] Would install get-shit-done-cc via npx"
  else
    npx -y get-shit-done-cc@latest 2>/dev/null && log "GSD installed" || warn "GSD install failed — install manually: npx get-shit-done-cc@latest"
  fi
fi

# ============================================================================
# 12. UPGRADE REVIEW PROMPT — Generate if there are upgrades to review
# ============================================================================
TOTAL_UPGRADES=$((HOOKS_UPGRADED + CMDS_UPGRADED + GSD_UPGRADED + AGENTS_UPGRADED + SKILLS_UPGRADED))

if [ "$TOTAL_UPGRADES" -gt 0 ] && ! $DRY_RUN; then
  log "Generating upgrade review prompt..."

  # Copy the review prompt template
  cp "$SCRIPT_DIR/templates/review-upgrades.md" "$UPGRADES_DIR/REVIEW.md"

  # Generate manifest of what needs review
  cat > "$UPGRADES_DIR/MANIFEST.md" << MANIFEST_EOF
# AXEL Upgrade Manifest

Generated: $(date +%Y-%m-%d\ %H:%M)

## Files to review

These files already existed on your system but the AXEL package has improved versions.
Your Claude Code agent will help you compare and merge the best parts of each.

MANIFEST_EOF

  for category in hooks commands commands/gsd agents skills; do
    if [ -d "$UPGRADES_DIR/$category" ]; then
      echo "### $category" >> "$UPGRADES_DIR/MANIFEST.md"
      for f in "$UPGRADES_DIR/$category/"*; do
        [ -f "$f" ] || [ -d "$f" ] || continue
        BASENAME=$(basename "$f")
        echo "- \`$BASENAME\`: upgrade at \`~/.claude/axel-upgrades/$category/$BASENAME\`, current at \`~/.claude/$category/$BASENAME\`" >> "$UPGRADES_DIR/MANIFEST.md"
      done
      echo "" >> "$UPGRADES_DIR/MANIFEST.md"
    fi
  done
fi

# ============================================================================
# DONE — Summary
# ============================================================================
echo ""
printf "${GREEN}${BOLD}============================================${RESET}\n"
printf "${GREEN}${BOLD}  AXEL Onboarding Complete!${RESET}\n"
printf "${GREEN}${BOLD}============================================${RESET}\n"
echo ""
log "All changes are ADDITIVE — nothing was overwritten or deleted."
log "Safety backup at: $BACKUP_DIR"
echo ""

printf "${BOLD}What was added (new files):${RESET}\n"
info "  Hooks:    $HOOKS_ADDED new"
info "  Commands: $CMDS_ADDED new | GSD: $GSD_ADDED new"
info "  Agents:   $AGENTS_ADDED new"
info "  Skills:   $SKILLS_ADDED new"
info "  Plugins:  $PLUGINS_ADDED new  ($PLUGINS_SKIPPED already installed)"
info "  Monitor:  $MONITOR_ADDED tools | http://localhost:9119"
echo ""

if [ "$TOTAL_UPGRADES" -gt 0 ]; then
  printf "${YELLOW}${BOLD}Upgrades available: $TOTAL_UPGRADES files have improved versions${RESET}\n"
  info "  Hooks:    $HOOKS_UPGRADED | Commands: $CMDS_UPGRADED | GSD: $GSD_UPGRADED"
  info "  Agents:   $AGENTS_UPGRADED | Skills: $SKILLS_UPGRADED"
  echo ""
  printf "${BOLD}To review and apply upgrades, run this in Claude Code:${RESET}\n"
  echo ""
  printf "  ${GREEN}Read the file ~/.claude/axel-upgrades/REVIEW.md and follow its instructions${RESET}\n"
  echo ""
  info "Your agent will compare each file, explain what's better,"
  info "and let you decide what to merge. Nothing changes without your approval."
  echo ""
fi

printf "${BOLD}What was preserved:${RESET}\n"
info "  Your existing memory (all files intact)"
info "  Your existing settings (merged, not replaced)"
info "  Your existing CLAUDE.md"
info "  Your existing hooks, commands, and agents"
echo ""

info "Next steps:"
info "  1. Restart Claude Code to load new plugins"
if [ "$TOTAL_UPGRADES" -gt 0 ]; then
  info "  2. Review upgrades: paste the command above into Claude Code"
  info "  3. Try: /daily, /style, /gsd:help"
else
  info "  2. Try: /daily, /style, /gsd:help"
fi
info "  AXEL will continue learning your personal preferences"
echo ""
