# Sprint Status — Consolidate everything into Linear + generate review outputs

The heaviest command. Ingests **Linear + Git across all configured repos + Slack (channels + DMs)** — plus optional Notion and Intercom if your team uses them — deduplicates, and **writes the consolidated state back into Linear** (creating missing issues, updating statuses, reassigning based on git authorship). Then produces three separate outputs.

**Linear is the single source of truth.** Git, Slack, Notion, and Intercom are inputs that feed Linear. When Notion is configured, it is a historical view only — this command NEVER creates cards in Notion, only reads from it and (optionally) updates state of existing cards that are desynced.

## Configuration (edit this section for your team)

Before using this skill, edit the YAML block below with your team's repos, channels, Linear setup, and integrations. Sections marked `[OPTIONAL]` can be deleted if your team does not use that system. Replace every `Cxxxxxxx` / `Uxxxxxxx` / `xxxxx-xxxx` placeholder with real IDs from your workspace.

```yaml
# --- Linear workspace ---
linear:
  team_name: "YourTeam"
  team_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  team_key: "TEAM"         # Used as issue prefix (e.g. TEAM-123)
  primary_user_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  primary_user_email: "you@company.com"

# --- Team member mapping (git email ≠ Linear email is common) ---
team_members:
  - git_email: "you@company.com"
    name: "You"
    linear_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  - git_email: "teammate@company.com"
    name: "Teammate"
    linear_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  - git_email: "nondev@company.com"
    name: "PM"
    linear_id: null         # Never in Linear — never assign

# --- Git repos to scan ---
git_repos:
  - ~/your-org/api-repo
  - ~/your-org/frontend-repo

# --- Slack channels ---
slack_channels:
  - { name: "#clients",    id: "Cxxxxxxx" }
  - { name: "#tech-guild", id: "Cxxxxxxx" }
  - { name: "#incidents",  id: "Cxxxxxxx" }

# --- Slack DMs (privacy gate applies) ---
slack_dms:
  - { name: "PM/CEO", id: "Uxxxxxxx" }
  - { name: "CS Lead", id: "Uxxxxxxx" }

# --- Optional integrations ---
integrations:
  notion: false           # [OPTIONAL] Sprints/Backlog DBs
  intercom: false         # [OPTIONAL] Client conversations

notion:                   # Only read if integrations.notion = true
  sprints_db_id: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  backlog_db_id: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## When to use

- Weekly sprint review where you need one reconciled view across all channels
- When Linear, git, and team conversations have drifted and you want one consolidated state
- Before talking to your PM/CEO/CS team about delivery status
- After a messy sprint to clean up the tracking state

## Core design principles

- **Linear = single source of truth.** Everything else is an input.
- **Early-stage disorder is expected.** The job of this command is to resolve it, not to complain about it.
- **1 PR → 1 or more cards. Every PR must be covered by at least one card.** The default is 1-to-1, but a single PR that actually contains several distinct features/fixes SHOULD produce multiple cards — one per logical unit of work. Sometimes even a single large commit inside a PR warrants its own card. The rule is about fidelity to the real work done, not about matching PR count. A week with 40 merged PRs typically produces **40 or more** cards, never fewer. The ratio `cards / PRs` must be `>= 1.0` as a floor (below 1 = you're hiding work by bundling). There is no upper bound.
- **Dedup conservatively.** A false negative (two Linear issues for one thing) is easy to merge later. A false positive loses information. When in doubt, keep separate and flag for human review.
- **Privacy gate on DMs.** Messages from configured `slack_dms` pass through a work-vs-personal classifier. Personal content is dropped entirely — never logged, never quoted, never added to Linear, never mentioned in outputs.
- **Shared-system writes are gated.** Creating/updating Linear issues affects the team. First run defaults to `--dry-run`: print the proposed diff and wait for explicit confirmation.
- **NEVER post directly to ANY Slack channel or DM.** Every message — `#clients`, `#incidents`, `#tech-guild`, any DM, any audience — goes via `slack_send_message_draft`. The user reviews in Slack and sends manually. Zero exceptions.
- **Intercom writes (notes, replies) are also gated** when the integration is enabled. They are proposed in the Phase 5 diff and wait for explicit confirmation, same as Linear writes. Never auto-reply to customers.

## Inputs / flags

