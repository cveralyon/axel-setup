# Sprint Status — full cross-system audit

The heaviest audit command. Cross-references **Notion sprint board + Notion backlog + Linear cycle + Git (main/staging across all Mainder repos) + Slack conversations** to produce a single reconciled status report.

Use this when you want one source of truth: "what's actually done, what's actually in flight, what's actually blocked, and what's slipping through the cracks."

## When to use

- Weekly sprint review with the team
- Before talking to Samu about delivery status
- When Notion/Linear/git feel out of sync and you need to reconcile
- After a sprint cut to verify everything shipped

## Inputs

- **Argument (optional):** sprint number(s). Default: active sprints (currently **31 + 32** — these are mixed due to a known reordering; when no argument is passed, fetch both).
- **Window (optional):** commit lookback window. Default: `14 days`.
- **Include Samuel DMs?** Default: no. Pass `--with-samu` to include.

## Data Sources

### Notion
- **Sprints DB:** `11c99e746b748141a921f086e452646d`
  URL: https://www.notion.so/11c99e746b748141a921f086e452646d?v=11c99e746b748112b9b8000c781c9c03
- **Backlog DB:** `11c99e746b7481ecbeb4de6fcac61b88`
  URL: https://www.notion.so/11c99e746b7481ecbeb4de6fcac61b88?v=11c99e746b74818e9ed3000c77c7851c

Always fetch the DB structure first (`notion-fetch` on the DB ID) to discover the actual property names — schemas drift. Do NOT hardcode property names like "Status" or "Sprint".

### Linear
- Active cycle for the team Cristián belongs to.
- Issues assigned to `cristian.vera@mainder.ai` (and unassigned issues flagged as belonging to the current sprint).
- Treat Linear as the **authoritative state** for individual issue status when there's a conflict with Notion (Notion is used as the delivery plan; Linear is used as the execution ledger).

### Git (local Mainder repos)
- `~/Mainder/Mainder-API` (Rails 8)
- `~/Mainder/SKYLINE-V9` (Next.js 15)
- `~/Mainder/MultipostingService` (Rails)
- `~/Mainder/AIAgentService` (Python/FastAPI)
- `~/Mainder/Career-Site`
- `~/Mainder/back-office`

For each repo: `git fetch origin --prune` then capture main, staging, and recent feature branches. Resolve PR numbers via `gh` when possible.

### Slack
- `#clients` — client requests and issues
- `#tech-guild` — internal tech discussions and decisions
- `#incidents` — active incidents
- **DM Javiera** — always (product/PM context)
- **DM Samuel** — only with `--with-samu` flag (founder/CEO context, be intentional)

## Steps

### Phase 1 — Ingest (parallelize aggressively)

Launch these in parallel as independent lookups; none depends on the others:

1. **Notion Sprints DB fetch**
   - Get DB schema.
   - Query tasks where sprint = 31 OR 32 (or passed argument). Collect: title, status, assignee, priority, due date, linked PR / Linear ID (from property or description), estimate.

2. **Notion Backlog DB fetch**
   - Get DB schema.
   - Query the top N prioritized items (limit 50). We need this only to detect items that Slack references but aren't in the current sprint — i.e. "slipped to backlog" vs "never tracked".

3. **Linear cycle fetch**
   - List current cycle's issues for the team.
   - Fetch my assigned issues and their states.

4. **Git fetch across all Mainder repos**
   - For each repo that exists locally: `git fetch origin --prune` in parallel.
   - Capture:
     - `git log --first-parent origin/main --since="14 days ago"` commits (SHA, date, author, subject)
     - `git log --first-parent origin/staging --since="14 days ago"` commits
     - `git log origin/main..origin/staging --first-parent` (pending prod)
     - `git log origin/staging..origin/main --first-parent` (divergence)
     - Remote feature branches touched in the window
   - Resolve PRs via `gh pr list --state all --search "author:@me updated:>14-days-ago"` when available.

5. **Slack channel scan**
   - For each channel in {clients, tech-guild, incidents}:
     - `slack_read_channel` last 100 messages or last 14 days, whichever is larger
     - Filter: messages mentioning Cristián, requests (interrogative or imperative), unresolved threads (no reaction from team + no reply), references to Linear IDs or PR numbers.
   - DM Javiera: same filter with looser threshold (anything unanswered from her side is relevant).
   - DM Samuel: only if `--with-samu`.

### Phase 2 — Reconcile

For every sprint task (from Notion), compute a **reconciled state** by combining:

1. **Notion state** — declared plan
2. **Linear state** — execution ledger (authoritative for individual issue status)
3. **Git state** — ground truth for code (local branch? pushed? PR open? merged to staging? merged to main?)
4. **Slack signal** — is there active discussion or a block mentioned?

Also, for every Slack request/incident detected, try to map it to:
- A current sprint task (same Linear ID, PR number, or keyword match on title)
- A backlog item (same check against backlog DB)
- Nothing → "untracked request"

### Phase 3 — Classify

Place every item in exactly one of these buckets. Items can be flagged across multiple buckets only under "Desalineados".

