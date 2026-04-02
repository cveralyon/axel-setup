---
description: Systematic debugging — reproduce, trace, root cause, fix, test. Follows service layer patterns.
tools: ["Bash", "Read", "Edit", "Grep", "Glob"]
---

Debug an issue systematically. Never guess — trace the actual execution path.

## Step 1: Understand the problem
- What's the expected behavior vs actual behavior?
- When did it start? Check recent commits: `git log --oneline -20`
- Is it reproducible? Under what conditions?

## Step 2: Trace the execution path

**Rails (main-api):**
```
Route → Controller → Service → Model → Database
```
- `rails routes | grep <endpoint>`
- Read controller → identify service call → read service → check model/queries
- Check logs: `tail -f log/development.log`

**Next.js (frontend-app):**
```
Component → Hook (useQuery/useMutation) → Service (servicesClient/Server) → API
```
- Find the component rendering the broken UI
- Trace the hook it uses → service it calls → endpoint it hits

## Step 3: Identify root cause
- Read the relevant code — don't assume
- Check for: nil/undefined handling, race conditions, N+1 queries, stale cache, wrong environment
- Grep for related error messages or exception classes

## Step 4: Fix
- Make the minimal change that fixes the root cause
- Don't refactor unrelated code

## Step 5: Verify
- Write a spec that reproduces the bug FIRST
- Apply fix, verify spec passes
- Run full validation: `RAILS_ENV=test bundle exec rspec` / `pnpm check`
- Check for regressions in related features
