---
description: Production incident response — gather logs, recent deploys, commits, Linear issues, draft summary.
tools: ["Bash", "Read", "Grep", "Glob", "mcp__claude_ai_Linear__list_issues", "mcp__claude_ai_Linear__search_documentation"]
---

When something breaks in production, gather context fast and structured.

## Step 1: Situational Awareness (30 seconds)
- What's broken? (endpoint, feature, service)
- When did it start? (timestamp or "since deploy X")
- Who reported it? (CS, user, monitoring)

## Step 2: Gather Evidence
- **Recent deploys:** `gh run list --limit 5` — what went out recently?
- **Recent commits to main:** `git log main --oneline -10`
- **Recent merges to staging:** `git log staging --oneline -10`
- **CI status:** any failed runs?
- **Linear:** search for related issues or recent completions that might correlate

## Step 3: Narrow Down
- If deploy-correlated: `git diff <previous_deploy_sha>..HEAD --stat` to see what changed
- Grep for the error message or affected model/endpoint in recent changes
- Check if the issue exists in staging branch or only main

## Step 4: Draft Incident Summary

```markdown
## Incidente: [título corto]
**Severidad:** P1/P2/P3
**Inicio:** [timestamp]
**Afecta a:** [feature/users/endpoint]

### Qué pasó
[1-2 sentences]

### Causa probable
[Based on evidence gathered]

### Commits sospechosos
- [sha] [message]

### Acción inmediata
- [ ] [Rollback / hotfix / feature flag]

### Seguimiento
- [ ] Post-mortem
- [ ] Test que cubra este caso
```
