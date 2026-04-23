# AXEL Setup — Claude Code Power Configuration

**AXEL** = **A**utonomous e**X**celsior **E**ngineering **L**ayer

A complete, production-grade configuration package for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that transforms it into a proactive engineering partner. Includes session persistence, automatic memory, proactive error resolution, 41 specialized agents, 38 slash commands, and a real-time usage monitor.

## Philosophy: Excelsior

AXEL operates on the **Excelsior principle** — always beyond, always better, never stop at obstacles:

- **Proactive resolution**: When a command fails, AXEL investigates the root cause, attempts to fix it (start services, install deps, fix configs), and retries — before asking you
- **Auto-verification**: After non-trivial changes (3+ files), AXEL automatically launches a verification agent in the background
- **Session persistence**: Every session is summarized, key learnings are extracted to memory, and the next session starts with full context of what happened before
- **Context awareness**: Monitors context window usage and warns before it runs out
- **Usage monitoring**: Tracks token usage, cost, and rate limit consumption per session — live terminal dashboard and web dashboard at `http://localhost:9119`

## Quick Start

```bash
git clone https://github.com/cveralyon/axel-setup.git
cd axel-setup
bash bootstrap.sh --user-name "Your Name"
```

Advanced: pass extra context so the Stop hooks personalize their prompts:

```bash
bash bootstrap.sh \
  --user-name "Emiliano" \
  --user-context "Backend engineer at Acme, Python specialist" \
  --language spanish
```

- `--user-context` gives the memory-extractor and session-summarize hooks a short self-description so their summaries frame decisions around your role. Defaults to `a software engineer`.
- `--language` tells the same hooks which language to respond in when they generate summaries (so non-English speakers get Spanish/French/etc. summaries back). Defaults to `english`.
- Both are optional and reversible — re-run the bootstrap with different values to update. The substitutions happen at install time (sed over the hook files), not at runtime.

### Optional: PostHog product analytics integration

