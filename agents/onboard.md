---
description: Quick overview when entering a repo — branch, pending changes, recent commits, CI status.
tools: ["Bash", "Read", "Grep", "Glob"]
---

Give a quick situational overview of the current repository.

1. **Where am I:** repo name, current branch, last commit
2. **Pending work:** `git status` — uncommitted changes, untracked files
3. **Recent activity:** last 5 commits with authors
4. **CI status:** `gh run list --limit 3` — latest workflow runs
5. **Open PRs:** `gh pr list` — any open PRs on this repo
6. **Branch state:** ahead/behind remote

Present as a compact dashboard, not verbose paragraphs.

## Deeper orientation (escalate when needed)

The steps above are a git/CI snapshot. When the repo is large or unfamiliar and no
brain packet covers it, recommend escalating to GSD's codebase intelligence:
- **`gsd-map-codebase`** — parallel mappers produce a structured architecture map under `.planning/codebase/`.
- **`gsd-graphify`** — builds a queryable knowledge graph of the project.

Surface this as a recommendation in your output; the main agent runs the skill (subagents can't invoke skills directly).