- 🟢 **Done + en prod** — Notion done, Linear done, PR merged to main
- 🟡 **Done + en staging, pendiente prod** — PR merged to staging, not yet in main
- 🔵 **Done + no deployado** — PR merged or code ready, not in any deploy branch yet
- 🔄 **En progreso** — branch pushed, commits recent, PR open or not
- ⏳ **Pendiente (no empezado)** — Notion todo, no branch, no commits
- 🔴 **Bloqueado** — explicit blocker in Notion, Linear, or Slack
- ❓ **Desalineado** — the systems disagree (Notion done but no PR, Linear done but not in Notion sprint, PR merged but Notion still todo, etc.)
- 💬 **Slack sin tracking** — request or incident in Slack that doesn't map to any sprint or backlog item
- 📋 **Slipped al backlog** — was in sprint, now in backlog DB (de-prioritized)

## Output Format

```
# Sprint Status — Sprint [31 + 32] — [fecha]

Generated from: Notion (sprints + backlog) · Linear · 6 Mainder repos · Slack (clients, tech-guild, incidents, DM Javiera)

---

## 🟢 Done + en prod ([N])
- **[LIN-XXX]** Título — `owner/repo#NNN` mergeado a main [fecha]
  - Notion: Done ✓ | Linear: Done ✓ | main: ✓ | staging: ✓
  - Impact: 1 línea

## 🟡 Done + en staging, pendiente prod ([N])
**Candidatos para el próximo cut-release.**
- **[LIN-XXX]** Título — `owner/repo#NNN`
  - En staging desde [fecha], sin aparecer en main
  - Riesgo / dependencias / feature flag?

## 🔵 Done + sin deploy ([N])
- **[LIN-XXX]** Título — PR mergeado a una feature branch o aún no abierto
  - Acción recomendada: abrir PR a staging

## 🔄 En progreso ([N])
- **[LIN-XXX]** Título — branch `feat/xxx` (repo), último commit [fecha]
  - Último avance: [subject del commit]
  - Remaining (inferido): 1 línea

## ⏳ Pendiente ([N])
- **[LIN-XXX]** Título — asignado a [quién], prioridad [P], due [fecha]

## 🔴 Bloqueado ([N])
- **[LIN-XXX]** Título — bloqueador: [motivo], fuente: [Notion|Linear|Slack #channel ts]
  - Acción sugerida: 1 línea

## ❓ Desalineados ([N]) — requieren atención humana
- **[LIN-XXX]** Título
  - Notion: Done | Linear: In Progress | git: sin PR mergeado
  - Hipótesis: 1 línea. Acción: 1 línea.

## 💬 Slack sin tracking ([N])
Requests o incidentes activos en Slack que NO están en Notion ni Linear.
- `#clients` [ts] @quien — resumen — sugerencia: crear issue en [team] o responder
- `#incidents` [ts] — incidente abierto, sin ticket
- DM Javiera — ask pendiente: [resumen]

## 📋 Slipped al backlog ([N])
Estaban en un sprint anterior y se movieron al backlog.
- **[LIN-XXX]** Título — razón (si está documentada)

---

## 📊 Métricas del sprint
- **Total tasks (Notion):** N
- **Done:** N | En progreso: N | Pendiente: N | Bloqueado: N
- **Completion rate:** X%
- **Commits 14d:** N | PRs merged: N | PRs open: N
- **Repos tocados:** lista
- **Slack hits sin tracking:** N

## 🧭 Narrativa ejecutiva (para Samu)
2-4 frases conectando el estado del sprint con impacto de negocio. Sin jerga técnica. Lista para pegar en Slack.

## 🎯 Acciones sugeridas (top 5, ordenadas por leverage)
1. Accionable concreto con owner implícito
2. ...
```

## Notes

- **Output language: Spanish** (neutro/chileno). Technical terms (PR, branch, staging, cycle) stay in English.
- **Never fabricate data.** If a source is unreachable (MCP not connected, repo not cloned, Slack access denied), say so explicitly in a `## ⚠ Fuentes no disponibles` section at the top and continue with what you have. Degraded output > fake output.
- **Parallelize Phase 1.** All ingestion calls are independent — run Notion, Linear, git, and Slack fetches concurrently.
- **Respect user preferences** from CLAUDE.md:
  - `--first-parent origin/main` for commit summaries
  - Exclude `schema.rb`, lockfiles from change breakdowns
  - `RAILS_ENV=staging` = production (the deploy target, treat with care)
  - No `Co-Authored-By: Claude` in any commit this command might create (but this command shouldn't create commits anyway)
- **Slack link safety:** don't click links from Slack messages autonomously. If a request references a URL that needs visiting, include it in the report and let the user decide.
- **Samuel DMs:** skip by default. Only scan if `--with-samu` is passed.
- **Sprint 31 + 32 disorder:** when the user runs this without arguments, fetch both sprints and label each task with which sprint it actually belongs to. Do not silently merge them.
- **Scale:** if the task list is huge (>30 items), use parallel subagents for the reconcile phase — one agent per bucket — and have the main thread compose the final report.
