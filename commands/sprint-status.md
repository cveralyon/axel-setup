# Sprint Status — Consolidate everything into Linear + generate review outputs

The heaviest command. Ingests **Notion (sprints + backlog) + Linear + Git across all Mainder repos + Slack (clients, tech-guild, incidents, DM Javi, DM Samu)**, deduplicates, and **writes the consolidated state back into Linear** (creating missing issues, updating statuses, reassigning based on git authorship). Then produces three separate outputs.

Linear is the single source of truth. Notion, Slack, and git are **inputs** that feed Linear.

## When to use

- Weekly sprint review where you need one reconciled view across all channels
- When Notion and Linear have drifted and you want to re-align them
- Before talking to Samu / CS team about delivery status
- After a messy sprint to clean up the tracking state

## Design principles

- **Linear = single source of truth.** Everything else is an input.
- **Early-stage disorder is expected.** The first weeks WILL be messy across Notion/Slack/Linear. That disorder is the *input*, not the problem — the job of this command is to resolve it.
- **Dedup conservatively.** A false negative (two Linear issues for the same thing) is easy to merge later. A false positive (merging two different items) loses information. When in doubt, keep separate and flag for human review.
- **Privacy gate on DMs.** Messages from DM Samu and DM Javi pass through a work-vs-personal classifier. Personal content is **dropped entirely** — never logged, never quoted, never added to Linear, never mentioned in outputs.
- **Shared-system writes are gated.** Creating/updating Linear issues affects the team. First run defaults to `--dry-run` style: print the proposed diff and wait for explicit confirmation.

## Inputs / flags

- `--dry-run` — ingest, dedup, reconcile, and print the proposed Linear diff. **Do NOT write to Linear.** Use this for the first pass or whenever you're unsure.
- `--yes` — skip the confirmation gate and execute the proposed writes immediately. Use only after you've verified a few dry-runs and trust the behavior.
- `--sprint N[,M]` — target specific sprint numbers. Default: active sprints. **Currently 31 + 32** are both active due to a known reordering — if no argument is passed, include both.
- `--window DAYS` — commit/Slack lookback window. Default: `14`.
- `--since ISO` — alternative to `--window`, explicit start date.

**Default behavior (no flags):** ingest → dedup → reconcile → print Linear diff → **wait for confirmation** → execute writes → emit three outputs.

## Data sources

### Notion
- **Sprints DB:** `11c99e746b748141a921f086e452646d`
  URL: https://www.notion.so/11c99e746b748141a921f086e452646d?v=11c99e746b748112b9b8000c781c9c03
- **Backlog DB:** `11c99e746b7481ecbeb4de6fcac61b88`
  URL: https://www.notion.so/11c99e746b7481ecbeb4de6fcac61b88?v=11c99e746b74818e9ed3000c77c7851c

Always `notion-fetch` the DB first to discover the actual property names. Do NOT hardcode property keys — the schema will drift.

### Linear
- Active cycle for the team.
- ALL issues touched in the window, not just ones assigned to Cristián (we need to see what others are doing to detect dedupes and assign correctly).
- Treat Linear as the **destination** of writes, not just a source to read.

### Git (local Mainder repos)
- `~/Mainder/Mainder-API` (Rails 8)
- `~/Mainder/SKYLINE-V9` (Next.js 15)
- `~/Mainder/MultipostingService` (Rails)
- `~/Mainder/AIAgentService` (Python/FastAPI)
- `~/Mainder/Career-Site`
- `~/Mainder/back-office`

For each repo: `git fetch origin --prune`, then capture main, staging, recent feature branches, PRs, and — critically — **author email for each commit** so we can map authorship back to Linear users.

### Slack
- `#clients` — client requests and issues
- `#tech-guild` — internal tech discussions and decisions
- `#incidents` — active incidents
- **DM Javi** — always scanned, filtered through the privacy gate
- **DM Samu** — always scanned, filtered through the privacy gate

## Phases

### Phase 1 — Ingest (parallel, read-only)

Launch these concurrently; they are fully independent:

1. **Notion Sprints DB** — fetch schema, then query tasks in target sprints. Collect title, status, assignee, priority, due date, and any references (Linear IDs, PR URLs, client names) from properties and description.

