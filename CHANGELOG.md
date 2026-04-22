# Changelog

All notable changes to AXEL Setup are documented in this file.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases are grouped by date and logical scope (no semver tagging yet).

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
- `#clients` identified as an INTERNAL channel — drafts are notes for Javi, not customer-facing (`39efac2`)
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