If your team uses PostHog and you have the [PostHog MCP](https://posthog.com/docs/mcp) connected, AXEL can install the `/posthog-weekly` skill — an analytical review of your product analytics workspace that finds anomalies, regressions, and improvement opportunities (not a metric dashboard, an actual analyst).

```bash
bash bootstrap.sh \
  --user-name "Your Name" \
  --enable-posthog \
  --posthog-context "Acme ATS — recruiting platform with AI sourcing"
```

What `--enable-posthog` installs:
- **`/posthog-weekly` skill** — pulls dashboards, insights, events, errors, and cohorts from PostHog; identifies dead events, regressions, error backlog, instrumentation gaps, and suggested cohorts; persists a 14-day cached snapshot for other commands to read.
- **`scripts/posthog-snapshot-loader.sh`** — bash helper that reads the cached snapshot and prints a markdown summary. Sourceable from any other command (e.g. `/sprint-status`, `/eod-review`, `/daily`) so they include the latest PostHog findings without re-querying.

What `--posthog-context` does: it gets substituted into the skill's prompt so the analytical lens knows what kind of product it's looking at. A good context is one sentence: name + product type + key features. Example: `"Acme ATS — recruiting platform with AI sourcing (People Finder, AI Hunt)"`. Defaults to a generic placeholder if omitted.

The skill is **gated**: without `--enable-posthog`, neither the skill nor the helper script are installed. So teams that don't use PostHog don't get extra files in their `~/.claude/`.

```bash
# Preview what it does without changing anything:
bash bootstrap.sh --dry-run
```

**Safe to run multiple times.** The bootstrap is fully additive — it only adds what's missing, proposes upgrades for existing files, and never overwrites your configuration, memory, or CLAUDE.md.

## Prerequisites

| Tool | Why | Install |
|------|-----|---------|
| **Claude Code CLI** | The tool being configured | [docs.anthropic.com](https://docs.anthropic.com/en/docs/claude-code) |
| **Node.js >= 18** | Hook scripts (session management, context monitor) | `brew install node` |
| **jq** | JSON processing in hooks and settings merge | `brew install jq` |
| **python3** | Some hook scripts | Ships with macOS |

## What's Included

### Hooks (18)

The hook system runs automatically during Claude Code lifecycle events:

| Event | Hook | What it does |
|-------|------|-------------|
| **SessionStart** | `session-restore.sh` | Restores context from previous sessions — you pick up where you left off |
| **UserPromptSubmit** | `session-auto-title.sh` | Auto-names the session from your first prompt — strips greetings, fillers, and assistant-name salutations. Flag-file idempotency so it only fires once per session. |
| **PreToolUse** | `--no-verify` blocker | Blocks `git commit --no-verify` — never bypass git hooks |
| **PreToolUse** | `validate-commit-format.sh` | Validates commit message format: `type (Scope): Message`. Parses `-m` flag and heredocs. |
| **PreToolUse** | staging guard | Warns before running anything with `RAILS_ENV=staging` (= production) |
| **PostToolUse** | `proactive-resolver.sh` | Auto-starts Docker, PostgreSQL, Redis when they're down. Detects missing deps and suggests install commands |
| **PostToolUse** | `post-edit-lint.sh` | Auto-runs rubocop/eslint/ruff after file edits (Ruby, TS/JS, Python) |
| **PostToolUse** | `gsd-context-monitor.js` | Warns the agent when context window is running low (15% warning, 8% critical) with debounce and severity escalation |
| **PostToolUse** | `session-log-action.sh` | Logs tool actions for session persistence |
| **PostToolUse** | `session-checkpoint.sh` | Every ~40 tool calls, summarizes progress using Claude Sonnet |
| **PostToolUse** | `post-commit-verify.sh` | After git commits, suggests launching the excelsior-verifier agent |
| **PostToolUse** | `post-commit-memory-trigger.sh` | After a `git commit`, triggers the memory extractor with a 5-minute rate limit to batch consecutive commits |
| **PostToolUse** | `linear-lifecycle-sync.sh` | Auto-moves Linear cards based on git actions: commit → In Progress, `gh pr create` → In Review, `gh pr merge` → Done. Requires Linear MCP. Configurable ticket pattern and repo filter. |
| **PreCompact** | `precompact-save-context.sh` | Saves rich context snapshot before compaction (git state, pending work, decisions) |
| **Stop** | `session-summarize.sh` | Compiles a structured session summary using Claude Sonnet |
| **Stop** | `memory-extractor.sh` | Extracts key learnings and decisions to persistent memory using Claude Sonnet |
| **Stop** | `session-cost-log.sh` | Logs session cost, tokens, and 5h rate limit consumption to `~/.claude/session-costs.log` |
| **Stop** | `desktop-notify.sh` | macOS notification when Claude finishes (only when terminal is not focused) |
| **SessionStart** _(opt-in)_ | `priority-map-staleness.sh` | Warns if `~/.claude/memory/priority-map.md` hasn't been touched in ≥14 days. Enable by wiring into `settings.json` SessionStart. |
| **Cron / weekly** _(opt-in)_ | `weekly-priority-map-review.sh` | Weekly run (e.g., Monday 9am via LaunchAgent) that correlates git activity from the last 7 days against the current priority map and writes an update proposal. Requires `PRIORITY_MAP_REPOS` env var with space-separated absolute repo paths. |

> **Note:** the two `priority-map-*` hooks are opt-in — they are not cabled into `settings.json` by default because they assume `~/.claude/memory/priority-map.md` exists. Create that file first, then wire the hooks (SessionStart for staleness, LaunchAgent/cron for the weekly review).

### Commands (12 custom + 26 GSD)

Slash commands you can use in Claude Code:

| Command | Description |
|---------|-------------|
| `/daily` | Daily briefing — pulls Linear issues, calendar events, and blockers (Phase 2: system sync) |
| `/eod-review` | End-of-day review — non-technical tone, audience-aware drafts for Slack/Linear |
| `/sprint-status` | Sprint status report — dual-audience (technical + plain-language), Linear+Notion+Slack aware |
| `/style` | Switch response style: `debug`, `teach`, `architect`, `ship` (interactive picker) |
| `/create-pr` | Create a PR with auto-generated summary |
| `/deslop` | Remove AI-generated slop from code |
| `/draft-message` | Help structure important Slack/email messages |
| `/generate-prp` | Generate a Product Requirements Prompt from an INITIAL.md |
| `/execute-prp` | Execute an existing PRP step by step |
| `/multi-repo-feature` | Plan and coordinate features spanning multiple repos |
| `/roadmap` | Generate feature and improvement suggestions |
| `/visualize` | Visualize code architecture |

Plus **26 GSD (Get Shit Done) subcommands** for structured project execution:
`/gsd:help`, `/gsd:fast`, `/gsd:quick`, `/gsd:debug`, `/gsd:progress`, `/gsd:autonomous`, `/gsd:pause-work`, `/gsd:resume-work`, `/gsd:map-codebase`, `/gsd:session-report`, and more.

### Agents (41)

Specialized subagents that Claude Code can spawn for focused tasks:

| Category | Agents |
|----------|--------|
| **Verification** | `excelsior-verifier`, `production-validator` |
| **Code Quality** | `bughunter`, `security-check`, `cleanup`, `perf` |
| **Development** | `feature`, `debug`, `tdd-mainder`, `test-gen`, `api-design` |
| **Review** | `review`, `compare-branch`, `changelog` |
| **Operations** | `deploy-check`, `db-check`, `incident` |
| **Multi-repo** | `cross-repo`, `linear-task` |
| **Communication** | `draft-message`, `sprint-summary` |
| **Onboarding** | `onboard` |
| **GSD System** | 20+ agents for structured project execution (planner, executor, verifier, researcher, etc.) |

### Usage Monitor

AXEL installs a lightweight Node.js server that runs in the background (via launchd on macOS) and serves a real-time usage dashboard.

**Live web dashboard** — auto-starts at login, always available at:
```
http://localhost:9119
```

Features:
- Summary cards: total cost, today's cost, tokens, 5h rate limit % consumed
- **Active sessions panel** with live progress bars (context %, 5h %, cost, per-session delta)
- 4 charts: cost/day, 5h% per session, tokens (in+out stacked), sessions by project
- Full session history table with filtering and sorting
- Auto-refreshes every 30 seconds, no page reload needed

**Status bar** shows live data on every Claude Code interaction:
```
Mainder-API | (main) | Sonnet 4.6 | ctx:69% | $1.26 | 5h:22% (+3.2%)
```

**Terminal live view** — runs in a terminal pane, updates every 10s:
```bash
watch -n 10 -c ~/.claude/tools/session-live.sh
```

**CLI log viewer:**
```bash
~/.claude/tools/session-costs-view.sh           # last 30 sessions
~/.claude/tools/session-costs-view.sh today     # today only
~/.claude/tools/session-costs-view.sh week      # last 7 days
~/.claude/tools/session-costs-view.sh summary   # totals by day
```

**How the 5h rate limit tracking works:**
- The `5h-acum` column shows the cumulative % of the 5-hour window used at session close
- The `5h-sesion` column shows how much of the limit **this specific session** consumed (`end% - start%`)
- The status bar shows both: `5h:22% (+3.2%)` = 22% total, this session used 3.2%

### Skills (2 + 1 optional)

Multi-file skills with data and scripts:

- **memory-review** — Review, optimize, and deduplicate the persistent memory system
- **ui-ux-pro-max** — UI/UX design intelligence with 67 styles, 96 palettes, 57 font pairings, 25 chart types, 13 frontend stacks
- **posthog-weekly** _(optional, requires `--enable-posthog` at install)_ — Weekly analytical review of your PostHog workspace. Finds dead events, regressions, instrumentation gaps, error triage debt; suggests cohorts to create; persists a 14-day cached snapshot that other commands can read for daily/sprint reports.

### Plugins (10)

Official Claude Code marketplace plugins:

| Plugin | Purpose |
|--------|---------|
| `frontend-design` | Anti-slop UI guidelines, auto-activates on frontend tasks |
| `context7` | Live documentation fetching for any library/framework |
| `ruby-lsp` | Ruby language server integration |
| `typescript-lsp` | TypeScript language server integration |
| `pyright-lsp` | Python type checking integration |
| `code-simplifier` | Simplify and refine code for clarity |
| `hookify` | Create hooks from conversation analysis |
| `claude-md-management` | Audit and improve CLAUDE.md files |
| `commit-commands` | Git commit, push, and PR workflows |
| `pr-review-toolkit` | Comprehensive PR review with specialized agents |

## How the Bootstrap Works

### For new files: Install

Files that don't exist on your system are copied directly.

### For existing files: Propose Upgrade

When a file already exists but the AXEL version is different (potentially better), the bootstrap:

1. Saves the AXEL version to `~/.claude/axel-upgrades/<category>/`
2. Generates a `MANIFEST.md` listing all files with available upgrades
3. Creates a `REVIEW.md` prompt that your Claude Code agent can follow

**To review upgrades**, paste this into Claude Code after running the bootstrap:

```
Read the file ~/.claude/axel-upgrades/REVIEW.md and follow its instructions
```

Your agent will compare each file side-by-side, explain what's better in each version, and let you decide: **keep current**, **use AXEL version**, or **merge the best of both**. Nothing changes without your explicit approval.

### For settings.json: Deep Merge

The bootstrap uses a `jq` filter to deep-merge settings:

- **Scalar values** (language, theme, etc.): your existing value always wins
- **Hook arrays**: AXEL hooks are added alongside yours (deduplicated by command string)
- **Plugin map**: new plugins are added; if you disabled a plugin, it stays disabled
- **Permission arrays**: union of both lists
- **Environment variables**: your existing vars are kept, missing ones are added

### For memory: Never Touch

Your memory files are never read, modified, or deleted. The bootstrap only ensures the directory structure exists (`~/.claude/memory/`, `~/.claude/memory/decisions/`).

## Memory System

AXEL includes an automatic persistent memory system:

- **`memory-extractor.sh`** (Stop hook): At session end, uses Claude Sonnet to analyze the conversation and extract key learnings, decisions, and preferences to `~/.claude/memory/` files
- **`memory-dedup.sh`**: Hash-based duplicate detection + orphan cleanup + dead link removal
- **`session-summarize.sh`** (Stop hook): Compiles a structured session summary for the next session's context
- **`session-restore.sh`** (SessionStart hook): Loads previous session summaries so you pick up where you left off

Memory types:
| Type | Purpose | Example |
|------|---------|---------|
| `user` | Your role, preferences, expertise | "Senior backend dev, prefers terse responses" |
| `feedback` | How to work with you (dos and don'ts) | "Never mock the database in integration tests" |
| `project` | Technical decisions, team context | "Auth rewrite driven by compliance requirements" |
| `reference` | Where to find things in external systems | "Pipeline bugs tracked in Linear project INGEST" |

## Customization

### Adding your own hooks

Edit `~/.claude/settings.json` and add entries to the relevant event:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "your-custom-hook.sh" }]
      }
    ]
  }
}
```

### Removing components

- **Hooks**: Delete from `~/.claude/hooks/` and remove the corresponding entry in `settings.json`
- **Commands**: Delete from `~/.claude/commands/`
- **Agents**: Delete from `~/.claude/agents/`
- **Plugins**: Set to `false` in `settings.json` → `enabledPlugins`

### Language

Default is Spanish. Change `"language"` in `settings.json` to your preferred language.

### Team CLAUDE.md

The template at `~/CLAUDE.md` (created only if you don't have one) includes:
- Commit format conventions
- Environment mapping (test/development/staging)
- Excelsior principle configuration
- Multi-repo workflow guidelines

Customize it with your team's specific repos, conventions, and rules.

## What's NOT Touched

These are personal to each developer and are never modified:

- **Memory content** — all your existing memories stay intact
- **Existing hooks** — your custom hooks are preserved; new ones are added alongside
- **settings.local.json** — your personal permission overrides are untouched
- **MCP server connections** — configured per account (Linear, Slack, GitHub, etc.)
- **Disabled plugins** — if you've disabled a plugin, the merge respects that

## Requirements

- macOS (hooks use macOS-specific features like `osascript` for notifications)
- Claude Code CLI with an active subscription
- The `session-summarize.sh` and `memory-extractor.sh` hooks use `claude -p --model sonnet` for quality extraction — this consumes API tokens at session end

## Troubleshooting

### Usage dashboard not responding on http://localhost:9119

On a fresh `bootstrap.sh` run the launchd agent is installed and loaded automatically. If the dashboard stops responding — usually after a reboot on a machine where the plist was never registered with launchd, or after a manual install that left the plist outside `~/Library/LaunchAgents/` — run these checks:

```bash
# 1. Is anything listening on the port?
lsof -iTCP:9119 -sTCP:LISTEN

