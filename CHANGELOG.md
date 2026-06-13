# Changelog

All notable changes to AXEL Setup are documented in this file.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases are grouped by date and logical scope. npm package releases use semver tags.

---

## [Unreleased]

---

## [0.2.0] 2026-06-12 setup hardening and npm release

### Added
- Install profiles: `personal`, `team-safe`, `minimal`, `ci`, and `full`.
- Bootstrap flags for CI and safer installs: `--skip-plugins`, `--skip-monitor`, `--skip-keybindings`, `--skip-claude-md`, `--skip-gsd`, and `--no-launchd`.
- Machine-readable `axel-manifest.json` installed into `~/.claude/axel-manifest.json`.
- `axel-setup doctor [--home PATH]` to verify installed files against the manifest.
- Integration tests for dry-run behavior, real temp-home installation, recursive skill assets, CLI doctor, and `merge-settings.jq` fixtures.
- Public multi-runtime roadmap for keeping Claude Code as the default install target while planning Codex and generic adapters.
- Experimental `--target codex` and `--target generic --output <dir>` adapters that install portable AXEL assets without Claude-only hooks, plugins, settings, launchd, or GSD side effects.
- Target-aware `axel-setup doctor --target claude|codex|generic` validation.
- GitHub Actions release workflow for `v*` tags that verifies the tag matches `package.json`, re-runs repository validation, skips already-published versions, and publishes `axel-setup` to npm with provenance when `NPM_TOKEN` is configured.

### Changed
- `--dry-run` now keeps installer filesystem writes read-only.
- Skill installation now copies nested assets recursively while excluding Python cache files.
- CI now installs `shellcheck` and `shfmt`; `npm run check` owns shell syntax, shellcheck, shfmt, JSON, jq, integration tests, and package dry-run validation.
- README now documents `npx axel-setup` as the primary install path, release automation, profiles, skip flags, and `doctor`.

## [0.1.1] 2026-06-12 npm publish hardening

Prepare the npm package for the first public registry publish without changing bootstrap behavior.

### Added
- npm package metadata for author and discovery keywords.
- `npm run publish:dry-run` maintainer script.
- README maintainer publish checklist with root directory and explicit path examples.

### Changed
- `prepublishOnly` now runs the full repository check before registry publish.

---

## [2026-06-12] OSS readiness and package entrypoint

Prepare AXEL Setup for a stronger public open source application and a cleaner contributor workflow.

### Added
- `CONTRIBUTING.md` with project scope, local setup, validation, PR expectations, and security reporting guidance.
- GitHub issue forms for bugs, features, and roadmap items, plus a pull request template.
- GitHub Actions CI that runs repository checks on pushes to `main` and on pull requests.
- `package.json` and `bin/axel-setup.js` so the bootstrap can be run through npm from GitHub and published as `axel-setup`.
- `scripts/ci/check.sh` and `scripts/ci/bootstrap-dry-run.sh` for shell syntax checks, jq validation, JSON validation, bootstrap smoke testing, and npm package dry run checks.

### Changed
- `README.md` now includes an explicit Ecosystem Relevance section and documents the npm based install path.

---

## [2026-06-11] Subagent model routing

With a Fable-class model on the main thread, any Agent call without an explicit `model` param silently inherits the session model, so token-heavy subagent work (exploration, log triage, bounded edits) runs at the most expensive tier in the catalog. This change adds a routing layer: judgment stays on the session model, everything delegated gets an explicit cheaper tier. Pattern distilled from `efficient-fable` (github.com/BuilderIO/skills), completed with the task-to-tier table and cost anchors that the original omits.

### Added
- `skills/model-routing/SKILL.md`: routing table (sonnet for exploration/research/bounded implementation, haiku for mechanical reduction, opus for risky implementation and adversarial verification), handoff packet template, vetting protocol, and anti-waste rules.
- `hooks/enforce-agent-model.jq`: PreToolUse filter that denies any Agent call missing the `model` param; the deny reason embeds the routing table so the retry succeeds first try.

### Changed
- `templates/settings.json`: new PreToolUse hook entry (matcher `Agent`) wiring the jq filter.
- `templates/CLAUDE.md`: Coordinator Mode gains step 5 (explicit model routing on every Agent call).

