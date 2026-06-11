---
name: model-routing
description: Routes each subagent to the right model tier (fable, opus, sonnet, haiku) when orchestrating multi-agent work via the Agent tool or Workflow. Use whenever spawning 2+ agents or activating Coordinator Mode. Keeps judgment on Fable (main thread), delegates token-heavy work to cheaper tiers, and enforces handoff packets plus vetting of subagent reports.
---

# Model Routing for Multi-Agent Orchestration

The main thread (Fable) is the orchestrator, architect, synthesizer, and final judge. Cheaper subagents do bounded, token-heavy work. Never delegate judgment.

## Reserved for Fable (main thread, never spawn for this)

- Decomposing ambiguous work into clean parallel slices.
- Architecture, product, security, and payment-flow tradeoffs.
- Reading conflicting subagent reports and deciding what matters.
- Integrating partial implementations into one coherent plan.
- Final review, risk assessment, and user-facing synthesis.

## Routing Table

Set the `model` param explicitly on every Agent call. Default to `sonnet` when a task does not match a row.

| Task type | model | Why |
|---|---|---|
| Broad codebase exploration, file/pattern discovery (Explore agents) | sonnet | High read volume, moderate judgment |
| Mechanical reduction: log filtering, test output triage, inventories, classification, link checking | haiku | Zero judgment, maximum volume |
| External docs research, dependency or vendor comparison | sonnet | Needs criteria but not deep tradeoffs |
| Bounded implementation from a precise, file-scoped spec (1 logical unit) | sonnet | Spec quality carries the work |
| Complex implementation, risky refactor, DB migrations, security or payment code | opus | Error cost exceeds the price delta |
| Code review, adversarial verification (excelsior-verifier, refute passes, skeptic agents) | opus | Must independently catch errors from other agents |
| Sub-coordinators that themselves spawn agents (cross-repo, debug session managers) | opus | Orchestration judgment without Fable price |
| Synthesis of conflicting findings, final verdicts, anything ambiguous | fable (stay in main thread) | This is the judgment layer |

Cost anchors per 1M tokens (input/output): haiku $1/$5, sonnet $3/$15, opus $5/$25, fable $10/$50. Fable's tokenizer also emits roughly 30% more tokens for the same content, so its effective cost is about 2.6x opus. Every token kept out of the main thread is saved at the most expensive rate in the catalog.

## Handoff Packets (required for every delegated prompt)

Write the prompt as if the subagent has zero chat context. Include:

1. Repo path and the exact objective.
2. Scope: files, packages, or surfaces in scope, and what is explicitly out of scope.
3. Evidence format to return: file paths with line refs, commands run, diffs, failures, uncertainties, stop conditions hit.
4. Verification: commands or flows to run, and what success looks like when knowable.
5. Stop conditions: if live code contradicts the prompt, a command fails twice after a reasonable retry, or the task needs out-of-scope files, stop and report instead of improvising.

Prefer parallel subagents (one message, one tool block per agent) when slices are independent. Keep blocking or tightly coupled work local.

## Vetting Delegated Work

Treat subagent reports as leads, not facts:

- Before acting on a high-impact finding, reopen the cited files and confirm the line refs or failures yourself.
- Before opening a PR or reporting work as done, review the final diff against the task in the main thread.
- Before accepting dismissals (FP, OUTDATED, MOOT), run an adversarial refute pass: skeptic agents with the inverted instruction (prove the bug is still alive on staging/main today).
- PR reviewers must read repo state via `git show origin/branch:path`, never the working tree, which may sit on another branch.

## Anti-waste Rules

- Do not spawn an agent for a single targeted read or an already-known file path: read it directly.
- Group by file or surface: one finding repeated across 15 lines of one file is 1 agent, not 15.
- Run long agents with `run_in_background: true` and keep orchestrating; never poll.
- Verification agents (excelsior-verifier) run in background on opus; do not block reporting structure on them, but do not claim "verified" before they return.

## Integration with Coordinator Mode (CLAUDE.md)

When Coordinator Mode triggers (3+ files), apply this mapping to its mandatory minimums:

- Research: the 2+ parallel Explore agents run on `sonnet` (or `haiku` if purely mechanical inventory).
- Implement: workers default to `sonnet`; escalate a worker to `opus` when its unit touches migrations, auth, payments, multi-tenant scoping, or cross-repo contracts.
- Verify: `excelsior-verifier` runs on `opus`, in background.
- Synthesize and final judgment: never delegated, stays in the main thread.
