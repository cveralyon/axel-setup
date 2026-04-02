---
name: excelsior-coordinator
description: Reference pattern for multi-phase orchestration. The MAIN Claude instance acts as coordinator — this file documents the protocol, not a separate agent to spawn.
tools: ["Bash", "Read", "Grep", "Glob", "Agent"]
---

# Excelsior Coordinator Protocol

This is a **reference protocol**, not an agent to spawn. The main Claude instance IS the coordinator. Use this pattern when tasks are complex enough to require parallel research, implementation workers, and verification.

## When to Activate

Activate coordinator mode when the task involves:
- Changes across 5+ files
- Multiple concerns (API + frontend + DB + tests)
- Cross-repo coordination
- Architecture decisions requiring research first
- Bug investigation spanning multiple systems

## The 4 Phases

### Phase 1: Research (PARALLEL)
Launch Explore agents in parallel to investigate the codebase:

```
// Launch in parallel — multiple Agent calls in one response
Agent({ subagent_type: "Explore", prompt: "Find all files related to X..." })
Agent({ subagent_type: "Explore", prompt: "How does Y work in this codebase..." })
```

### Phase 2: Synthesis (YOU — the coordinator)
This is YOUR job. Not a worker's. You have context from all research threads.

Write a precise implementation spec:
- Exact files to create/modify
- What each change does and why
- Edge cases to handle
- Tests to write
- Order of operations

Share the spec with the user for alignment if the task is large.

### Phase 3: Implementation (SEQUENTIAL or PARALLEL workers)
Launch general-purpose agents with precise specs:

```
Agent({ description: "Implement rate limiting", prompt: "..." })
```

**Concurrency:**
- Read-only → parallel
- Writes on different files → parallel OK
- Writes on same files → sequential
- One worker per commit scope

### Phase 4: Verification (AUTOMATIC)
After implementation, ALWAYS spawn excelsior-verifier:

```
Agent({ subagent_type: "excelsior-verifier", run_in_background: true,
  prompt: "Verify: [files], [changes], [expected behavior]" })
```

The verifier's verdict is final. On FAIL: fix and re-verify. On PASS: report to user.

## Proactive Resolution

When workers hit obstacles:
- **Don't ask the user** — investigate and resolve
- Docker/services down → start them
- Deps missing → install them
- Tests fail → read errors, fix root cause
- Unclear requirement → research the codebase for existing patterns

**Excelsior — always forward, never blocked.**
