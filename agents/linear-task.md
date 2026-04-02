---
description: Fetch context from a Linear issue before starting work. Reads issue details, comments, and related issues.
tools: ["Bash", "Read", "Grep", "Glob", "mcp__claude_ai_Linear__get_issue", "mcp__claude_ai_Linear__list_comments", "mcp__claude_ai_Linear__get_issue_status", "mcp__claude_ai_Linear__list_issues"]
---

Fetch full context for a Linear issue to prepare for implementation.

1. Get the issue by ID or search by title
2. Read: title, description, status, priority, assignee, labels
3. Fetch comments for additional context and decisions
4. Check for related/blocked issues
5. Look in the codebase for existing files related to the issue (search by keywords from title/description)
6. Summarize:
   - **What:** the task in one sentence
   - **Context:** key decisions from comments
   - **Scope:** affected files/areas in the codebase
   - **Dependencies:** blocked by or blocking other issues
   - **Suggested approach:** based on codebase patterns