# 2. Is the launchd agent loaded?
launchctl list | grep claude-monitor

# 3. Is the plist in the right place?
ls -l ~/Library/LaunchAgents/com.*.claude-monitor.plist
```

If the plist is missing from `~/Library/LaunchAgents/`, reinstall it from the template and load it:

```bash
USERNAME=$(whoami)
NODE_BIN=$(which node)
PLIST_DEST="$HOME/Library/LaunchAgents/com.${USERNAME}.claude-monitor.plist"

sed -e "s|{{USERNAME}}|$USERNAME|g" \
    -e "s|{{HOME}}|$HOME|g" \
    -e "s|{{NODE_PATH}}|$NODE_BIN|g" \
    ~/.claude/axel-upgrades/templates/claude-monitor.plist > "$PLIST_DEST" 2>/dev/null || \
  sed -e "s|{{USERNAME}}|$USERNAME|g" -e "s|{{HOME}}|$HOME|g" -e "s|{{NODE_PATH}}|$NODE_BIN|g" \
      "$(git -C ~/axel-onboarding rev-parse --show-toplevel 2>/dev/null)/templates/claude-monitor.plist" > "$PLIST_DEST"

launchctl load -w "$PLIST_DEST"
curl -sS -o /dev/null -w "HTTP: %{http_code}\n" http://localhost:9119
```

Expected output: `HTTP: 200`. Logs live at `~/.claude/logs/monitor.log` and `~/.claude/logs/monitor-error.log`.

If the agent runs but the port stays closed, check the error log — most failures are a wrong `NODE_PATH` (fix: re-run the `sed` above after updating `NODE_BIN`) or a permission issue on `~/.claude/session-costs.log`.

## Release notes

See [`CHANGELOG.md`](./CHANGELOG.md) for the full history of changes grouped by date and scope.

## License

MIT
