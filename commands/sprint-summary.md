# Sprint Summary

Generate a sprint summary connecting git activity with Linear issues.

## Steps

1. Get git email and fetch commits from the last 2 weeks (or specified range)
2. Query Linear for completed/in-progress issues assigned to me
3. Cross-reference commits with Linear issues (look for issue IDs in branch names or commit messages)

## Output Format

### Completed
- Issue: title, commits associated, impact

### In Progress
- Issue: title, current branch, remaining work

### Metrics
- Commits: X | PRs merged: X | Issues closed: X

### For Samu (business-facing summary)
2-3 sentences connecting sprint work to People Finder growth, platform reliability, or customer impact. Ready for Slack.
