---
name: memory-review
description: "Review, optimize, and maintain the persistent memory system. Reads all memory files, identifies stale/duplicate/outdated entries, asks the user targeted questions, and produces a clean, optimized memory state. Use when memory feels bloated, after major project changes, or periodically to keep context sharp."
---

# Memory Review & Optimization

Interactive memory maintenance skill. When invoked, systematically reviews all memory files and works with the user to keep the memory system clean, relevant, and efficient.

## Workflow

### Phase 1: Audit

1. Read `~/.claude/memory/MEMORY.md` (index)
2. Read every memory file listed in the index
3. Detect any orphan files (exist on disk but not in index)
4. For each memory file, evaluate:
   - **Staleness**: Does the content reference things that may have changed? (team members, tools, architectures)
   - **Redundancy**: Is this duplicated or overlapping with another memory file?
   - **Relevance**: Is this still useful for future conversations?
   - **Accuracy**: Does this match current reality? (verify against code/git if needed)
   - **Size**: Is this too verbose? Can it be trimmed without losing value?

### Phase 2: Report

Present a structured report to the user:

```
## Memory Audit Report

### Summary
- Total files: X
- Index entries: X
- Orphan files: X (not in index)
- Potentially stale: X
- Candidates for merge: X
- Candidates for removal: X

### Per-File Analysis
For each file, show:
- Status: OK / STALE / MERGE_CANDIDATE / REMOVE_CANDIDATE
- Last modified: date
- Reason: why this status
- Suggested action: keep / update / merge with X / remove
```

### Phase 3: Interactive Q&A

Ask the user targeted questions to resolve ambiguities:
- "Is X still accurate?"
- "Should I merge A and B since they overlap?"
- "This mentions Y which seems outdated — remove or update?"
- "Any new context I should add?"

Keep questions grouped and numbered for easy answering. Max 5-7 questions per round.

### Phase 4: Execute

Based on user answers:
1. Update stale files with correct information
2. Merge redundant files
3. Remove files the user confirms as unnecessary
4. Add any new memory files the user requests
5. Rebuild `MEMORY.md` index with accurate one-line descriptions
6. Sync both memory locations:
   - `~/.claude/memory/` (shared, primary)
   - `~/.claude/projects/` (legacy fallback, path varies by user)

### Phase 5: Summary

Show final state:
- Files kept / updated / merged / removed
- Total memory size before vs after
- Next review suggestion (based on change velocity)

## Rules

- NEVER delete a memory file without explicit user confirmation
- NEVER remove information that is still relevant — when in doubt, ask
- Prefer updating over removing — information decay is better handled by correction than deletion
- Keep MEMORY.md index lines under 120 chars
- Memory files should use the standard frontmatter format (name, description, type)
- After cleanup, verify all index links point to existing files

## Memory Types Reference

| Type | Purpose | Decay Rate |
|------|---------|------------|
| `user` | Identity, preferences, skills | Low — rarely changes |
| `feedback` | How to work with user | Low — corrections persist |
| `project` | Ongoing work, team, goals | High — changes frequently |
| `reference` | Where to find external info | Medium — tools change |

## When to Suggest Running This

Suggest `/memory-review` to the user when:
- More than 30 days since last review
- After major team/project changes
- When memory files exceed 20 entries
- When you notice conflicting information in memory
