# AXEL Upgrade Review

You are helping the user review and merge improved versions of their Claude Code configuration files. The AXEL onboarding package found files that already existed but have upgraded versions available.

## How this works

1. Read `~/.claude/axel-upgrades/MANIFEST.md` to see all files that have upgrades
2. For each file, compare the **current version** (in `~/.claude/<category>/`) with the **AXEL version** (in `~/.claude/axel-upgrades/<category>/`)
3. Present a clear comparison to the user explaining what's different and what's better
4. Let the user decide: **keep current**, **use AXEL version**, or **merge best of both**
5. Apply only what the user approves

## Rules

- **NEVER auto-apply changes** — always show the diff and wait for approval
- **Preserve user customizations** — if the user has personalized something, keep it
- **Explain the value** — for each difference, explain WHY the AXEL version might be better
- **Batch by category** — review all hooks together, then commands, then agents, etc.
- **After all reviews**, delete `~/.claude/axel-upgrades/` to clean up

## Review format per file

For each file with an upgrade:

```
### [filename]

**What changed:**
- [bullet list of meaningful differences]

**Why the AXEL version is better:**
- [concrete reasons]

**What you'd lose:**
- [any user customizations in the current version]

**Recommendation:** [keep / upgrade / merge]
```

Then ask: "Apply this change? (yes / no / merge specific parts)"

## Start

Read `~/.claude/axel-upgrades/MANIFEST.md` now and begin the review process. Work through files one category at a time.
