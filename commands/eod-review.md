# EOD Review — End-of-Day report para #tech-guild

Genera un reporte de fin de día con todo lo que se hizo, cambió y avanzó HOY. Diseñado para cumplir con el pedido de Samu del 10/04: "Recordad mandar un reporte de todos los updates al final del día para poder actualizar el Product Drop."

El output es un **draft en #tech-guild** listo para que Cristián revise y envíe. Incluye una versión dual: detalle técnico para devs + resumen plain-language para CS/Samu.

## When to use

- Al final de la jornada (~18:00 hora Chile) antes de cerrar.
- Cuando Samu o Javi piden "qué se hizo hoy".
- Antes de un standup o sync rápido donde necesitas mostrar avance del día.

## Data sources (all read-only, all in parallel)

### Git (primary source for "what was done today")
- For each Mainder repo: `git fetch origin --prune`
- PRs merged TODAY by anyone: `gh pr list --state merged --search "merged:>=TODAY"`
- PRs opened TODAY
- Commits pushed to staging/feature branches TODAY
- Author mapping via the team member table (git email → name)

### Linear
- Issues moved to Done today
- Issues moved to In Progress today (started)
- New issues created today
- Comments added today

### Slack (secondary — for context on what happened)
- `#incidents` — any new incidents today, resolved or open
- `#tech-guild` — any important messages (Samu asks, Javi asks, decisions)
- `#clients` — new client requests today (count + brief summary)

### Notion
- Not queried. Linear is the source of truth.

## Privacy gate
Same as sprint-status. DMs are NOT scanned for EOD review — only channel content.

## Output format

The output is a **Slack draft** in `#tech-guild` (channel C080YP98T44). NOT a direct send.

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

*📬 Requests de clientes nuevas*
• [count] nuevas en #clients: [resumen brevísimo]
(o "Sin requests nuevas")

*🔴 Stoppers*
• [MAI-XX] — [razón] — [días frenado]
(o "Sin stoppers 🟢")

*🎯 Foco mañana*
• [1-3 bullets de qué sigue]
```

## Rules

### Content rules
- **Solo lo de HOY.** No repetir lo de ayer ni hacer resumen semanal — para eso existe `/sprint-status`.
- **Contar trabajo de TODOS, no solo de Cristián.** Si Alex mergeó algo hoy, va. Si Emi resolvió un incident, va. Este es un team report.
- **PRs de staging promote / "Staging" merges** que solo promueven staging→main NO cuentan como features — son operacionales. Si el contenido real ya se reportó antes, skip.

### Tone rules (non-technical first)
- **La audiencia principal es Samu y Javi.** No son técnicos. Necesitan entender qué avanzó, qué mejoró para los clientes, qué está frenado.
- **Escribir SIEMPRE en plain-language.** Cada item es 1 frase que responde: "¿qué puede hacer el cliente ahora que antes no podía?" o "¿qué problema ya no va a tener?".
- **NUNCA mencionar:** PR#, Linear IDs (MAI-X), nombres de clase, branch names, nombres de servicios internos, jerga técnica de ningún tipo.
- **Ejemplos:**
  - ❌ "Mergeamos PR #462 fix (ProcessCvSubmissionJob): Deduplicate apply_portals candidates by email/phone"
  - ✅ "Arreglamos un problema donde las candidaturas de Infojobs se duplicaban dentro del proceso"
  - ❌ "Fix SSRF allowlist guard en server-side fetchWithAuth"
  - ✅ "Cerramos una vulnerabilidad de seguridad en el servidor"
- **Si los devs quieren detalle técnico**, pueden preguntar o revisar #tech-guild / Linear directamente. El EOD review NO es para ellos, es para visibilidad de negocio.

### Delivery rules
- **Siempre draft, nunca send directo.**
- **Tag `@here`** al inicio solo si hay algo bloqueante o un deploy grande con impacto en clientes. No abusar.
- **Corto.** Target: 10-15 líneas. Máximo 25 líneas. Si el día fue largo, priorizar los 5 items más importantes y cerrar con "y N items más de mantenimiento/bugfixes menores".

### Reminder
- **Cristián tiene que enviar esto antes de las 18:00 Chile** (Samu lo pidió explícitamente). Si este skill se ejecuta y ya pasaron las 18:00, mencionarlo al inicio: "⚠ Este reporte debió haberse enviado antes de las 18:00."
- El skill `/daily` (morning check) debe recordar al usuario que tiene que correr `/eod-review` al final del día.

## Relationship with other skills
- **`/daily`** — el check de la mañana (qué pasó, qué necesita atención). `/eod-review` es el cierre de la tarde (qué se hizo).
- **`/sprint-status`** — el audit semanal pesado. `/eod-review` es el micro-reporte diario.
- **Los dos se complementan:** `/daily` por la mañana → trabaja todo el día → `/eod-review` a las 18:00 → enviar a #tech-guild.