- `--dry-run` — ingest, dedup, reconcile, print the proposed Linear diff. **Do NOT write to Linear.** Use for first pass or whenever unsure.
- `--yes` — skip the confirmation gate and execute writes immediately. Only after several successful dry-runs.
- `--sprint N[,M]` — target specific sprint numbers. Default: active sprints.
- `--window DAYS` — commit/Slack lookback window. Default: `14`.
- `--since ISO` — alternative to `--window`, explicit start date.
- `--backfill` — include the retroactive backfill phase (Phase 3b below). Off by default; on for first-ever runs or when the user explicitly asks for "catch up Linear with everything I've done".

**Default behavior (no flags):** ingest → dedup → reconcile → print Linear diff → wait for confirmation → execute writes → emit three outputs.

## Data sources

### Linear
- Active cycle for the team
- ALL issues touched in the window, not just ones assigned to the user
- Linear = destination of writes, not just source to read
- Use `linear.team_id` / `linear.team_key` from configuration above

**Team member mapping** (critical — git email ≠ Linear email is common): use the `team_members` block from configuration. Cache the map across runs. Refresh only if `list_users` returns new members.

**Linear label constraints** (learned the hard way):
- Labels live in **groups** (e.g. "Repo", "Type", "Area"). Within a group, **only ONE label per issue is allowed**. Trying to set two labels from the same group fails with `LabelIds not exclusive child labels`.
- When a feature touches multiple repos: pick the **most representative** repo label (usually where the primary logic lives) and mention the others in the description.
- Type-group conflicts are common (`task` + `maintenance`, `task` + `Improvement`). Pick one.
- Before creating issues in bulk, fetch `list_issue_labels` once and cache the label → group mapping to avoid failed requests.

### Git (local repos)
For each path in `git_repos`:
- `git fetch origin --prune`
- Capture main, staging, and feature branches
- Critically: capture author email for each commit (for the team member mapping above)

### Slack
For each channel in `slack_channels`:
- Read messages in the window

For each DM in `slack_dms`:
- Read messages in the window with the privacy gate applied

### Notion `[OPTIONAL]` (if `integrations.notion`)
- Sprints DB + Backlog DB from `notion.sprints_db_id` / `notion.backlog_db_id`
- **Read-only.** Always `notion-fetch` the DB first to discover property names. Do NOT hardcode property keys.
- **Warning:** querying a full Sprints DB view may return 250KB+ and blow the context. If that happens, skip Notion as primary source and rely on Linear (which already has the sprint info in issue descriptions). Fetch individual Notion pages by ID only when cross-referencing a specific card.
- **Notion write policy:** **NO creating new cards in Notion from this command.** The only allowed Notion writes are `update_properties` on existing pages whose status in Notion is clearly stale compared to the reconciled state. Even those updates are proposed in the diff and wait for confirmation.

### Intercom `[OPTIONAL]` (if `integrations.intercom`)
- When a team uses Intercom, it's typically the canonical source for client conversations; Slack client channels are usually a mirror.
- `mcp__intercom__search_conversations` filtered by the configured window (default 14 days)
- `mcp__intercom__get_conversation` to fetch the full transcript of any conversation referenced from a Slack channel, a PR, or a Linear issue
- `mcp__intercom__get_contact` + `mcp__intercom__get_company` to enrich with customer name and company when the Slack forward only has an email
- **Read + write**: the MCP supports notes/replies. Writes are proposed in the Phase 5 diff and wait for explicit confirmation alongside Linear writes. **Never auto-reply to a customer.** Only internal notes for the CS lead.

## Phases

### Phase 1 — Ingest (parallel, read-only)

Launch concurrently (fully independent):

1. **Linear** — `list_cycles` current + `list_issues` updated in window + `list_users` for mapping + `list_issue_labels` for constraint map.
2. **Git across all repos** — fetch + main/staging/branches + `gh pr list --author "@me" --state merged --search "merged:>=DATE"` for the full merge log in the window.
3. **Slack** — read each channel + each DM with the privacy gate applied.
4. **Notion** `[OPTIONAL]` — fetch schemas, query backlog top 50, skip sprints DB query if it blows context.
5. **Intercom** `[OPTIONAL]` — `search_conversations` in the full window. Cache conversation IDs for cross-ref in Phase 1.5.

### Phase 1.5 — Intercom cross-ref `[OPTIONAL]` (only if `integrations.intercom`)

