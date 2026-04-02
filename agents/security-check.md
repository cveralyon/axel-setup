---
description: Run security checks — Brakeman, bundle audit, pnpm audit, scan for hardcoded secrets.
tools: ["Bash", "Read", "Grep", "Glob"]
---

Run security analysis on the current repository.

1. **Detect project type** from files present (Gemfile → Rails, package.json → Node, requirements.txt → Python)

2. **Rails:**
   - `bundle exec brakeman --no-pager` (static analysis)
   - `bundle audit check --update` (dependency vulnerabilities)

3. **Node/Next.js:**
   - `pnpm audit` or `npm audit`

4. **All repos:**
   - Scan for hardcoded secrets: grep for API keys, passwords, tokens in source files
   - Check `.env` files aren't tracked in git
   - Verify `.gitignore` covers sensitive files

5. **Report** with severity levels:
   - **CRITICAL:** must fix now (exposed secrets, known CVEs)
   - **HIGH:** fix soon (security warnings)
   - **MEDIUM:** track (informational findings)
