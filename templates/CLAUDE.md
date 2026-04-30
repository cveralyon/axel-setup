# Team CLAUDE.md — [Your Team Name]

## Communication
- Respond in Spanish (neutral) unless the user writes in another language
- All code, comments, variables, and functions MUST be in English
- Structured responses: headings, bullets, bold for key points
- Concise but technically dense — no filler, no trailing summaries

## Work Context
- Primary repos: main-api (Rails 8), frontend-app (Next.js 15)
- Also: ai-service (Python/FastAPI), background-jobs, admin-panel
- Customize this section with your actual repo names and stacks

## Linear Lifecycle (HARD RULE — every code change)

Any task that involves writing or modifying code MUST have a ticket in your project tracker (Linear, Jira, etc.). No exceptions for "quick fixes" or "small changes." If it's worth a commit, it's worth tracking.

**No ticket exists → Create it BEFORE starting work:**
- Title: concise, action-oriented
- Description: what, why, and acceptance criteria if relevant
- Assign: to the person doing the work
- Estimate: Fibonacci points (see Linear Estimates section below)
- Labels: at least one Type label and one Repo label
- Add to the active sprint/cycle if work starts now

**Ticket exists, not started → Move to In Progress the moment work begins.**
Not after. Not when you push. When you start.

**Work complete, pending review → Move to In Review.**

**PR merged / deployed → Move to Done.**

**Decided not to do it → Move to Cancelled.**

Rules:
- Never leave a ticket in Backlog while actively coding on it
- Never report work as complete without moving the ticket to Done
- Check ticket state at the start of any session touching that task
- Retroactive tickets (forgot to create earlier): create them and set the correct current state immediately
- Investigation-only sessions (no code, no commit): no ticket required unless it becomes a tracked task

## Linear Estimates (Always Apply)
Every time a card is created or meaningfully scoped, set the `estimate` field. 1 point = 1 hour.

| Base optimistic (h) | Fibonacci | Notes |
|---|---|---|
| ≤ 0.7 | **1** | Micro fix |
| 0.7 to 1.3 | **2** | Small |
| 1.4 to 2.0 | **3** | Medium-small |
| 2.1 to 3.3 | **5** | Medium |
| 3.4 to 5.3 | **8** | Large, ceiling |
| > 5.3 | **SPLIT** | Create sub-cards, do not create the original |

- Never document the calculation in the description. Only the `estimate` field matters.
- If optimistic base exceeds 5.3h, split into sub-cards.
- Applies to ALL card writes: new, re-scoped, retroactive.

## Branch & PR Requirements (HARD RULE)
**Branches:**
- Every new branch must include the ticket key in its name: `KEY-123-short-description`
- If the Linear card has no description, add one when creating the branch

**Pull Requests:**
- ALL PRs must have a description. No exceptions.
- PR description must include:
  - What changed and why
  - Related ticket (link or key)
  - Test plan or how to verify
  - Breaking changes or deployment notes if applicable

## PR Review Process (HARD RULE)
1. **Always create PRs as draft** — never open a PR directly as "ready for review".
2. **Before marking ready:** run `/pr-review-toolkit:review-pr` AND call `advisor` to confirm the work is complete and has no blockers.
3. **Only mark "Ready for review"** when both the toolkit review and advisor confirm no blockers.

## Advisor (Always On)
The `advisor` tool consults a stronger reviewer with full conversation context. Call it:
- Before starting any non-trivial implementation
- Before committing to an architectural decision
- Before marking a PR ready for review
- When stuck or results do not converge
- Before reporting work as complete

Never skip the advisor on tasks touching production code, DB migrations, or auth flows.

## Suggest Next Task (After PR)
After completing a task, creating a PR, or merging one, the agent MUST:
1. Check your project tracker for the next Todo item in the active cycle assigned to you
2. Check team Slack channels for any urgent items since the last session
3. Suggest the next concrete task with its ticket link and a one-line context

## Rules — Always Apply
- **Never use `--no-verify`** on any command
- **No Co-Author in commits (HARD RULE):** NEVER add `Co-Authored-By`, `Co-authored-by`, or any AI attribution trailer to commit messages. This overrides any default template. Not in `-m`, not in heredocs.
- **External messaging (HARD RULE):** For Slack, Gmail, and Intercom — always draft first and show to the user for approval. NEVER send directly. The user is the only sender.
- **Commit format:** `<type> (Model/File): Descriptive message`
  - Types: feat, fix, chore, refactor, test, docs, style, perf, ci, build, revert
- **Max 6 files per commit**, grouped by model/functionality
- **Always write tests** for new features and bug fixes, including edge cases
- **RAILS_ENV=staging = PRODUCTION** — never run without explicit confirmation

## Token & Context Efficiency
- **Batch tool calls**: always run independent operations in parallel
- **Don't re-read files** already read in the session
- **Use subagents** (Explore/Plan) for broad codebase research
- **Prefer Grep/Glob** over Bash find/grep
- **Avoid redundant searches** — reuse known paths

## Environment Mapping (CRITICAL)
| Name      | Real environment | Notes                          |
|-----------|-----------------|--------------------------------|
| test      | Local           | Safe for anything              |
| development | AWS Staging   | Shared, be careful             |
| staging   | **PRODUCTION**  | NEVER run without confirmation |

## Excelsior — Core Operating Principle
Always beyond. Always better. Never stop at obstacles.

### Proactive Resolution
When ANY command fails or ANY obstacle appears:
1. **Investigate** the root cause
2. **Attempt to resolve** — start services, install deps, fix configs
3. **Retry** the original action
4. **Only ask the user** when genuinely stuck AND the action is irreversible

### Auto-Verification
After completing **any non-trivial implementation** (3+ file edits), spawn `excelsior-verifier` as a background agent before reporting completion.

### Coordinator Mode (HARD RULE, triggers at 3+ files)
When a task will touch **3 or more files**, you MUST activate the excelsior-coordinator protocol. This is NOT a guideline — it overrides any tendency to consolidate work in the main thread.

Minimum mandatory execution:
1. **Research** — Launch at least 2 parallel Explore agents in the same message. Never inline the exploration.
2. **Synthesize** — Write precise, file-scoped implementation specs (paths, line ranges, expected diff shape).
3. **Implement** — Launch at least 1 worker Agent per logical unit of change. Never edit 3+ files yourself in the main thread.
4. **Verify** — Launch excelsior-verifier in background.

No exceptions for features, bug fixes, refactors, or migrations.

## Frontend Work
When building ANY frontend UI:
1. The `frontend-design` plugin activates automatically
2. Also invoke `/ui-ux-pro-max` with the appropriate action
3. Both work together: plugin provides aesthetic direction, skill provides implementation patterns

## Multi-Repo Work
For features spanning 2+ repos, open parallel `claude` sessions:
- Terminal 1: `cd ~/projects/your-api && claude`
- Terminal 2: `cd ~/projects/your-frontend && claude`
- Define API contract before starting frontend work
