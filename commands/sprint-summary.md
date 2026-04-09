# Sprint Summary

Generate a sprint summary cross-referencing Notion sprint board, Linear issues, git activity, and Slack conversations.

## Inputs

- **Argument (optional):** sprint number(s). If omitted, target the **active sprint(s)**. Current state: sprint 31 and 32 are mixed (known disorder), so when no argument is passed, pull both 31 and 32.
- **Date range (optional):** defaults to last 14 days.

## Data Sources

- **Notion Sprints DB:** `11c99e746b748141a921f086e452646d` (https://www.notion.so/11c99e746b748141a921f086e452646d)
- **Notion Backlog DB:** `11c99e746b7481ecbeb4de6fcac61b88` — consult only if a task is not found in the Sprints DB
- **Linear:** active cycle for the team, issues assigned to `cristian.vera@mainder.ai`
- **Git:** Mainder repos under `~/Mainder/` (Mainder-API, SKYLINE-V9, MultipostingService, AIAgentService, Career-Site, back-office). Use `--first-parent origin/main` and exclude schema changes from summaries.
- **Slack:** channels `clients`, `tech-guild`, `incidents`, plus DMs with **Javiera** and **Samuel** (Samuel only if explicitly asked, otherwise skip DMs by default).

## Steps

1. **Notion — active sprint tasks**
   - Fetch the Sprints DB structure first (`notion-fetch` on the DB) to discover property names — do NOT assume "Status", "Sprint #", etc.
   - Query tasks where sprint = 31 or 32 (or the argument passed). Collect: title, status, assignee, priority, linked PR/issue, due date.
   - If a task references a Linear ID or GitHub PR in its description or a property, extract it.

2. **Linear — ground truth on issue states**
   - List issues in the active cycle for the team.
   - Fetch my assigned issues with state ∈ {In Progress, Todo, In Review, Done this cycle}.
   - Keep Linear state as authoritative when Notion and Linear disagree (flag the mismatch).

3. **Git — commits and PRs across Mainder repos**
   - `git config user.email` → confirm identity.
   - For each Mainder repo, get commits from the last 14 days by the user on any branch.
   - Cross-reference commit messages and branch names against Linear issue IDs and Notion task titles.
   - For each matched commit, note: repo, branch, merged-to (main / staging / neither), PR number.

4. **Slack — context, blockers, unanswered requests**
   - `clients`: any open request mapping to a sprint task or mentioning me? Unanswered threads?
   - `tech-guild`: technical discussions or decisions relevant to in-flight sprint work.
   - `incidents`: open incidents that should be in the sprint but aren't.
   - DM with Javiera: any pending ask or agreement relevant to sprint tasks.
   - DM with Samuel: **only if the user asked explicitly**. Skip otherwise.
   - For each Slack hit, capture: channel, timestamp, short summary, whether a reaction or reply from me/Javiera resolved it.

5. **Cross-reference and classify**
   - For every sprint task, compute status = reconciliation of (Notion state, Linear state, git state, Slack context).
   - Flag desynchronizations: "Notion says Done but no PR merged", "Linear Done but task not in Notion sprint", "Slack request not tracked anywhere".

## Output Format

```
## Sprint [31 + 32] — resumen al [fecha]

### ✅ Completado y deployado
- **[TEAM-XXX]** Título corto — repo/PR, deployado a main [fecha]
  - Impact: 1 línea
  - Commits: N | PR: owner/repo#NNN

### 🚢 Hecho, pendiente deploy a prod
- **[TEAM-XXX]** Título — en staging pero no en main
  - PR: owner/repo#NNN

### 🔄 En progreso
- **[TEAM-XXX]** Título — branch: feature/xxx, último commit [fecha]
  - Remaining: 1 línea

### ⏳ Pendiente (sin empezar)
- **[TEAM-XXX]** Título — asignado a [quién], prioridad [P]

### 🔴 Bloqueado
- **[TEAM-XXX]** Título — motivo (de Linear/Notion/Slack)

### ❓ Desalineado (requiere atención)
- **[TEAM-XXX]** — Notion dice X, Linear dice Y, git dice Z

### 💬 Slack — requests relevantes sin cerrar
- `#clients` [ts] — resumen, mapeado a [TEAM-XXX] o "no tracked"
- `#incidents` [ts] — incidente abierto
- DM Javiera — ask pendiente

### 📊 Métricas
- Commits: X | PRs merged: X | PRs open: X | Issues closed: X | Tasks Notion done: X / Y

### 📌 Para Samu (business-facing)
2-3 frases conectando el trabajo del sprint con People Finder growth, reliability, o impacto cliente. Lista para pegar en Slack.
```

## Notes

- All output in Spanish (neutro/chileno).
- If a Notion task lacks a link to Linear or GitHub, do NOT guess — flag it as "sin tracking" in the desalineado section.
- `RAILS_ENV=staging` = production per user convention. "Staging" here refers to the pre-prod deploy target (the branch).
- Never hallucinate PR numbers. If a PR cannot be verified via `gh` or MCP GitHub, say "PR no encontrado".
- Respect `--first-parent origin/main` and exclude `schema.rb` from change summaries (user preference).
- If the Notion MCP is not connected, say so and continue with Linear+git+Slack. Do NOT abort the whole command.
