# Daily — Morning Check-in

Scan rápido de todo lo que pasó desde el último check. Read-only, no escribe en ningún sistema. Diseñado para arrancar el día en ~2 minutos sabiendo qué pasó y qué necesita atención.

## Data sources (all read-only, all in parallel)

### Slack (last 24h or since last check, whichever is longer)
- `#incidents` (C07A76XN5QB) — nuevos incidents, threads sin cerrar, threads sin respuesta tuya
- `#clients` (C07FA2HPPHP) — nuevas conversaciones de Intercom, requests sin atender
- `#tech-guild` (C080YP98T44) — mensajes de Samu/Javi/Alex/Emi que requieran acción o respuesta
- **DM Javi** (U07G632994K) — asks pendientes, confirmaciones, context work-only (privacy gate)
- **DM Samu** (U062B9FMR6F) — preguntas, pedidos, context work-only (privacy gate)

### Git (all Mainder repos)
- `git fetch origin --prune` en cada repo
- PRs merged since last check (`gh pr list --state merged --search "merged:>=DATE"`)
- PRs opened/updated by anyone (`gh pr list --state open`)
- New branches pushed

### Linear
- Issues updated since last check
- New issues created
- Issues moved to Done (celebrate!)
- Issues assigned to me still in Todo (nudge)

### Google Calendar
- Today's events with time, title, and meeting link
- Use `gcal_list_events` for the user's primary calendar, filtered to today

### Gmail
- Unread or recent emails from the last 24h that are work-relevant
- Use `gmail_search_messages` with query like `is:unread newer_than:1d` or `newer_than:1d`
- Focus on: emails from clients, from team members (Samu, Javi, Alex, Emi, Diego Qualis), from external services (Bizneo, Idibu, Unipile, NTT DATA)
- Skip: newsletters, marketing, automated notifications that aren't actionable
- For each relevant email: sender, subject, 1-line summary of what it needs

## Privacy gate (same as sprint-status)
DMs with Javi and Samu pass through work-vs-personal classifier. Personal content dropped silently.

## Output format

```
## Buenos días — [fecha] [día de la semana]

### 📅 Agenda de hoy
- HH:MM — [título] ([link])
- (sin reuniones hoy ✨)

### 📧 Emails relevantes (últimas 24h)
- [sender] — [subject] — [acción necesaria o "solo FYI"]
- (sin emails relevantes pendientes ✨)

### 🆕 Qué pasó mientras no estabas
Bullets cortos de lo nuevo en cada canal, solo lo que requiere tu atención:
- #incidents: [resumen o "sin nuevos"]
- #clients: [resumen o "sin nuevos"]
- #tech-guild: [resumen o "sin nuevos"]
- DM Javi: [resumen work-only o "sin novedades"]
- DM Samu: [resumen work-only o "sin novedades"]
- Git: [N PRs merged, N PRs opened, branches nuevas relevantes]
- Linear: [N issues movidas, N nuevas]

### 🔔 Necesita tu respuesta/acción
Lista priorizada de threads, PRs, asks que esperan algo de ti:
1. [canal/fuente] — [qué] — [acción sugerida]
2. ...
(si no hay nada: "Inbox limpio 🟢")

### 🔴 Stoppers activos
- [MAI-XX] — razón — días frenado
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

**Linear updates:**
- Issues that should move to Done based on git evidence (PR merged to main but Linear still says In Progress/In Review)
- New items detected in Slack (#incidents, #clients) that don't have a Linear issue yet → propose CREATE
- Issues with stale status (no git activity in 7+ days but still marked In Progress) → flag for user
- Assignee mismatches (git author ≠ Linear assignee) → propose UPDATE_ASSIGNEE

**Notion updates (existing cards only):**
- Cards in Notion whose status is stale vs the reconciled state (e.g. Notion says "In Progress" but Linear/git says Done) → propose update_properties

**Slack drafts:**
- Threads in #incidents or #clients that need a response → propose drafts (following CS tone rules: tag Javi, plain-language, no dev offers)

### Execution:
- Print the proposed updates as a numbered list
- Wait for: `apply all`, `apply 1,3,5`, or `skip`
- If user says nothing about syncing, skip — don't block the morning

## Rules
- **Phase 1 (briefing) is read-only.** The briefing output itself never writes to any system.
- **Phase 2 (sync) proposes writes** but waits for explicit confirmation before executing.
- **Rápido.** Parallelize todo. El output debe ser corto y escaneable.
- **Si no hay novedades en un canal, decir "sin novedades" y seguir.** No llenar con texto de relleno.
- **Privacy gate aplica** igual que en sprint-status.
- **Tono:** interno, para Cristián. Puede usar PR#, Linear IDs, jerga técnica. Es solo para ti.
- **Si detecta que hay un EOD review pendiente de ayer** (Samu pidió daily reports), mencionarlo en el foco sugerido.

## Relationship with other skills
- **`/sprint-status`** — el audit pesado semanal con writes a Linear. `/daily` es el check ligero diario que NO escribe nada.
- **`/eod-review`** — el reporte de fin de día para Samu y el Product Drop. `/daily` es el input de la mañana; `/eod-review` es el output de la tarde.
- **`/sprint-summary`** y **`/weekly-review`** fueron eliminados — su funcionalidad está absorbida por `/sprint-status`.
