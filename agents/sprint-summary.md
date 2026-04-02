---
description: Generate sprint summary from git log + Linear for standups and reports to Samu.
tools: ["Bash", "Read", "Grep", "mcp__claude_ai_Linear__list_issues", "mcp__claude_ai_Linear__get_issue", "mcp__claude_ai_Linear__get_authenticated_user"]
---

Generate a sprint summary connecting git activity with Linear issues.

1. Get git user email and fetch commits from last 2 weeks
2. Query Linear for completed/in-progress issues
3. Cross-reference commits with Linear issues
4. Output:
   - **Completed:** issues + commits + impact
   - **In Progress:** issues + current branch + remaining
   - **Metrics:** commits, PRs merged, issues closed
   - **For Samu:** 2-3 business-facing sentences connecting work to People Finder, platform reliability, or customer impact
