# Daily — Morning Check-in

Scan rápido de todo lo que pasó desde el último check. Read-only, no escribe en ningún sistema. Diseñado para arrancar el día en ~2 minutos sabiendo qué pasó y qué necesita atención.

## Configuration (edit this section for your team)

Este skill es genérico. Antes de usarlo, edita la sección siguiente con los canales, personas y repositorios de tu equipo. Todo lo marcado como `[OPTIONAL]` puede desactivarse borrando la sección entera si tu equipo no usa ese sistema.

```yaml
# --- Slack channels to scan (add/remove as needed) ---
slack_channels:
  - name: "#incidents"    # id: Cxxxxxxx
  - name: "#clients"      # id: Cxxxxxxx
  - name: "#tech-guild"   # id: Cxxxxxxx

# --- Slack DMs to scan (privacy gate applies) ---
slack_dms:
  - name: "PM/CEO"        # id: Uxxxxxxx
  - name: "CS Lead"       # id: Uxxxxxxx

# --- Git repos to scan for PR/commit activity ---
git_repos:
  - ~/your-org/api-repo
  - ~/your-org/frontend-repo

# --- Team member git-email → display-name mapping ---
team_members:
  - { email: "you@company.com", name: "You" }
  - { email: "teammate@company.com", name: "Teammate" }

# --- Optional integrations (delete sections you don't use) ---
integrations:
  linear: true            # requires Linear MCP
  google_calendar: true   # requires Google Calendar MCP
  gmail: true             # requires Gmail MCP
  intercom: false         # [OPTIONAL] requires Intercom MCP — client conversations
  notion: false           # [OPTIONAL] requires Notion MCP
```

**How to customize:** open this file (`~/.claude/commands/daily.md`) and edit the YAML block above. The rest of the skill reads from it. Any section whose integration is `false` or whose MCP is not connected is skipped gracefully.

## Data sources (all read-only, all in parallel)

Launch all configured sources concurrently. Skip any section whose integration is `false` or whose MCP is not connected.

### Slack (last 24h or since last check, whichever is longer)
For each channel in `slack_channels`:
- New messages, threads without reply, threads needing your attention
- Highlight messages from team members that require action

For each DM in `slack_dms`:
- Asks pendientes, confirmations, context **work-only** (privacy gate — see Rules below)

### Git (all repos in `git_repos`)
- `git fetch origin --prune` in each repo
- PRs merged since last check (`gh pr list --state merged --search "merged:>=DATE"`)
- PRs opened/updated by anyone (`gh pr list --state open`)
- New branches pushed

### Linear (if `integrations.linear`)
- Issues updated since last check
- New issues created
- Issues moved to Done (celebrate!)
- Issues assigned to you still in Todo (nudge)

### Google Calendar (if `integrations.google_calendar`)
- Today's events with time, title, and meeting link
- Use `gcal_list_events` for the user's primary calendar, filtered to today

### Gmail (if `integrations.gmail`)
- Unread or recent emails from the last 24h that are work-relevant
- Use `gmail_search_messages` with query like `is:unread newer_than:1d`
- Focus on: emails from clients, from team members, from external services
- Skip: newsletters, marketing, automated non-actionable notifications
- For each relevant email: sender, subject, 1-line summary of what it needs

### Intercom `[OPTIONAL]` (if `integrations.intercom`)
- When a team uses Intercom, it's typically the canonical source for client conversations; internal Slack channels are usually just a mirror of notifications.
- Last 24h conversations needing attention:
  - Open + unread
  - Priority flagged
  - Conversations with a new customer reply pending a response
- Tool: `mcp__intercom__search_conversations` with filter `updated_at` last 24h + `state=open`
- For each relevant conversation: contact name, company, last message, state, 1-line summary
- **Cross-ref with Slack:** if a conversation also appears forwarded into a Slack client channel, link both (Slack permalink + Intercom URL)

### Notion `[OPTIONAL]` (if `integrations.notion`)
- Skim relevant pages/databases the team uses as a read-only reference (roadmap, backlog, specs)
- Never write from `/daily`

## Privacy gate
DMs pass through a work-vs-personal classifier. Personal content is dropped silently — never logged, quoted, or mentioned. Only work-relevant asks surface.

## Output format