For each thread in Slack client channels that is Intercom-forwarded (identifiable by an Intercom bot author or pattern like "New conversation from [client]"), fetch the full conversation from Intercom with `mcp__intercom__get_conversation` and enrich the canonical item with:

- Contact name, company, email (`get_contact` + `get_company` if needed)
- Full transcript summary (not just the snippet of the forward)
- Current Intercom state (open / snoozed / closed)
- Direct URL to the conversation in Intercom

**Why:** drafts posted to client channels later (Phase 8) need to reflect the real customer context, not just the first line of the forward. It also allows detecting mismatches: forward exists in Slack but conversation is closed in Intercom → flag.

**Calibration:** if the client channel has N Intercom-forwarded threads in the window and `search_conversations` returns fewer matchable conversations, flag "possible Slack↔Intercom mismatch" in the output.

### Phase 2 — Privacy gate (DMs only)

For every message from configured DMs, classify as `work` or `personal`.

**Signals FOR work:** client names, product features, ticket IDs, PR URLs, repo names, technical terms, explicit asks with business context, deliverables, meetings, roadmap, deadlines.

**Signals AGAINST work:** family, relationships, health, personal finance, weekend plans, hobbies, memes, casual banter, venting unrelated to work items, politics, social-only content.

**Ambiguous → DROP.** Treat as personal.

**Hard rules:**
- Personal content NEVER appears in any output, ever.
- No counts, no dates of filtered messages. No metadata that could reverse-engineer dropped content.
- Only one generic line allowed in Output 3: "Personal chats with configured DMs: processed through privacy filter; work-only content included below."

### Phase 3 — Deduplicate and build canonical items

Build canonical work items. Matching signals in order of confidence:

1. **Explicit ticket ID** in any source → that's the canonical ID.
2. **Shared PR URL or branch name** → same item.
3. **Same Notion page ID** → collapse Notion duplicates.
4. **Title similarity >80%** + same client/feature anchor → merge.
5. **Client-specific anchor** (same client name + same incident type within 48h) → consider merging.

**Never merge when:**
- Two items have different explicit ticket IDs.
- Two items have the same title but different clients.
- Two items touch different repos AND have no shared reference.

**1 PR → 1 or more cards. Every PR must be covered by at least one card.** The default is 1-to-1, but PRs that contain multiple distinct features/fixes should be split into multiple cards, one per logical unit. Even individual commits inside a fat PR can warrant their own card when they represent independent work. A bug fix + a feature in the same PR are ALWAYS separate cards. The rule: **every piece of logical work becomes visible as a card**. Never hide work by bundling heroically under a single umbrella card.

The only cross-PR bundling allowed is when 2-4 PRs form literally ONE logical feature across repos (e.g. API endpoint + frontend page + propagation-service = 1 card like "Multi-tenant iframe filter"). This is the rare exception, not the default.

### Phase 3b — Backfill retroactive (only if `--backfill` flag)

For every merged PR in the window that has NO Linear issue linked and is NOT covered by any canonical item from Phase 3:

- Create one `bf-NN` canonical item per PR.
- Group ONLY when a cross-repo set of PRs was clearly one feature (same branch name pattern, same day, same subject stem).
- State: `Done` (merged to main) or `In Review` (merged to staging only).
- Assignee: the git author mapped via the team member mapping.
- Cycle: current cycle if merge date ≥ cycle start, else no cycle.
- Description should include: PR number(s), merge date, branch name, one-paragraph summary of what the PR did, related tickets if any, cluster this fix belongs to.
- **Calibration check:** if the user has N merged PRs in the window and the backfill produces < N × 0.7 cards, something is wrong — you're over-bundling. Expand.

### Phase 4 — Reconcile state and authorship

**State resolution** (priority: git > Linear > Notion > Slack):

1. PR merged to `main` → `Done`
2. PR merged to `staging` → `In Review` + label `pending-prod`
3. PR open → `In Review`
4. Branch has commits in window → `In Progress`
5. Linear says `In Progress` / `In Review` → keep
6. Notion says `Done` but no git evidence → flag `Desalineado`, keep latest of {Linear, Notion}
7. Else → `Todo`

**Blockers:**
- Explicit "blocked" / "blocker" / "stuck" / "waiting" in Notion, Linear comments, Slack
- Implicit: no commits in 7+ days on a branch marked In Progress + PR with CI failing
- Stale PRs (>7 days without update), merge conflicts