2. **Notion Backlog DB** — fetch schema, then query the top 50 prioritized items. Used only for dedup ("was this slipped to backlog?") and for detecting Slack requests that exist in backlog but not in sprint.

3. **Linear cycle + recent issues** — current cycle for the team, plus all issues updated in the window regardless of assignee. Collect ID, title, description, state, assignee, labels, PR/branch references, created/updated dates.

4. **Git across all Mainder repos** — `git fetch origin --prune` then:
   - Commits on `origin/main` in window
   - Commits on `origin/staging` in window
   - `git log origin/main..origin/staging` (pending prod deploy)
   - `git log origin/staging..origin/main` (divergence flag)
   - Feature branches touched in window (pushed, not yet merged)
   - For each commit: SHA, date, author email, subject, files touched
   - PRs via `gh pr list --state all --search "updated:>=YYYY-MM-DD"` — titles, state, merged target, author
   - **Keep a `email → commits` map** to detect authorship per canonical item later.

5. **Slack** — for each of `#clients`, `#tech-guild`, `#incidents`, `DM Javi`, `DM Samu`:
   - Read messages in window
   - For each message: timestamp, author, text, reactions, reply count, thread context
   - Capture Linear IDs (`[A-Z]{2,5}-\d+`), PR URLs, client names, and explicit questions/asks

### Phase 2 — Privacy gate (DMs only)

For every message from **DM Javi** and **DM Samu**, classify as `work` or `personal`:

**Signals FOR work (keep):**
- Mentions client names, product features, Linear IDs, PR URLs, repo names
- Technical terms: bug, incidencia, deploy, staging, prod, PR, merge, rollback, feature
- Explicit asks with business context: "¿puedes revisar X del cliente Y?", "necesitamos...", "hay que..."
- References to meetings, sprints, roadmap, delivery dates
- Screenshots/files clearly related to the product (when visible in metadata)
- Mentions Samu, Javi, Cristián, team members in a work context

**Signals AGAINST work (drop as personal):**
- Family, relationships, health, personal finances (non-company)
- Weekend plans, food, hobbies, memes, casual banter
- Venting or emotional content unrelated to a specific work item
- Politics, news, non-work opinions
- Any message where the only topic is social/relational

**Rule when ambiguous:** DROP. Treat as personal. Better to miss a work signal than to leak private content into Linear or a team-facing message. You can always re-run the command with the user clarifying later.

**Hard rules:**
- Personal messages are NEVER logged, quoted, summarized, or referenced anywhere in the outputs.
- Do NOT report a count of personal messages per DM. Do not let dropped content be reverse-engineered.
- The only trace allowed is a single line in Phase 8 output 3: "Chats personales con Javi/Samu: procesados con filtro de privacidad; contenido work-only incluido abajo." No stats, no counts, no dates.

### Phase 3 — Deduplicate and build canonical items

Build a set of **canonical work items**. Each canonical item has an ID (synthetic until it gets a Linear ID) and a list of sources.

Matching signals for the same canonical item, in order of confidence:

1. **Explicit Linear ID** — if a Notion row, Slack message, PR, or branch mentions `LIN-123`, that's the canonical ID. All sources referencing it collapse into one item.
2. **Shared PR URL or branch name** — same PR = same item, even if titles differ.
3. **Same Notion task ID** — collapse Notion duplicates.
4. **Title similarity** — if Notion title and Linear title or Slack subject share >80% token overlap AND the same client/feature name, merge them. Below 80%, keep separate.
5. **Client-specific anchors** — if a Slack message and a Notion row both reference the same unique client name + same feature/incident type within 48h, consider merging. Otherwise keep separate.

**Never merge** when:
- Two items have different explicit Linear IDs
- Two items have the same title but different clients
- Two items touch different repos AND have no shared reference

**Canonical item shape:**
```
{
  canonical_id: "tmp-01" | "LIN-123",
  title: "best title from available sources",
  sources: [
    {type: "notion", id: "...", state: "...", url: "..."},
    {type: "linear", id: "LIN-123", state: "In Progress", assignee: "...", url: "..."},
    {type: "git", repo: "...", branch: "...", pr: "owner/repo#NNN", merged_to: ["staging"], authors: ["email1", "email2"]},
    {type: "slack", channel: "clients", ts: "...", summary: "1 line, no personal content"},
  ],
  inferred_state: "...",        // Phase 4
  inferred_assignee: "...",     // Phase 4 (Linear user ID)
  blockers: [...],              // Phase 4
}
```

