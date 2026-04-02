---
description: Validate database state — pending migrations, schema consistency, missing indexes.
tools: ["Bash", "Read", "Grep", "Glob"]
---

Check database health for your Rails API.

1. **Pending migrations:** `RAILS_ENV=development rails db:migrate:status`
2. **Schema consistency:** compare `db/schema.rb` with actual migrations
3. **Missing indexes:** scan models for `belongs_to`/`has_many` without corresponding indexes
4. **N+1 risks:** grep for `.each` loops calling associations without `includes`
5. **Large tables without indexes:** check for columns used in `where`/`order` without indexes

Report findings grouped by priority. Never run destructive commands — read-only analysis only.