**Assignee resolution:**
- Git author of the most recent commit on the item's branch
- Map via `team_members` (git email → Linear user)
- If author not in Linear → unassigned + mention in description
- Multiple authors → primary = most recent commit, others as collaborators in description

### Phase 5 — Compute Linear diff

Per canonical item, compute the operation:

- **CREATE** — no ticket ID. Build draft:
  - `title`: best from sources
  - `description`: markdown with what, sources (Notion link, PR URL, Slack permalinks), client name, rationale for inferred state
  - `state`: inferred state
  - `assignee`: inferred assignee (mapped via team map)
  - `labels`: **one per group max**, derived from repo/type/area. Mention cross-repo context in description.
  - `cycle`: current if within cycle dates
  - `priority`: inherit from Notion/Linear if set

- **UPDATE_STATE** — existing Linear issue with different reconciled state
- **UPDATE_ASSIGNEE** — different reconciled assignee
- **ADD_COMMENT** — new Slack/git context not captured yet
- **ADD_LABEL** — missing labels (respecting group constraint)
- **NOTION_UPDATE** `[OPTIONAL]` — existing Notion card with stale status vs reconciled (rare, use sparingly)
- **NO_CHANGE** — everything aligned

Each operation records a one-line `reason` for the confirmation step.

### Phase 6 — Confirmation gate

Print the diff as a human-readable plan, then:
- `--dry-run` → STOP, emit outputs without writing.
- `--yes` → proceed without asking.
- Default → wait for user:
  - `apply all`
  - `apply 1,3,5-8`
  - `apply core` — preset of high-leverage ops (user decides scope per run)
  - `cancel`
  - `show N` — expand operation N before deciding

### Phase 7 — Execute Linear writes

Execute sequentially (MCP rate limits). Continue on individual failures, report all at the end.

**Label failure retry:** if an operation fails with `LabelIds not exclusive child labels`, auto-drop the lower-priority label from the conflicting group and retry once. Log both labels in the description.

Summary format:
```
## Linear — changes applied
✓ Created: N (with URLs and IDs)
✓ Updated: N
✓ Commented: N
✗ Failed: N (with reason for each)
```

Rollback hint: list created IDs so they can be deleted manually if needed.

### Phase 8 — Slack message drafts + Intercom notes (ALL drafts, zero direct sends)

**Zero direct sends rule:** every message produced by this phase — regardless of channel or audience — is created via `slack_send_message_draft`. No exception for internal channels, no exception for teammate DMs. The user is the only sender.

For each Slack thread or DM that needs a response based on the reconciled state, produce a **draft** via `slack_send_message_draft` (NOT a direct post). The user reviews in Slack and sends.

**Tone rules for draft content:**
- **When the audience is non-technical** (recruiters, CS, business): write in simple, warm, direct language. **NEVER mention PR numbers, ticket IDs, class names, controller names, branch names, or technical jargon.** Instead: "fixed", "already in production", "the problem was X".
- **If something doesn't exist in the product, the answer is "we don't have it". Period.** NEVER offer to develop it. Do not say "we could plan it", "if you want we'll build it", "we'll propose it as an improvement". That creates false expectations and inflates scope.
- **Offering solutions requires pre-approval** from the user, EXCEPT when it's a quick-win: small change, doesn't break anything, reversible, clear. Quick-wins can be offered as "quick fix". Everything else: draft a response that just acknowledges and states the current state.
- **For status updates on fixed bugs:** confirm the fix in plain language. Do not cite PR or tech details. "Fixed, already in production. Let me know if it happens again."
- **For "can we add X?" questions:** if X exists → say so. If X doesn't exist → "we currently don't have this". Do NOT add "but it could be developed".
- **When the audience is technical** (dev-only channels): jargon, PR numbers, ticket IDs, branch names are all fine.

**Draft targets (when relevant):**
- Threads in incident channels that need status confirmation → draft as reply in the incident thread (`thread_ts` = parent message). Audience: your CS/PM leads plus the rest of the team reading the channel. Tone: internal, concise.
- Threads in client channels where a conversation was forwarded from Intercom (or any external source) → **draft as reply in that thread tagging the CS lead** so they get notified. **Critical understanding:** internal client channels are NOT visible to customers — they are a notification mirror. The CS lead is the one who reads them and responds to the customer directly from the original tool (Intercom, Zendesk, etc.). So the draft is NOT a customer-facing message — it's an internal note with the technical context + optionally a suggested customer-facing phrasing that CS can copy-edit. Always tag the CS lead.
- DM the PM/CEO → internal coordination asks that are NOT about a specific customer. **Also draft.**
- Dev channels (tech-guild, status updates) → **also draft**, never direct send.

