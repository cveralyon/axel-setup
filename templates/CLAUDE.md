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
- Estimate: using your team's point scale
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

### Coordinator Mode (3+ files)
When a task touches **3+ files**:
1. **Research** — Launch parallel Explore agents
2. **Synthesize** — Write precise implementation specs
3. **Implement** — Launch workers with clear specs
4. **Verify** — Launch excelsior-verifier

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
