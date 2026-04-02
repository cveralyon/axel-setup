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