**Never draft on behalf of the user:**
- Anything to a customer directly (Intercom/Zendesk conversations) — propose as **internal note for CS**, not as reply
- Financial/legal/compliance decisions
- Anything requiring the user's explicit judgment call

**Intercom drafts** `[OPTIONAL]`:
- When a canonical item resolves a client issue tracked in Intercom, propose an internal `note` in the conversation so CS can see it and, if appropriate, use it as base for the customer reply. **Never a direct reply to the customer.**
- Writes to Intercom (`create note`, `update conversation`) execute only after explicit confirmation from the user, same as Linear writes.
- If the Intercom conversation is already `closed` and the fix is newer, propose `reopen` + note. Wait for confirmation.

**There are NO internal channels exempt from the draft rule.** Every Slack message — tech-guild, DM to a teammate, anything — goes via `slack_send_message_draft`. The user reviews and sends from Slack.

### Phase 9 — Three outputs

---

## OUTPUT 1 — Linear consolidated (summary)

```
# Linear — Sprint [N+M] consolidated — [date]

## By state (post-apply)
- Done (in prod): N
- In Review (staging pending prod): N
- In Review (PR open): N
- In Progress: N
- Todo: N
- Blocked: N

## By assignee
- @user1: N
- @user2: N
- unassigned: N (details)

## By repo
- repo-1: N | repo-2: N | repo-3: N | ...

## Active stoppers (detail in Output 3)
- TICKET-ID — short reason

## Issues created in this run
- TICKET-ID Title — source (Slack / backfill / Notion / new)
```

---

## OUTPUT 2 — Review for PM + CS (copy-paste ready, work-only)

Warm, professional language. 250-450 words. Zero jargon. Zero PR#. Zero ticket IDs. Zero personal content.

**Dual-audience note:** when the target channel is mixed (devs + non-devs), the report must be accessible to non-technical readers but with enough technical signal for devs. **By default**, apply a "topic-level translation" rule: each technical section leads with a 1-2 line plain-language sentence ("what this means for the customer") followed by the technical detail. If the channel is purely non-technical, omit the technical detail entirely. If the channel is purely technical, the opposite. Safe default: dual layer per section.

```
# Sprint [N+M] — review [week DD/MM to DD/MM]

Hi 👋 Consolidated status update.

## 🟢 Delivered to customers (in production)
3-7 bullets per feature or client, connecting to business value.

## 🚢 Ready, waiting for prod deploy
What is already in pre-prod (staging). Include ETA if known.

## 🔄 In progress (focus of the week)
Top 5 in flight, who leads, % estimate if applicable.

## 🔴 Stoppers and risks
Only what impacts delivery: reason, owner, help needed.

## 📬 Pending from CS / customers not yet queued
Detected requests not yet in the queue, with suggested priority.

## 📊 Numbers
- Delivered: N | In staging: N | In progress: N | Stoppers: N

## 🎯 Focus next week
2-3 sentences prioritizing what's next and why.

Comments, priority adjustments? 🙏
```

**Format rules for Output 2:**
- Warm but professional.
- No unnecessary technical language. "PR merged" NO; "delivered" YES.
- Zero internal jargon. "merged to main" NO; "in production" YES.
- Don't mention IDs unless CS already uses them.
- 250-450 words. Scrollable.
- Always close with an open question inviting a reply.

---

## OUTPUT 3 — Personal list for the user (brutal and direct)

```
# Your personal focus — [date]

## ✅ Closed since the last run
Short list of what was unblocked.

## 🛑 Stoppers (what's blocking you TODAY)
- **[TICKET-ID] Title** — blocked for N days. Reason: X. Unblock: 1 concrete action.

## ⏳ Your specific pending items
Things assigned to you with detected friction.

## 🔔 Need your response (Slack work-only)
- #channel [date] — [work-only summary] — suggestion: [action]
- DM [person] [date] — [work-only ask] — suggestion: [action]

Personal chats with configured DMs: processed through privacy filter; work-only content included above.

## 🎯 Top 3 highest-leverage actions
1. [action, 1 line]
2. [action, 1 line]
3. [action, 1 line]

## 📝 Useful detected context
PRs from others waiting for your review, tech-guild decisions affecting you, unowned incidents, etc.
```

