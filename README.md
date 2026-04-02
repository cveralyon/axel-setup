# AXEL Onboarding — Claude Code Team Configuration

**AXEL** = Autonomous eXcelsior Engineering Layer

This package **adds** the AXEL stack to your existing Claude Code setup. It is fully **additive** — it never overwrites your existing memory, settings, hooks, or CLAUDE.md. Everything you already have is preserved.

## What's Included

| Component | Count | Description |
|---|---|---|
| **Hooks** | 13 | Session management, auto-linting, proactive error resolution, memory extraction, context monitoring |
| **Commands** | 12 + 26 GSD | Slash commands: `/daily`, `/style`, `/create-pr`, `/gsd:*`, etc. |
| **Agents** | 41 | Specialized subagents: excelsior-verifier, bughunter, cross-repo, TDD, etc. |
| **Skills** | 2 | Multi-file skills: memory-review, ui-ux-pro-max |
| **Plugins** | 13 | Official marketplace: code-review, context7, frontend-design, LSPs, etc. |
| **Settings** | Full | Permissions, feature flags, hook wiring, statusline |
| **CLAUDE.md** | Team template | Team conventions, Excelsior principle, environment mapping (customizable) |

## Quick Start

```bash
# Clone or download this package
# Then run:
bash bootstrap.sh --user-name "Tu Nombre"

# Or dry run first to see what it does:
bash bootstrap.sh --dry-run
```

**Safe to run multiple times** — it only adds what's missing. Existing files are never overwritten.

## Prerequisites

- **Claude Code CLI** installed (`claude --version`)
- **Node.js >= 18** (for hook scripts)
- **jq** (`brew install jq`)
- **python3** (ships with macOS)

## What the Bootstrap Does

1. **Backs up** your existing `~/.claude/` config (safety net)
2. **Adds hooks** that don't already exist (never overwrites your custom hooks)
3. **Adds commands** that don't already exist (preserves your custom commands)
4. **Adds agents** that don't already exist
5. **Installs plugins** you don't have yet (skips already-installed)
6. **Merges settings** — deep-merges new hooks/plugins/features into your existing settings.json
7. **Preserves memory** — never touches your memory files, only ensures directory structure
8. **Offers CLAUDE.md** — only if you don't have one yet

## Post-Install

1. **Restart Claude Code** to load plugins
2. **Customize `~/CLAUDE.md`** — add your personal section (name, role, preferences)
3. **Try these commands:**
   - `/daily` — daily briefing
   - `/style` — switch response style (debug, teach, architect, ship)
   - `/gsd:help` — GSD workflow system
   - `/create-pr` — create a PR with summary

## Hook Architecture

```
SessionStart
  ├── gsd-check-update.js     — Check GSD package updates
  └── session-restore.sh      — Restore previous session context

PreToolUse
  ├── --no-verify blocker     — Prevents bypassing git hooks
  ├── staging guard            — Warns before RAILS_ENV=staging
  └── gsd-prompt-guard.js     — Prompt injection detection

PostToolUse
  ├── proactive-resolver.sh   — Auto-resolve service failures
  ├── post-edit-lint.sh       — Auto-lint after file edits
  ├── gsd-context-monitor.js  — Context window warnings
  ├── session-log-action.sh   — Log tool actions
  ├── session-checkpoint.sh   — Periodic checkpoint summaries
  └── post-commit-verify.sh   — Trigger verification after commits

PreCompact
  └── precompact-save-context.sh — Save rich context before compaction

Stop
  ├── session-summarize.sh    — Compile session summary (Sonnet)
  ├── memory-extractor.sh     — Extract learnings to memory (Sonnet)
  └── desktop-notify.sh       — macOS notification when done
```

## Memory System

Your existing memory is **fully preserved**. The bootstrap only ensures the directory structure exists.

Memory types (auto-extracted by hooks):
- **user**: your role, preferences, expertise
- **feedback**: corrections and validated approaches
- **project**: technical decisions, team context
- **reference**: external system pointers

The `memory-extractor.sh` hook automatically extracts key learnings at session end.
The `memory-dedup.sh` hook prevents duplicate entries.

## Customization

### Adding your own hooks
Edit `~/.claude/settings.json` and add entries to the hooks section.

### Removing components you don't need
- Delete files from `~/.claude/hooks/`, `~/.claude/commands/`, or `~/.claude/agents/`
- Remove corresponding hook references from `settings.json`
- Disable plugins: set to `false` in `settings.json` → `enabledPlugins`

### Language
Default is Spanish. Change `"language"` in settings.json.

## What's NOT Touched

These are personal to each developer and are never modified:
- **Memory content** — all your existing memories stay intact
- **Existing hooks** — your custom hooks are preserved, new ones are added alongside
- **settings.local.json** — your personal permission overrides are untouched
- **MCP server connections** — configured per account (Linear, Slack, etc.)
- **OpenClaw notifications** — requires personal setup (not included)
- **Disabled plugins** — if you've disabled a plugin, the merge respects that
