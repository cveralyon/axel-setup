# EOD Review — End-of-Day team report

Generate an end-of-day report with everything that was done, changed, or moved TODAY. Designed to give non-technical stakeholders (CEO, PM, CS lead) clear visibility into delivery progress without requiring them to read PRs or Linear.

The output is a **Slack draft** (never a direct send) ready for the user to review and post. When the target channel is mixed (devs + non-devs), a dual layer is produced: non-technical summary on top, optional technical detail below.

## Configuration (edit this section for your team)

Before using this skill, edit the YAML block below with your team's channels, repos, and target audience. Sections marked `[OPTIONAL]` can be deleted if your team does not use that system.

```yaml
# --- Target channel for the draft (where the report will be posted) ---
target_channel:
  name: "#tech-guild"     # id: Cxxxxxxx
  audience: "mixed"        # "mixed" | "technical" | "non-technical"

# --- Slack channels to scan for context on what happened today ---
slack_channels:
  - name: "#incidents"
  - name: "#tech-guild"
  - name: "#clients"

# --- Git repos to scan for "what was done today" ---
git_repos:
  - ~/your-org/api-repo
  - ~/your-org/frontend-repo

# --- Team member git-email → display-name mapping ---
team_members:
  - { email: "you@company.com", name: "You" }
  - { email: "teammate@company.com", name: "Teammate" }

# --- Optional integrations ---
integrations:
  linear: true            # requires Linear MCP
  intercom: false         # [OPTIONAL] requires Intercom MCP — client-facing metrics
  notion: false           # [OPTIONAL] never queried from this command
```

## When to use

- At the end of the workday, before closing
- When your PM/CEO asks "what was done today"
- Before a standup or sync where you need to show daily progress

## Data sources (all read-only, all in parallel)

### Git (primary source for "what was done today")
For each repo in `git_repos`:
- `git fetch origin --prune`
- PRs merged TODAY by anyone: `gh pr list --state merged --search "merged:>=TODAY"`
- PRs opened TODAY
- Commits pushed to staging/feature branches TODAY
- Map authors via `team_members` (git email → display name)

### Linear (if `integrations.linear`)
- Issues moved to Done today
- Issues moved to In Progress today (started)
- New issues created today
- Comments added today

### Slack (secondary — for context)
For each channel in `slack_channels`:
- Any new incidents today (resolved or open)
- Important messages (asks from leadership, decisions)
- New client requests today (count + brief summary)

### Intercom `[OPTIONAL]` (if `integrations.intercom` — primary source for client-facing metrics)
- Conversations with activity TODAY: `mcp__intercom__search_conversations` filtered by `updated_at >= today`
- Count: created today / resolved today / still open / priority flagged
- Cross-ref with Slack client channels: every forwarded thread should have its real conversation in Intercom — confirm counts match. If Slack > Intercom, flag "possible phantom forward or deleted conversation". If Intercom > Slack, flag "tickets not visible in Slack"
- For each conversation resolved today: one plain-language line describing the fix (input for the "Delivered today" section)

### Notion `[OPTIONAL]`
- Not queried. Linear is the source of truth.

## Privacy gate
Same as `/sprint-status`. DMs are NOT scanned for EOD review — only channel content.

## Output format

The output is a **Slack draft** in `target_channel`. **NOT a direct send.**

```
📋 *EOD Review — [fecha]*

*🟢 Entregado hoy (merged a main)*
• *[Feature/fix corto]* — [1 línea de qué es] ([repo])
• ...
(si nada se mergeó hoy: "Sin deploys hoy — día de desarrollo/review")

*🔄 Avanzado hoy (staging / branches / PRs abiertos)*
• *[Feature/fix]* — [estado: PR abierto / pushed a staging / en desarrollo]
• ...

*🐛 Incidents*
• [resumen o "Sin incidents nuevos hoy ✅"]

*📬 Requests de clientes*    [OPTIONAL section — show only if Intercom OR client channels enabled]
• [N] conversations nuevas hoy · [M] resueltas hoy · [K] abiertas pendientes
• Top nuevas (plain-language): [1-3 líneas]
• ⚠ Si hay mismatch Intercom↔Slack, flag aquí
(o "Sin requests nuevas ✅")

*🔴 Stoppers*
• [ISSUE-ID] — [razón] — [días frenado]
(o "Sin stoppers 🟢")

*🎯 Foco mañana*
• [1-3 bullets de qué sigue]
```

## Rules

### Content rules
- **Only TODAY.** Do not repeat yesterday or summarize the week — use `/sprint-status` for that.
- **Count work from THE WHOLE TEAM, not just the user.** If a teammate merged something today, it goes in. If another teammate resolved an incident, it goes in. This is a team report.
- **Staging-promote PRs** (branches that only promote staging → main) do NOT count as features — they are operational. If the real content was already reported earlier, skip.

### Tone rules (audience-aware)

The tone adapts to `target_channel.audience`:

**If `audience: "non-technical"`** (CEO, PM, CS, investors):
- **Always plain-language.** Each item answers: "what can the customer do now that they couldn't before?" or "what problem do they no longer have?"
- **NEVER mention:** PR#, ticket IDs, class/service names, branch names, internal jargon.
- Examples:
  - ❌ "Merged PR #462 fix (ProcessCvSubmissionJob): Deduplicate apply_portals candidates by email/phone"
  - ✅ "Fixed a problem where candidates arriving from InfoJobs were duplicated inside the hiring process"
  - ❌ "Fix SSRF allowlist guard in server-side fetchWithAuth"
  - ✅ "Closed a server-side security vulnerability"
- Short. Target: 10-15 lines. Max 25 lines. If the day was long, prioritize the 5 most important items and close with "plus N minor maintenance/bugfix items".

**If `audience: "technical"`** (dev-only channel):
- Can use PR#, ticket IDs, branch names, jargon.
- Still keep it concise — readers already know the context.

**If `audience: "mixed"`** (dev channel that is also read by leadership/CS):
- **Dual layer**: for each section, lead with a 1-2 line plain-language translation, then optionally follow with the technical detail underneath.
- This is the safest default when you're not sure who reads the channel.

### Delivery rules
- **Always draft, never direct send.** Applies to every channel, no exceptions. The user is the only sender from Slack.
- **Tag `@here`** at the top only if there's a blocker or a large deploy with customer impact. Don't abuse.
- **Short and scannable.** See target length per audience above.

### Reminder
- Send the report before the end of the workday while context is fresh.
- The `/daily` morning skill can remind the user to run `/eod-review` at the end of the day.

## Relationship with other skills
- **`/daily`** — morning check (what happened, what needs attention). `/eod-review` is the afternoon close (what was done).
- **`/sprint-status`** — heavy weekly audit. `/eod-review` is the micro daily report.
- **Both complement each other:** `/daily` in the morning → work all day → `/eod-review` at 18:00 → draft to team channel.