**Format rules for Output 3:**
- Direct, no filler.
- Specific actions with concrete verbs ("merge PR #123", not "handle PRs").
- If no stoppers → "No active stoppers. Clean focus 🟢".
- Zero personal content. Privacy gate applies.
- **This output CAN use PR# and ticket IDs** — it's only for the user.

---

## Notes — critical rules (consolidated)

### DM privacy (Javi + Samu style configured DMs)
- Conservative filter: doubt → personal → discarded.
- Personal content NEVER appears, not even as a count or metadata.
- One generic line allowed in Output 3; nothing else.

### Dedup
- Prefer false negatives (2 issues for the same thing) over false positives.
- Conservative match by client + feature anchor.
- Doubt → keep separate and flag.

### Backfill granularity
- **1 PR → 1 or more cards.** Every PR must be covered by at least 1 card.
- Default 1-to-1, but if a PR contains several distinct features/fixes, split into multiple cards (even 1 per commit if applicable).
- Cross-PR bundling (2-4 PRs in 1 card) is the **rare exception**, only when they literally form one cross-repo feature.
- **Floor:** `cards / PRs >= 1.0`. Below = over-bundling, expand.
- **No upper bound:** 40 PRs can absolutely produce 55 cards if several PRs contain multiple fixes.

### Linear writes
- Default dry-run. Explicit confirmation by index allowed.
- `--yes` only after several OK runs.
- Label group constraint: 1 per group. Fetch labels first.
- If CREATE fails mid-stream, continue and report at the end.
- Rollback hint with created IDs.

### Notion `[OPTIONAL]`
- **Read-only + state updates on existing cards when they are desynced.**
- NO creating new cards from this command.
- Linear is the only source of truth.

### Slack messaging (CRITICAL)
- **ALL channels and DMs: ALWAYS draft, never direct send.** Zero exceptions. The user is the only sender.
- **Non-technical tone for CS/external audiences:** zero PR#, zero ticket IDs, zero class/controller names, zero jargon.
- **Don't offer development:** if something doesn't exist → "we don't have it", period. NO "we could develop it".
- **Quick wins** can be offered if they're small, reversible, don't break anything.
- **Internal dev channels and teammate DMs:** also draft. The difference with CS is just the tone (jargon OK for devs), not the send mechanism.
- **Intercom** `[OPTIONAL]`: never direct reply to customer. Only internal notes as drafts for CS.
- **Thread targeting (IMPORTANT):** drafts go as replies IN THE THREAD where the question/notification originally appeared, NOT as a separate DM. If a client forward landed in #clients, the draft goes in that thread (`thread_ts` = parent). If it was an incident in #incidents, the draft goes in the incident thread. Only use the CS DM for internal coordination that is NOT about a specific customer. This avoids scattering conversations and keeps context visible to the team.
- **Client channels are INTERNAL; customers do not read them.** They are a mirror where forwarded customer conversations appear as notifications. CS reads them and replies to the customer from the original tool. So when drafting a reply in a client channel: (1) it is NOT a customer-facing message, it's an internal note for CS; (2) **always tag the CS lead** so they get notified; (3) content: internal technical context + optionally a suggested customer-facing phrasing in italics that CS can copy-edit. Never write as if the customer would read it directly.

### Parallelization
- Phase 1 embarrassingly parallel.
- If > 40 canonical items → parallelize Phase 4/5 with subagents (1 per bucket).

### Offline sources
- Don't abort: degrade and report in `⚠ Sources unavailable` at the top of each output.
- Never fabricate data.

### Language
- Output language matches the user's `settings.json` language (default Spanish).
- Outputs 2 and 3 more conversational. Output 1 more structured.

### Safety
- This command does NOT touch git, does NOT make commits, does NOT push.
- Only writes to Linear (via MCP) and generates Slack drafts (+ optional Intercom notes).
- If there's doubt about anything destructive → STOP and ask.

### Sprint disorder
- Without arguments, pull active sprints (may be more than one).
- Do not attempt to "fix" Notion disorder by merging sprints; only consolidate in Linear.

### Retro calibration
- At the end of each run, report: "Processed X PRs, created Y cards, updated Z, Notion touched W". If Y/X < 0.7 and it's not a backfill run, warn about over-grouping.