## [2026-06-02] — Decouple GSD from AXEL

GSD (get-shit-done) was vendored as a frozen snapshot inside AXEL (18 `gsd-*` agents + `commands/gsd/` in the retired `/gsd:` format). GSD now updates independently through its own installer, so the bundled copy only caused version + command-format skew — and on re-bootstrap would resurrect `commands/gsd/` files that GSD deleted upstream in favor of `/gsd-` skills. Complements the settings-template GSD hook removals from 2026-04-22.

### Removed
- `agents/gsd-*.md` (18 vendored GSD agents) — now owned by the GSD installer.
- `commands/gsd/` (GSD subcommands in `/gsd:` colon format) — superseded by `/gsd-` skills upstream.

### Changed
- `bootstrap.sh` no longer creates `commands/gsd/`, iterates GSD subcommands, or reports GSD counts. It detects the live GSD skills and, if absent, points the user to `npx get-shit-done-cc@latest --claude --global`.
- Help hints updated `/gsd:help` → `/gsd-help`.
- `README.md` drops hardcoded agent/command counts (they drifted) and documents the GSD decoupling.

### Added
- `agents/{onboard,feature,debug,security-check}.md` — advisory escalations to current GSD capabilities (`gsd-map-codebase`/`graphify`, `gsd-spike`/`sketch`, `gsd-debug`, `gsd-secure-phase`); subagents recommend, the main loop runs the skill.
- `templates/CLAUDE.md` — "Agentic Skill Activation" decision tree: canonical skill per intent with an anti-overhead guardrail.

---

## [2026-04-23] — Linear lifecycle auto-sync hook

### Added
- `hooks/linear-lifecycle-sync.sh` — PostToolUse hook that automatically moves Linear cards through the lifecycle based on git/gh actions: `git commit (KEY-123)` → In Progress, `gh pr create` → In Review, `gh pr merge` → Done. Uses `claude -p haiku` + Linear MCP under the hood. Features a 90-second debounce per action type, skip logic for cards already in the target state or further along, and a `~/.claude/logs/linear-sync.log` audit trail. Configurable ticket pattern (`{{TICKET_PATTERN}}`), repo path filter (`{{REPO_PATH_FILTER}}`), and team name (`{{LINEAR_TEAM}}`) — substituted by bootstrap at install time.

---

## [2026-04-23] — Linear lifecycle rule + priority-map deprecation

### Added
- `templates/CLAUDE.md` — new `## Linear Lifecycle (HARD RULE)` section: any code change requires a project tracker ticket; covers the full state machine (create before starting, In Progress on start, In Review on PR, Done on merge, Cancelled if dropped). Generic wording works with Linear, Jira, or any equivalent tool.

### Changed
- `templates/CLAUDE.md` — two new HARD RULE bullets from yesterday's session are now visible in the rendered template: no AI co-author attribution in commits, and always draft before sending external messages (Slack, Gmail, Intercom).

### Notes
- The `priority-map-staleness.sh` and `weekly-priority-map-review.sh` hooks remain in the repo as opt-in. The tradeoff: a static priority-map grows stale quickly and can introduce context mismatches against the live state in Linear/Slack. If you use them, treat the file as a rough guide only — Linear is always the source of truth.

---

## [2026-04-22] — Memory system hardening + hook improvements

### Added
- `hooks/post-commit-memory-trigger.sh` — new PostToolUse hook that triggers memory extraction only after real `git commit` commands (not diff/log/status). Combined with the 5-min rate limit in `memory-extractor.sh`, this prevents extraction on every session end and groups burst commits into a single run.
- `hooks/gsd-context-monitor.js` — context window monitor now included in the repo (was documented in README but missing from hooks/). Warns the agent when context drops below 15% (warning) or 8% (critical) with debounce and severity escalation.

