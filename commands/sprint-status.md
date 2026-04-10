# Sprint Status — Consolidate everything into Linear + generate review outputs

The heaviest command. Ingests **Notion (sprints + backlog) + Linear + Git across all Mainder repos + Slack (clients, tech-guild, incidents, DM Javi, DM Samu)**, deduplicates, and **writes the consolidated state back into Linear** (creating missing issues, updating statuses, reassigning based on git authorship). Then produces three separate outputs.

**Linear is the single source of truth.** Notion, Slack, and git are inputs that feed Linear. Notion is a historical view only — this command NEVER creates cards in Notion, only reads from it and (optionally) updates state of existing cards that are desynced.

## When to use

- Weekly sprint review where you need one reconciled view across all channels
- When Notion/Linear/git have drifted and you want one consolidated state
- Before talking to Samu / CS team about delivery status
- After a messy sprint to clean up the tracking state

## Core design principles

- **Linear = single source of truth.** Everything else is an input.
- **Early-stage disorder is expected.** The job of this command is to resolve it, not to complain about it.
- **1 PR → 1 or more cards. Every PR must be covered by at least one card.** The default is 1-to-1, but a single PR that actually contains several distinct features/fixes SHOULD produce multiple cards — one per logical unit of work. Sometimes even a single large commit inside a PR warrants its own card. The rule is about fidelity to the real work done, not about matching PR count. A week with 40 merged PRs typically produces **40 or more** cards, never fewer. The ratio `cards / PRs` must be `>= 1.0` as a floor (below 1 = you're hiding work by bundling). There is no upper bound.
- **Dedup conservatively.** A false negative (two Linear issues for one thing) is easy to merge later. A false positive loses information. When in doubt, keep separate and flag for human review.
- **Privacy gate on DMs.** Messages from DM Samu and DM Javi pass through a work-vs-personal classifier. Personal content is dropped entirely — never logged, never quoted, never added to Linear, never mentioned in outputs.
- **Shared-system writes are gated.** Creating/updating Linear issues affects the team. First run defaults to `--dry-run`: print the proposed diff and wait for explicit confirmation.
- **NEVER post directly to CS channels or DMs.** All messages to `#clients`, `#incidents`, DM Javi, DM Samu, or any non-technical audience go through `slack_send_message_draft` so the user reviews and sends manually. Direct posts are allowed only in `#tech-guild` or DMs with devs (Alex, Emi), and only for status updates with no decisions pending.

## Inputs / flags

- `--dry-run` — ingest, dedup, reconcile, print the proposed Linear diff. **Do NOT write to Linear.** Use for first pass or whenever unsure.
- `--yes` — skip the confirmation gate and execute writes immediately. Only after several successful dry-runs.
- `--sprint N[,M]` — target specific sprint numbers. Default: active sprints.
- `--window DAYS` — commit/Slack lookback window. Default: `14`.
- `--since ISO` — alternative to `--window`, explicit start date.
- `--backfill` — include the retroactive backfill phase (Phase 3b below). Off by default; on for first-ever runs or when the user explicitly asks for "catch up Linear with everything I've done".

**Default behavior (no flags):** ingest → dedup → reconcile → print Linear diff → wait for confirmation → execute writes → emit three outputs.

## Data sources

### Notion
- **Sprints DB:** `11c99e746b748141a921f086e452646d`
- **Backlog DB:** `11c99e746b7481ecbeb4de6fcac61b88`

**Read-only.** Always `notion-fetch` the DB first to discover property names. Do NOT hardcode property keys.

**Warning:** `notion-query-database-view` on the full Sprints DB may return 250KB+ and explode the context. If that happens, skip Notion as primary source and rely on Linear (which already has the sprint info in issue descriptions). Fetch individual Notion pages by ID only when cross-referencing a specific card.

**Notion write policy:** **NO creating new cards in Notion from this command.** The only allowed Notion writes are `update_properties` on existing pages whose status in Notion is clearly stale compared to the reconciled state (e.g. card says "In Progress" in Notion but is merged to main in git and Done in Linear). Even those updates are proposed in the diff and wait for confirmation.

### Linear
- Active cycle for the team.
- ALL issues touched in the window, not just ones assigned to Cristián.
- Linear = destination of writes, not just source to read.
- **Linear team:** `Mainder` (id: `ebad1606-c98d-47a6-bf9f-4d2bdda0f1a2`, key `MAI`)
- **Cristián's Linear user:** `1f517371-5c7e-4cdc-8d9c-9e0cdf6c4fc5` (email: `cristian.vera@mainder.ai`)

**Team member mapping (critical — git email ≠ Linear email):**
| Git author email | Linear user | Notes |
|---|---|---|
| `cveralyon@gmail.com` | Cristián (`1f517371-5c7e-4cdc-8d9c-9e0cdf6c4fc5`) | Primary |
| `cristian.vera@mainder.ai` | Cristián (same) | Work email |
| `alexandre.bouhid@gmail.com` | Alexandre (`570f0fa5-869d-4d74-98a2-eecca0bab49d`) | |
| `Emilianorozas@gmail.com` | — | **Not in Linear yet** — leave unassigned, mention in description |
| `javiera.vargas@mainder.ai` | — | **Not in Linear** (CS, not dev) — never assign |
| `samuel.sala1@gmail.com` | — | **Not in Linear** (CEO) — never assign |

Cache this map across runs. Refresh only if `list_users` returns new members.

**Linear label constraints (learned the hard way):**
- Labels live in **groups** (e.g. "Repo", "Type", "Area"). Within a group, **only ONE label per issue is allowed**. Trying to set `skyline-v9` + `career-site-repo` on the same issue fails with `LabelIds not exclusive child labels`.
- When a feature touches multiple repos: pick the **most representative** repo label (usually where the primary logic lives) and mention the others in the description.
- The "Type" group conflict: `task` + `maintenance` collide, `task` + `Improvement` collide. Pick one.
- Before creating issues in bulk, fetch `list_issue_labels` once and cache the label → group mapping to avoid failed requests.

### Git (local Mainder repos)
- `~/Mainder/Mainder-API` (Rails 8)
- `~/Mainder/SKYLINE-V9` (Next.js 15)
- `~/Mainder/MultipostingService` (Rails)
- `~/Mainder/AIAgentService` (Python/FastAPI)
- `~/Mainder/Career-Site`
- `~/Mainder/back-office`

For each: `git fetch origin --prune`, then capture main, staging, feature branches, and — critically — author email for each commit for the mapping above.

### Slack
- `#clients` — client requests (heavily Intercom-forwarded)
- `#tech-guild` — internal tech discussions
- `#incidents` — active incidents
- **DM Javi** — always scanned, privacy gate applied
- **DM Samu** — always scanned, privacy gate applied

## Phases

### Phase 1 — Ingest (parallel, read-only)

Launch concurrently, they are fully independent:

1. **Notion Sprints DB** — fetch schema. If full query view errors with 200KB+, skip and use Linear's descriptions as ground truth.
2. **Notion Backlog DB** — fetch schema, query top 50 by priority for dedup detection.
3. **Linear** — `list_cycles` current + `list_issues` updated in window + `list_users` for mapping + `list_issue_labels` for constraint map.
4. **Git across all repos** — fetch + main/staging/branches + `gh pr list --author "@me" --state merged --search "merged:>=DATE"` for the full merge log in the window.
5. **Slack** — read each channel + each DM with the privacy gate applied.

### Phase 2 — Privacy gate (DMs only)

For every message from DM Javi and DM Samu, classify as `work` or `personal`.

**Signals FOR work:** client names, product features, Linear IDs, PR URLs, repo names, technical terms, explicit asks with business context, deliverables, meetings, roadmap, deadlines.

**Signals AGAINST work:** family, relationships, health, personal finance, weekend plans, hobbies, memes, casual banter, venting unrelated to work items, politics, social-only content.

**Ambiguous → DROP.** Treat as personal.

**Hard rules:**
- Personal content NEVER appears in any output, ever.
- No counts, no dates of filtered messages. No metadata that could reverse-engineer dropped content.
- Only one generic line allowed in Output 3: "Chats personales con Javi/Samu: procesados con filtro de privacidad; contenido work-only incluido abajo."

### Phase 3 — Deduplicate and build canonical items

Build canonical work items. Matching signals in order of confidence:

1. **Explicit Linear ID** in any source → that's the canonical ID.
2. **Shared PR URL or branch name** → same item.
3. **Same Notion page ID** → collapse Notion duplicates.
4. **Title similarity >80%** + same client/feature anchor → merge.
5. **Client-specific anchor** (same client name + same incident type within 48h) → consider merging.

**Never merge when:**
- Two items have different explicit Linear IDs.
- Two items have the same title but different clients.
- Two items touch different repos AND have no shared reference.

**1 PR → 1 or more cards. Every PR must be covered by at least one card.** The default is 1-to-1, but PRs that contain multiple distinct features/fixes should be split into multiple cards, one per logical unit. Even individual commits inside a fat PR can warrant their own card when they represent independent work. A bug fix + a feature in the same PR are ALWAYS separate cards. The rule: **every piece of logical work becomes visible as a card**. Never hide work by bundling heroically under a single umbrella card.

The only cross-PR bundling allowed is when 2-4 PRs form literally ONE logical feature across repos (e.g. Mainder-API endpoint + SKYLINE page + Career-Site propagation = 1 card like "Multi-tenant iframe filter"). This is the rare exception, not the default.

### Phase 3b — Backfill retroactive (only if `--backfill` flag)

For every merged PR in the window that has NO Linear issue linked and is NOT covered by any canonical item from Phase 3:

- Create one `bf-NN` canonical item per PR.
- Group ONLY when a cross-repo set of PRs was clearly one feature (same branch name pattern, same day, same subject stem).
- State: `Done` (merged to main) or `In Review` (merged to staging only).
- Assignee: the git author mapped via the team member mapping.
- Cycle: current cycle if merge date ≥ cycle start, else no cycle.
- Description should include: PR number(s), merge date, branch name, one-paragraph summary of what the PR did, related Linear issues if any, cluster this fix belongs to.
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
- Explicit "bloqueado" / "blocker" / "stuck" / "esperando" in Notion, Linear comments, Slack
- Implicit: no commits in 7+ days on a branch marked In Progress + PR with CI failing
- Stale PRs (>7 days without update), merge conflicts

**Assignee resolution:**
- Git author of the most recent commit on the item's branch
- Map via the team member mapping (git email → Linear user)
- If author not in Linear → unassigned + mention in description
- Multiple authors → primary = most recent commit, others as collaborators in description

### Phase 5 — Compute Linear diff

Per canonical item, compute the operation:

- **CREATE** — no Linear ID. Build draft:
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
- **NOTION_UPDATE** — existing Notion card with stale status vs reconciled (rare, use sparingly)
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
## Linear — cambios aplicados
✓ Creados: N (con URLs y IDs)
✓ Actualizados: N
✓ Comentados: N
✗ Fallidos: N (con razón por cada uno)
```

Rollback hint: list created IDs so they can be deleted manually if needed.

### Phase 8 — Slack message drafts (CS-safe)

For each Slack thread or DM that needs a response based on the reconciled state, produce a **draft** via `slack_send_message_draft` (NOT a direct post). The user reviews in Slack and sends.

**Tone rules for draft content:**
- **Audience is non-technical** (recruiters, CS, business). Write in simple, warm, direct Spanish (neutro/chileno).
- **NEVER mention PR numbers, Linear IDs (MAI-X), class names, controller names, branch names, or technical jargon.** Instead: "arreglado", "ya está en producción", "el problema era X".
- **If something doesn't exist in the product, the answer is "no lo tenemos". Period.** NEVER offer to develop it. Do not say "podemos planificarlo", "si quieres lo construimos", "lo proponemos como mejora". That creates false expectations and inflates scope.
- **Offering solutions requires pre-approval** from Cristián, EXCEPT when it's a quick-win: small change, doesn't break anything, reversible, clear. Quick-wins can be offered as "quick fix". Everything else: draft a response that just acknowledges and states current state.
- **For status updates on fixed bugs:** confirm the fix in plain language. Do not cite PR or tech details. "Arreglado, ya está en producción. Si vuelve a pasar avísame."
- **For "can we add X?" questions:** if X exists → say so. If X doesn't exist → "actualmente no lo tenemos". Do NOT add "pero se puede desarrollar".

**Draft targets (when relevant):**
- Threads in `#incidents` that need status confirmation → draft as reply in the incident thread (`thread_ts` = parent message). Audience: Javi + the rest of the team reading the channel. Tone: internal, concise, no client-facing language.
- Threads in `#clients` where Intercom forwarded a client question → **draft as reply in that thread tagging Javi explicitly** (`<@U07G632994K>`). **Critical understanding:** `#clients` is an INTERNAL channel — clients do NOT see it. Intercom forwards conversations as notifications. Javi is the one who reads them and responds to the client directly from Intercom. So the draft in #clients is NOT a client-facing message — it's an internal note for Javi with the technical context + (optionally) a suggested client-facing phrasing she can copy-edit. Always tag Javi so she gets notified.
- DM Javi → only for internal coordination asks that are NOT about a specific client message (e.g. "pinchar a Diego de Qualis", "crees que vale la pena priorizar X como feature")
- DM Samu → only for things he explicitly asked in DM
- `#tech-guild` → only pure status updates for other devs, no decisions, direct send OK

**Never draft on behalf of Cristián:**
- Anything to a client directly (Intercom conversations)
- Financial/legal/compliance decisions
- Anything requiring Cristián's judgment call

**Internal channels allowed for direct posts (no draft):**
- `#tech-guild` — only pure status updates for other devs, no decisions
- DM Alex, DM Emi — dev-to-dev comms

### Phase 9 — Three outputs

---

## OUTPUT 1 — Linear consolidado (resumen)

```
# Linear — Sprint [N+M] consolidado — [fecha]

## Por estado (post-aplicación)
- Done (en prod): N
- In Review (staging pending prod): N
- In Review (PR open): N
- In Progress: N
- Todo: N
- Blocked: N

## Por asignado
- @cristian.vera: N
- @alexandre.q: N
- unassigned: N (detalles)

## Por repo
- Mainder-API: N | SKYLINE-V9: N | MultipostingService: N | AIAgentService: N | Career-Site: N | back-office: N

## Stoppers activos (detalle en Output 3)
- MAI-XXX — razón corta

## Issues creadas en este run
- MAI-XX Título — fuente (Slack / backfill / Notion / nueva)
```

---

## OUTPUT 2 — Review para CS + Samu (copy-paste ready, work-only)

Spanish neutro/chileno, cálido y profesional. 250-450 palabras. Zero jerga. Zero PR#. Zero Linear IDs. Zero contenido personal.

**Nota dual-audience:** cuando el usuario pide un resumen para un canal mixto (#tech-guild tiene devs + no-devs; #general es todos; #clients es Javi/CS), el reporte debe ser accesible para no-técnicos pero con suficiente señal técnica para devs. **Por default**, aplicar una regla "traducción por tópico": cada sección técnica lleva primero una frase plain-language de 1-2 líneas ("qué significa esto para el cliente") y luego el detalle técnico. Si el canal es puramente no-técnico, omitir el detalle técnico completamente. Si el canal es puramente técnico (#tech-guild con solo devs), lo contrario. Default seguro: dual layer por sección.

```
# Sprint [N+M] — review [semana del DD/MM al DD/MM]

Buenas 👋 Resumen consolidado del estado actual.

## 🟢 Entregado al cliente (en producción)
3-7 bullets por feature o cliente, conectando con valor de negocio.

## 🚢 Listo, esperando deploy a prod
Lo que ya está en pre-prod (staging). Incluye ETA si existe.

## 🔄 En curso (foco de la semana)
Top 5 en flight, quién lidera, % estimado si aplica.

## 🔴 Stoppers y riesgos
Solo lo que impacta delivery: razón, owner, ayuda necesaria.

## 📬 Pendientes de CS / clientes sin mover
Requests detectadas que aún no están en cola, con prioridad sugerida.

## 📊 Números
- Entregado: N | En staging: N | En curso: N | Stoppers: N

## 🎯 Foco siguiente semana
2-3 frases priorizando qué sigue y por qué.

¿Comentarios, ajustes de prioridad? 🙏
```

**Format rules for Output 2:**
- Cálido pero profesional.
- Sin lenguaje técnico innecesario. "PR mergeado" NO; "ya está entregado" SÍ.
- Zero jerga interna. "merged a main" NO; "en producción" SÍ.
- No mencionar IDs a menos que CS ya los use.
- 250-450 palabras. Scrolleable.
- Siempre cerrar con pregunta abierta invitando respuesta.

---

## OUTPUT 3 — Lista personal para Cristián (brutal y directa)

```
# Tu foco personal — [fecha]

## ✅ Cerrados desde el run anterior
Lista breve de lo que se destrabó.

## 🛑 Stoppers (lo que te frena HOY)
- **[MAI-XXX] Título** — frenado hace N días. Razón: X. Desbloqueo: 1 acción concreta.

## ⏳ Pendientes tuyos específicos
Cosas asignadas a ti con fricción detectada.

## 🔔 Necesitan respuesta tuya (Slack work-only)
- `#incidents` [fecha] — [resumen work-only] — sugerencia: [acción]
- DM Javi [fecha] — [ask work-only] — sugerencia: [acción]

Chats personales con Javi/Samu: procesados con filtro de privacidad; contenido work-only incluido arriba.

## 🎯 Top 3 acciones de mayor leverage
1. [acción, 1 línea]
2. [acción, 1 línea]
3. [acción, 1 línea]

## 📝 Contexto útil detectado
PRs de otros esperando tu review, decisiones de tech-guild que te afectan, incidentes sin owner, etc.
```

**Format rules for Output 3:**
- Directo, sin rodeos, sin filler.
- Acciones específicas con verbo concreto ("mergear PR #123", no "atender PRs").
- Si no hay stoppers → "Sin stoppers activos. Foco limpio 🟢".
- Zero personal content. Privacy gate aplica.
- **Este output SÍ puede usar PR# y Linear IDs** — es solo para Cristián.

---

## Notes — reglas críticas (consolidadas)

### Privacidad DMs Javi + Samu
- Filtro conservador: duda → personal → descartado.
- Contenido personal NUNCA aparece, ni como conteo ni metadata.
- Una línea genérica permitida en Output 3; nada más.

### Dedup
- Prefer false negatives (2 issues por lo mismo) sobre false positives.
- Match conservador por client + feature anchor.
- Duda → keep separate y flag.

### Granularidad de backfill
- **1 PR → 1 o más cards.** Cada PR debe estar cubierto por al menos 1 card.
- Default 1-to-1, pero si un PR contiene varios features/fixes distintos, splitear en múltiples cards (incluso 1 por commit si aplica).
- Cross-PR bundling (2-4 PRs en 1 card) es la **excepción rara**, solo cuando forman literalmente una feature cross-repo.
- **Floor:** `cards / PRs >= 1.0`. Por debajo = sobre-agrupación, expandir.
- **No hay upper bound:** 40 PRs pueden perfectamente generar 55 cards si hay PRs gordos con múltiples fixes dentro.

### Linear writes
- Default dry-run. Confirmación explícita por índice permitida.
- `--yes` solo tras varios runs OK.
- Label group constraint: 1 por grupo. Fetch labels primero.
- Si CREATE falla mid-stream, continuar y reportar al final.
- Rollback hint con IDs creados.

### Notion
- **Solo lectura + updates de estado en cards existentes cuando están desalineadas.**
- NO crear cards nuevas desde este comando.
- Linear es el único source of truth.

### Slack messaging (CRITICAL)
- **Externos (#clients, #incidents, DM Javi, DM Samu, clientes): SIEMPRE draft, nunca send directo.**
- **Tono no-técnico:** zero PR#, zero Linear IDs, zero nombres de clase/controller, zero jerga.
- **No ofrecer desarrollo:** si algo no existe → "no lo tenemos", punto. NO "podemos desarrollarlo".
- **Quick wins sí** pueden ofrecerse si son chicos, reversibles, no rompen nada.
- **Internos (#tech-guild, DM devs): send directo OK** solo para status updates sin decisiones.
- **Thread targeting (IMPORTANTE):** los drafts van como reply EN EL THREAD donde apareció la pregunta/notificación original, NO como DM separado a Javi. Si Intercom forwardeó algo a #clients, el draft va en ese thread (`thread_ts` = parent). Si fue un incident en #incidents, el draft va en el thread del incident. Solo usar DM Javi para coordinación interna que NO es sobre un cliente específico (ej. "pinchar a Diego de Qualis"). Esto evita scatter de conversaciones y deja el contexto visible para todo el equipo.
- **#clients es INTERNO, los clientes no lo leen.** Es un canal donde Intercom reenvía las conversaciones de clientes como notificaciones. Javi es quien las lee y responde al cliente desde Intercom. Entonces cuando drafteo una respuesta en un thread de #clients: (1) NO es un mensaje para el cliente, es una nota interna para Javi; (2) **siempre taggear a Javi con `<@U07G632994K>`** para que le llegue notificación; (3) contenido: contexto técnico interno + opcionalmente una frase sugerida en cursiva que Javi puede copiar y editar para mandar al cliente vía Intercom. Nunca escribir como si el cliente lo fuera a leer directamente.

### Paralelización
- Phase 1 embarrassingly parallel.
- Si >40 canonical items → paralelizar Phase 4/5 con subagents (1 por bucket).

### Fuentes offline
- No abortar: degradar y reportar en `⚠ Fuentes no disponibles` al inicio de cada output.
- Nunca fabricar datos.

### Idioma
- Todos los outputs en Spanish (neutro/chileno).
- Términos EN permitidos solo entre devs: PR, branch, staging, cycle, merge.
- Outputs 2 y 3 más coloquiales. Output 1 más estructurado.

### Safety
- Este comando NO toca git, NO hace commits, NO pushea.
- Solo escribe a Linear (via MCP) y genera drafts de Slack.
- Si hay duda sobre algo destructivo → PARA y pregunta.

### Sprint disorder
- Sin argumento, pullea sprints activos (puede haber más de uno).
- No intentar "arreglar" el disorder de Notion mergeando sprints; solo consolidar en Linear.

### Calibración retrospectiva
- Al final de cada run, reportar: "Procesé X PRs, creé Y cards, updated Z, Notion touched W". Si Y/X < 0.7 y no es un run de backfill, warning por sobre-agrupación.
