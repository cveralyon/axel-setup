---
description: Performance analysis — N+1 queries, missing eager loading, slow queries, unnecessary re-renders.
tools: ["Bash", "Read", "Grep", "Glob"]
---

Analyze the codebase or a specific area for performance issues. Read-only analysis — report findings, don't auto-fix.

## Rails (main-api)

### N+1 Queries
- Find `.each`/`.map`/`.find_each` loops that access associations
- Check if `includes`/`eager_load`/`preload` is used upstream
- Check serializers with `belongs_to`/`has_many` that trigger lazy loads

### Slow Queries
- Find `where` clauses on columns without indexes (cross-reference with `db/schema.rb`)
- Find `LIKE`/`ILIKE` queries without trigram/GIN indexes
- Find `order` on unindexed columns
- Check for `pluck` vs loading full objects when only IDs/values needed

### Sidekiq
- Find jobs doing heavy DB work without batching
- Check for jobs that could be parallelized

## Next.js (Frontend)

### Re-renders
- Find components missing `memo`, `useMemo`, or `useCallback` where appropriate
- Check for objects/arrays created inline in JSX props (new reference each render)
- Find Context providers that re-render too many consumers

### Data Fetching
- Check `staleTime` configuration in React Query hooks — too low = excessive refetching
- Find components that fetch data they could receive as props from a parent
- Check for waterfall requests that could be parallelized

### Bundle
- Large imports that could be dynamic: `import()` for heavy components
- Check if heavy libraries are imported in client components unnecessarily

## Report Format

| Issue | Location | Severity | Suggested Fix |
|-------|----------|----------|---------------|
