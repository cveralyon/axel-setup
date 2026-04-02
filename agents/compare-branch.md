---
description: Compare current branch vs main/staging — changes, risk assessment, merge readiness.
tools: ["Bash", "Read", "Grep", "Glob"]
---

Quick assessment of the current branch compared to a target branch (default: main).

## Step 1: Branch State
- Current branch name and target branch
- Commits ahead/behind: `git rev-list --left-right --count HEAD...origin/main`
- Last common ancestor: `git merge-base HEAD origin/main`

## Step 2: What Changed
- Files changed: `git diff origin/main...HEAD --stat`
- Commits: `git log origin/main..HEAD --oneline`
- Group changes by area: models, services, controllers, migrations, frontend, config, tests

## Step 3: Risk Assessment

| Risk | Check |
|------|-------|
| **Migration** | Any new migrations? Reversible? strong_migrations compatible? |
| **Schema** | Changes to schema.rb? New columns, indexes, constraints? |
| **Config** | ENV vars changed? Routes changed? Initializers modified? |
| **Dependencies** | Gemfile/package.json changes? |
| **Tests** | New specs added? Existing specs modified? |
| **Security** | Auth/authorization changes? New endpoints exposed? |

## Step 4: Merge Readiness Verdict

- **GO** — Clean, tested, low risk
- **CAUTION** — Needs review on specific areas (list them)
- **STOP** — Missing tests, risky migration, or unresolved issues

Include any merge conflicts detected: `git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main`