```
## Buenos días — [fecha] [día de la semana]

### 📅 Agenda de hoy
- HH:MM — [título] ([link])
- (sin reuniones hoy ✨)

### 📧 Emails relevantes (últimas 24h)
- [sender] — [subject] — [acción necesaria o "solo FYI"]
- (sin emails relevantes pendientes ✨)

### 📬 Intercom — conversations activas   [OPTIONAL section, omit if disabled]
- [contact — company] — [state] — [acción sugerida o "solo monitoreo"]
- Cross-ref Slack: [permalink if applicable]
- (sin conversations que requieran atención ✨)

### 🆕 Qué pasó mientras no estabas
Bullets cortos por canal/fuente, solo lo que requiere tu atención:
- [#channel-1]: [resumen o "sin nuevos"]
- [#channel-2]: [resumen o "sin nuevos"]
- DM [person]: [resumen work-only o "sin novedades"]
- Git: [N PRs merged, N PRs opened, branches nuevas relevantes]
- Linear: [N issues movidas, N nuevas]

### 🔔 Necesita tu respuesta/acción
Lista priorizada de threads, PRs, asks que esperan algo de ti:
1. [canal/fuente] — [qué] — [acción sugerida]
2. ...
(si no hay nada: "Inbox limpio 🟢")

### 🔴 Stoppers activos
- [ISSUE-ID] — razón — días frenado
(si no hay: "Sin stoppers 🟢")

### 🎯 Foco sugerido para hoy
Top 3 acciones de mayor leverage basadas en lo detectado arriba.
1. [acción concreta]
2. [acción concreta]
3. [acción concreta]
```

## Phase 2 — Sync systems (after showing the briefing)

After presenting the morning briefing to the user, propose system updates detected during the scan. Wait for user confirmation before executing.

### What to detect and propose:

**Linear updates** (if enabled):
- Issues that should move to Done based on git evidence (PR merged to main but Linear still says In Progress/In Review)
- New items detected in Slack channels without a Linear issue yet → propose CREATE
- Issues with stale status (no git activity in 7+ days but still marked In Progress) → flag for user
- Assignee mismatches (git author ≠ Linear assignee) → propose UPDATE_ASSIGNEE

**Notion updates** `[OPTIONAL]` (if enabled, existing pages only):
- Pages whose status is stale vs the reconciled state (e.g. Notion says "In Progress" but Linear/git says Done) → propose update

**Slack drafts (ALWAYS draft, never direct send — applies to every channel and DM):**
- For every thread where a reply is warranted, produce a `slack_send_message_draft`
- No exceptions, not even for internal channels or teammate DMs
- The user is the only sender — they review the draft in Slack and send manually
- Apply tone rules when relevant (non-technical language for client-facing threads)

**Intercom proposals** `[OPTIONAL]` (if enabled, read + write):
- Incidents detected in Slack without an associated Intercom conversation (reported by identifiable customer) → propose `CREATE_INTERCOM_NOTE` on the matching conversation, or flag as "internal incident, no customer link"
- Forwarded client requests → propose `ADD_INTERCOM_NOTE` on the original conversation with the technical context detected, so the CS lead sees it inside Intercom
- When an issue is resolved and the customer needs to be notified → propose a **note draft** in the Intercom conversation, **never a direct reply to the customer**
- **NEVER auto-send in Intercom.** All writes wait for explicit confirmation (`apply 1,3` / `apply all` / `skip`)

### Execution:
- Print the proposed updates as a numbered list
- Wait for: `apply all`, `apply 1,3,5`, or `skip`
- If the user says nothing about syncing, skip — don't block the morning

## Rules
- **Phase 1 (briefing) is read-only.** The briefing output itself never writes to any system.
- **Phase 2 (sync) proposes writes** but waits for explicit confirmation before executing.
- **NEVER direct-send to Slack.** Every Slack message — any channel, any DM, any audience — goes as `slack_send_message_draft`. Zero exceptions. The user is the only sender.
- **Intercom writes allowed but gated.** Notes are proposed in Phase 2 and wait for confirmation. Never reply directly to a customer.
- **Fast.** Parallelize everything. Output must be short and scannable.
- **If a source has no news, say "sin novedades" and move on.** Don't pad with filler text.
- **Privacy gate applies** same as `/sprint-status`.
- **Tone:** internal, for the user only. Can use IDs and jargon. Not meant for sharing.
- **If an EOD review is pending from yesterday**, mention it in the suggested focus.

## Relationship with other skills
- **`/sprint-status`** — heavy weekly audit with Linear writes. `/daily` is the lightweight daily check that writes nothing.
- **`/eod-review`** — end-of-day report. `/daily` is the morning input; `/eod-review` is the afternoon output.