### Changed
- `hooks/memory-extractor.sh` — added 5-minute rate-limit debounce: skips extraction if run within the last 5 minutes, preventing over-extraction from consecutive commits or rapid session cycling.
- `hooks/validate-commit-format.sh` — improved error output: `BLOCKED:` instead of `WARNING:`, canonical example, explicit "do not use --no-verify" instruction.
- `hooks/proactive-resolver.sh` — Docker wait loop reduced from 30s to 15s; adds hint message if Docker does not start within the window.
- `templates/settings.json` — removed `gsd-prompt-guard.js` (GSD plugin hook, not part of AXEL core); removed `gsd-check-update.js` SessionStart hook; reduced `gsd-context-monitor.js` timeout 10→3; reduced `proactive-resolver.sh` timeout 45→30; added `post-commit-memory-trigger.sh`; reduced `autoCompactWindow` 1,000,000→500,000.
- `templates/CLAUDE.md` — added two HARD RULE bullets: no AI co-author attribution in commits, and always draft before sending Slack/email/Intercom messages.

---

## [2026-04-17] — Priority Map hooks

### Added
- `hooks/priority-map-staleness.sh` — SessionStart warning when `priority-map.md` is stale (≥14 days without edits).
- `hooks/weekly-priority-map-review.sh` — weekly cron proposal that reconciles git activity with the current priority map.

---

## [2026-04-14] — Onboarding genericization

Make AXEL installable for teammates (Emi, Álex) without hardcoded personal values.

### Added
- `/posthog-weekly` skill — gated behind `--enable-posthog` flag. Weekly analytical review of a PostHog workspace with `--posthog-context` injected into the prompt. Ships `posthog-snapshot-loader.sh` for other commands to consume the 14-day cached snapshot (`66f6fae`)
- `bootstrap.sh --user-context` and `--language` flags — substituted into `memory-extractor` and `session-summarize` hooks at install time via `sed` (`59b1de9`)
- `session-auto-title.sh` hook — auto-names the session from the first user prompt, strips greetings and assistant-name salutations. Idempotent via flag file (`dde0f4d`)
- `validate-commit-format.sh` hook — enforces `type (Scope): Message` format. Parses `-m` flag and heredoc bodies (`dde0f4d`)

### Changed
- Commands `daily` / `eod-review` / `sprint-status` moved to YAML-config model — no hardcoded IDs, paths, or personal context in the command files (`b19c8b0`)

### Fixed
- `claude -p` subprocesses in Stop hooks now isolated via `mktemp -d` — previously they accumulated JSONL in the main project directory and polluted `/resume` history (`80f1f2e`)

---

## [2026-04-13] — Commands consolidation

### Added
- `/eod-review` command — end-of-day report with 100% non-technical tone targeted at Samu and Javi (`f17f555`, `1372508`)
- `/daily` Phase 2 — system sync step after the briefing pulls latest state from Linear/Slack/Notion (`921e3db`)

### Removed
- Redundant org skills consolidated into `/daily` and `/eod-review` (`f17f555`)

---

## [2026-04-09] — Sprint status overhaul

### Added
- `/sprint-status` (replaces `/sprint-summary`) — consolidated into Linear as source of truth, with privacy gate + review outputs and dual-audience layer (technical + plain-language ~15 lines for mixed Slack channels) (`7b8b91a`, `30480ee`)
- Session-learned policies encoded into the command: CS messaging tone, backfill granularity (1 PR = 1 card), Notion read-only policy (`e082ab8`, `2d6524a`, `e38fd21`)

### Fixed
- Support channel classified as internal, so drafts are notes for the team and not customer facing (`39efac2`)
- Draft targeting: reply in the original Slack thread, not the user's DM (`fd64145`)

### Changed
- Sprint/weekly review commands now pull from Notion, Slack, and split main vs staging correctly (`3df1e99`)

---

## [2026-04-07..09] — Usage monitor

### Added
- Real-time usage monitor — Node.js web dashboard at `http://localhost:9119`, live terminal view, CLI log viewers, launchd agent for auto-start at login (`1bb5e70`)
- Dashboard troubleshooting section in README covering launchd plist recovery (`6154ae2`)

### Fixed
- Session log deduplication via upsert; start file preserved across restarts (`cd5e3f7`)
- Cost display: 2 decimal places instead of 3 (`37f0f5d`)

---

## [2026-04-02] — Initial release

### Added
- Initial AXEL Setup package — Claude Code team configuration with hooks, commands, agents, skills, and plugins (`e21be13`)
- Full README with usage guide and MIT license (`4dcc6be`)
- Commit-format PreToolUse hook (`9e00b15`)

### Changed
- Plugin list trimmed to reduce token usage at session start (`9e00b15`, `862df59`)