### Phase 4 — Reconcile state and authorship

For each canonical item, compute the **reconciled state** and **reconciled assignee**.

**State resolution (priority: git > Linear > Notion > Slack mention):**

1. If PR merged to `main` → `Done` (deployed)
2. Else if PR merged to `staging` → `In Review` with label `pending-prod`
3. Else if PR open → `In Review`
4. Else if branch has commits in window → `In Progress`
5. Else if Linear says `In Progress` or `In Review` → keep Linear state
6. Else if Notion says `Done` but no git evidence → `Desalineado` flag + keep the latest of {Linear, Notion}
7. Else → `Todo` (or whatever Linear's initial state is)

**Blockers:**
- Explicit "bloqueado"/"blocker"/"stuck"/"esperando" in Notion, Linear comments, or Slack thread referencing this item
- Implicit: no commits in 7+ days on a branch flagged as In Progress + PR with CI failing
- PR merge conflicts, stale PRs (>7 days without update)

**Assignee resolution:**
- Git author of the MOST RECENT commit on the item's branch (by commit date)
- Map git email → Linear user via the Linear users list (`list_users`). Cache the map.
- If no git activity: keep Linear assignee if set, else `unassigned`
- If multiple authors on the branch: primary = most recent commit author; add the rest as collaborators in the issue description ("Colaboradores: @user2, @user3")

### Phase 5 — Compute Linear diff

For each canonical item, compute the proposed Linear operation:

- **CREATE** — item has no Linear ID. Build a new issue draft:
  - `title`: best title from sources
  - `description`: markdown with:
    - Summary of what this is
    - Sources: list of Notion link, PR URL, Slack permalink(s), client name
    - Inferred state rationale
  - `state`: inferred state
  - `assignee`: inferred assignee
  - `labels`: derived from repo name, client name, and type (bug/feature/incident/tech-debt)
  - `cycle`: current cycle
  - `priority`: inherit from Notion if set, else `None`

- **UPDATE_STATE** — Linear issue exists but its state differs from reconciled state. Build a patch.

- **UPDATE_ASSIGNEE** — reconciled assignee differs from current Linear assignee. Build a patch.

- **ADD_COMMENT** — new Slack context or git activity not yet captured in the Linear issue. Build a comment draft with the new info only.

- **ADD_LABEL** — missing labels (repo, client, type). Build a patch.

- **NO_CHANGE** — everything aligns. Nothing to do.

Collect all operations into a structured diff. For each operation, record the `reason` (one line explaining why this change) so the confirmation step is reviewable.

### Phase 6 — Confirmation gate

Print the proposed diff as a human-readable plan:

```
## Linear — cambios propuestos

### CREATE (N issues)
1. [tmp-01] "Título" — assignee: @user — state: In Progress
   Razón: detectado en Notion sprint 32 + PR merged a staging, sin Linear issue
   Sources: Notion page, PR owner/repo#NNN, Slack #clients 2026-04-08

2. ...

### UPDATE_STATE (N issues)
1. LIN-123 "Título" — In Progress → Done
   Razón: PR owner/repo#NNN merged a main 2026-04-07

### UPDATE_ASSIGNEE (N issues)
1. LIN-456 "Título" — @oldUser → @newUser
   Razón: último commit en branch feat/xxx por newUser@mainder.ai

### ADD_COMMENT (N issues)
1. LIN-789 — nuevo contexto de Slack #clients 2026-04-08

### ADD_LABEL (N issues)
1. LIN-999 — agregar labels: [mainder-api, cliente-acme, bug]

### NO_CHANGE (N issues)
(shown as a collapsed count)
```

Then:
- If `--dry-run`: STOP here. Emit the diff and proceed to Phase 8 (outputs) WITHOUT executing.
- If `--yes`: proceed to Phase 7 without asking.
- Otherwise: wait for user confirmation. Options:
  - `apply all` → execute all operations
  - `apply 1,3,5-8` → execute selected operations by index
  - `cancel` → abort, no writes
  - `show N` → print full details for operation N before deciding

### Phase 7 — Execute Linear writes

Execute the confirmed operations sequentially (Linear MCP rate limits matter). For each:
- Try the operation
- On success: record the resulting Linear issue URL/ID
- On failure: capture the error, continue with the next operation, report all failures at the end

After execution, print a summary:
```
## Linear — cambios aplicados

✓ Creados: N (con URLs)
✓ Actualizados: N
✓ Comentados: N
✗ Fallidos: N (con razón por cada uno)
```

**Rollback helper:** if any CREATE succeeded and the user wants to undo, log the created issue IDs in a rollback hint at the bottom: `rm: LIN-NEW-1, LIN-NEW-2` so the user can delete them manually in Linear if needed.

### Phase 8 — Generate three outputs

After (or instead of, in dry-run) Phase 7, emit these three artifacts as separate sections.

---

## OUTPUT 1 — Linear consolidado (resumen)

One-screen summary of the current Linear state of the sprint(s) AFTER writes.

```
# Linear — Sprint 31 + 32 consolidado — [fecha]

## Por estado
- Done (en prod): N issues
- In Review (pending prod deploy): N
- In Review (PR open): N
- In Progress: N
- Todo: N
- Blocked: N

## Por asignado
- @cristian: N issues (N done, N in progress, N todo)
- @javi: N issues
- @samu: N issues
- otros...

## Por repo / área
- Mainder-API: N
- SKYLINE-V9: N
- ...

## Stoppers activos (detalle en output 3)
- LIN-XXX — razón corta

## Nuevas issues creadas este run
- LIN-NEW-1 "Título" — de Slack #clients
- LIN-NEW-2 "Título" — de Notion sprint 32 sin Linear ID
- ...
```

---

## OUTPUT 2 — Review detallado para CS + Samu

A polished, copy-paste-ready message in Spanish (neutro/chileno), work-only, zero personal content, zero jargon unless unavoidable. Directed at Customer Success team + Samu.

```
# Sprint 31 + 32 — review [semana del DD/MM al DD/MM]

Buenas 👋 Resumen consolidado del estado actual cruzando Notion, Linear, Slack y los repos.

## 🟢 Entregado al cliente (en producción)
Lista de 3-7 bullets, por feature o cliente. Cada bullet conecta con valor de negocio:
- **Cliente X — [feature]** — qué se entregó, qué habilita. Referencia opcional a LIN-XXX.
- ...

## 🚢 Listo, esperando deploy a prod
Lo que ya está validado en staging:
- **[Feature / fix]** — estado, ETA si existe, cliente afectado
- ...

## 🔄 En curso (foco de la semana)
Top 5 en flight, quién lidera, % estimado:
- **[Tarea]** — @owner — [avance]
- ...

## 🔴 Stoppers y riesgos
Solo lo que impacta delivery:
- **[Stopper]** — razón, owner, ayuda necesaria
- ...

## 📬 Pendientes de CS / clientes sin mover
Requests o incidencias detectadas en #clients o en mails de CS que aún no están en cola:
- **Cliente Y** — resumen, prioridad sugerida
- ...

## 📊 Números
- Entregado: N items | En staging: N | En curso: N | Stoppers: N
- PRs mergeados esta semana: N | Commits: N

## 🎯 Foco siguiente semana
2-3 frases priorizando qué sigue y por qué (impacto cliente > deuda técnica > refactors).

¿Comentarios, ajustes de prioridad? 🙏
```

Format rules for output 2:
- Spanish neutro/chileno, cálido pero profesional
- Sin lenguaje técnico innecesario. "PR mergeado" está OK; "reconcile state machine" no.
- Cero contenido personal de DMs.
- Cero jerga interna desconocida (usar "entregado al cliente" no "merged a main").
- No mencionar issues por ID a menos que CS ya los use; preferir nombres de feature/cliente.
- 250-450 palabras. Legible en un scroll.

---

## OUTPUT 3 — Lista personal para Cristián (stoppers + pendientes)

Brutal y directo. Solo para ti. Detecta lo que te está bloqueando AHORA y lo que está pendiente y requiere tu atención.

```
# Tu foco personal — [fecha]

## 🛑 Stoppers (lo que te está frenando HOY)
Cada uno con: qué es, por qué está frenado, qué desbloqueo específico se necesita.
- **[LIN-XXX] Título** — frenado hace [N días]. Razón: [X]. Desbloqueo: [acción concreta, ideally una sola].
- ...

## ⏳ Pendientes tuyos específicos (nadie más puede hacerlos)
Cosas asignadas a ti, en flight, con fricción detectada:
- **[LIN-XXX] Título** — último commit hace [N días]. Estado: [X]. Siguiente paso: [acción].
- ...

## 🔔 Necesitan respuesta tuya (Slack / DMs)
Items de trabajo en #clients, #tech-guild, #incidents, DM Javi, DM Samu que te mencionan o esperan tu respuesta. **Solo work-related**, nada personal.
- `#clients` [fecha] — [resumen work-only] — sugerencia: [acción]
- DM Javi [fecha] — [ask work-only] — sugerencia: [acción]
- DM Samu [fecha] — [ask work-only] — sugerencia: [acción]

Chats personales con Javi/Samu: procesados con filtro de privacidad; solo se incluye contenido work-related arriba.

## 🎯 Top 3 acciones de mayor leverage
Ordenadas por impacto / tiempo invertido:
1. [acción concreta, 1 línea]
2. [acción concreta, 1 línea]
3. [acción concreta, 1 línea]

## 📝 Contexto útil detectado
Cosas que encontré y que podrían interesarte (PRs de otros pendientes de review tuyo, decisiones de tech-guild que afectan tu trabajo en curso, incidentes sin owner):
- ...
```

Format rules for output 3:
- Directo, sin rodeos, sin filler.
- Acciones específicas, no generales ("revisa el PR #123" no "atiende los PRs").
- Si no hay stoppers, decirlo: "Sin stoppers activos detectados. Foco limpio 🟢".
- Cero personal content. Privacy gate aplica aquí también.

---

## Notes — reglas críticas

### Privacidad (DMs Javi + Samu)
- Filtro work/personal **conservador**: cuando hay duda, es personal → se descarta.
- Contenido personal NUNCA aparece en ningún output, ni siquiera como conteo.
- NO decir cosas como "filtré 12 mensajes personales" — eso es metadata que puede reverse-engineerarse.
- Sí decir: "Chats personales con Javi/Samu: procesados con filtro de privacidad; contenido work-only incluido" — genérico, sin números.

### Dedup
- Prefer **false negatives** (dos issues para lo mismo) sobre **false positives** (mergeando cosas distintas).
- Match conservador por client name + feature anchor, no por title similarity sola.
- Si hay cualquier duda, keep separate y flag en output 1 como "posible duplicado, revisar manual".

### Escribir a Linear
- Default: `--dry-run` behavior. Esperar confirmación explícita antes de escribir.
- Confirmación por default hace referencia a operaciones por índice, permite cancelar.
- `--yes` solo después de varios runs exitosos.
- Si una operación CREATE falla a medio camino, continuar con las siguientes y reportar el fallo al final. Nunca dejar estado parcial sin reportar.
- Rollback hint al final del Phase 7 output con los nuevos IDs creados.

### Paralelización
- Phase 1 es embarrassingly parallel. Lanzar Notion + Linear + git + Slack en paralelo.
- Si la cantidad de canonical items supera 40, paralelizar Phase 4/5 con subagents (uno por bucket).

### Fuentes offline
- Si cualquier MCP (Notion, Linear, Slack) o `gh` no responde, NO abortar. Degradar y reportar en un bloque `⚠ Fuentes no disponibles` al inicio de cada output.
- Nunca fabricar datos para compensar una fuente caída.

### Idioma
- Todos los outputs en Spanish (neutro/chileno).
- Términos técnicos en inglés permitidos: PR, branch, staging, main, cycle, merge.
- Outputs 2 y 3 más coloquiales. Output 1 más estructurado.

### Sprint 31 + 32 disorder
- Sin argumento, pullear ambos sprints.
- Etiquetar cada canonical item con el sprint al que Notion dice que pertenece.
- NO intentar "arreglar" el disorder mergeando sprints — solo consolidar el contenido en Linear sin tocar la organización de Notion.

### Safety
- Este comando NO crea commits, NO hace push, NO modifica git en ningún repo.
- Solo escribe a Linear (via MCP) y emite texto. Nada más.
- Si detectas que necesitas hacer algo destructivo, PARA y pregunta.
