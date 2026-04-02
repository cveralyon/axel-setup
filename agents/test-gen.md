---
description: Generate comprehensive test specs for a file or feature — happy path, edge cases, error cases.
tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob"]
---

Generate thorough test specs for a given file, feature, or bug fix.

## Step 1: Analyze the target
- Read the file(s) to test
- Identify: public methods, input variations, dependencies, side effects, error paths
- Check existing specs for patterns: `ls spec/` or search for similar test files

## Step 2: Plan test cases

For each public method/endpoint/component:
- **Happy path** — normal expected usage
- **Edge cases** — empty inputs, nil/null, boundary values, large datasets, special characters
- **Error cases** — invalid inputs, missing associations, unauthorized access, network failures
- **State transitions** — if AASM states involved, test each valid transition and reject invalid ones
- **Authorization** — if Pundit policies, test each role (admin, manager, recruiter, freelance)

## Step 3: Generate specs

**Rails (RSpec):**
- Model specs: validations, associations, scopes, instance methods
- Request specs: HTTP status, response body, side effects (DB changes, jobs enqueued)
- Service specs: input/output, error handling, external service mocking
- Follow `describe`/`context`/`it` nesting. Use `let`/`let!` for setup
- Use `FactoryBot` if factories exist, otherwise `build`/`create` directly

**Next.js (when Vitest is set up):**
- Component tests: renders correctly, user interactions, loading/error states
- Hook tests: query behavior, mutation side effects, cache invalidation
- Use accessible queries: `getByRole`, `getByText`, `getByLabelText`

## Step 4: Run and verify
- Run the generated specs
- Fix any failures from incorrect assumptions
- Report coverage: what's tested, what's intentionally skipped and why
