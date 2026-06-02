---
name: context-budget
description: Audits Claude Code context consumption across agents, skills, commands, hooks, MCP servers, and the CLAUDE.md/MEMORY chain. Identifies bloat and redundancy, then produces prioritized token-savings recommendations. Backs the /context-budget command.
origin: ECC (adapted)
---

# Context Budget

Estimate the token overhead of everything loaded into a Claude Code session and surface concrete ways to reclaim context space. Adapted from ECC's context-budget for a single-runtime (Claude Code) setup on a large Opus window.

## When to Use

- The setup has grown (many agents, hooks, skills, MCP servers) and you want the real load cost.
- Output quality degrades, or the context monitor fires earlier than expected.
- Before adding more agents, skills, or MCP servers: check headroom first.
- Running the `/context-budget` command (this skill backs it).

## How It Works

Token estimation: prose uses `words × 1.3`, code or JSON uses `chars / 4`.

### Phase 1 — Inventory

Scan each source and estimate tokens.

- **Agents** (`~/.claude/agents/*.md`): tokens per file. Flag files over 200 lines (heavy) and a `description` over 30 words (it loads into every Task tool invocation, even for agents never spawned).
- **Skills** (`~/.claude/skills/*/SKILL.md`): tokens per SKILL.md. Flag over 400 lines.
- **Commands** (`~/.claude/commands/*.md`): tokens per file. Flag stale or duplicated entries.
- **Hooks** (`~/.claude/hooks/` plus the wiring in `settings.json`): count active hooks. Flag heavy or overlapping ones.
- **MCP servers** (active MCP config): count servers and total tools. Estimate ~500 tokens per tool schema. Flag servers over 20 tools, and servers that wrap a CLI already available for free (gh, git, vercel, supabase).
- **CLAUDE.md and memory chain** (`~/CLAUDE.md`, `~/.claude/memory/MEMORY.md`, any project CLAUDE.md): tokens per file. Flag a combined total over 400 lines, or a MEMORY index that carries detail instead of one-line pointers.

Note on RTK: it compresses Bash OUTPUT at runtime. It does not reduce the LOAD cost of this setup. Measure the load cost (the files above), not RTK-filtered command output.

### Phase 2 — Classify

| Bucket | Criteria | Action |
|--------|----------|--------|
| Always needed | Referenced in CLAUDE.md, backs an active command, or matches current work | Keep |
| Sometimes needed | Domain-specific, not referenced in CLAUDE.md | On-demand or lazy-load |
| Rarely needed | No reference, overlapping content, no project match | Remove or archive |

### Phase 3 — Detect Issues

- Bloated agent descriptions (over 30 words): present in every Task tool context.
- Heavy agents (over 200 lines): inflate Task context on every spawn.
- Redundant components: skills that duplicate agent logic, memory entries that duplicate CLAUDE.md rules.
- MCP over-subscription: many servers, or servers wrapping free CLI tools.
- CLAUDE.md or MEMORY bloat: verbose sections, stale rules, MEMORY entries carrying detail instead of a one-line hook.

### Phase 4 — Report

```
Context Budget Report
═══════════════════════════════════════
Window: Opus (1M tokens)
Total estimated setup overhead: ~XX,XXX tokens (XX% of 1M)
Effective working context: ~XXX,XXX tokens

Component Breakdown:
┌───────────────┬───────┬──────────┐
│ Component     │ Count │ Tokens   │
├───────────────┼───────┼──────────┤
│ Agents        │ N     │ ~X,XXX   │
│ Skills        │ N     │ ~X,XXX   │
│ Commands      │ N     │ ~X,XXX   │
│ Hooks         │ N     │ ~X,XXX   │
│ MCP tools     │ N     │ ~XX,XXX  │
│ CLAUDE+memory │ N     │ ~X,XXX   │
└───────────────┴───────┴──────────┘

Top 3 Optimizations (ranked by savings):
1. [action] → ~X,XXX tokens
2. [action] → ~X,XXX tokens
3. [action] → ~X,XXX tokens
```

In verbose mode, add per-file token counts, the heaviest files line-counted, and the MCP tool list with per-tool schema estimates.

## Best Practices

- MCP is usually the biggest lever. One 30-tool server can cost more than every skill combined.
- Agent descriptions load always, even for agents never invoked. Keep them tight.
- On a 1M window the absolute overhead matters less than redundancy and menu noise. Prioritize removing stale or duplicated surface over shaving raw tokens.
- Re-audit after adding any agent, skill, or MCP server to catch creep early.
- Pairs with the `harness-optimizer` agent, which consumes this report as its baseline.
