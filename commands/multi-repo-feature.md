# Multi-Repo Feature Coordinator

Coordinate a feature that spans multiple repos. Creates a parallel work plan and sequences changes correctly.

## Input
Describe the feature or provide a Linear issue ID. Example:
- "Implementar filtro de candidatos por idioma en API y frontend"
- "MAI-123"

## Steps

### 1. Understand the Feature
If a Linear issue ID is provided, fetch it with the Linear MCP tool to get full context, acceptance criteria, and comments.

### 2. Impact Analysis
For each repo, determine:
- **main-api**: new/modified endpoints, migrations, services, background jobs
- **frontend-app**: new/modified pages, components, hooks, API calls, i18n keys
- **ai-service**: new/modified agents, prompts, contracts (only if AI logic involved)
- **background-service**: new/modified background processing (only if affected)

### 3. API Contract First
If API changes are needed, define the contract before writing any code:
```
Endpoint: METHOD /api/v1/[resource]
Auth: required / public
Request: { field: type }
Response: { data: { field: type } }
Errors: 422 { errors: [...] }
```

### 4. Sequenced Work Plan
Output a sequenced plan respecting the dependency order:
1. Migrations (API first)
2. Backend services + endpoints
3. AI/Agent logic (if needed)
4. Frontend components + hooks

### 5. Parallel Session Setup
For large features (3+ files per repo), suggest opening parallel Claude sessions:

```bash
# Terminal 1 — API
cd ~/projects/your-api && cl
# Prompt: "Implement [backend part] following the contract: [contract]"

# Terminal 2 — Frontend (can start with mock data)
cd ~/projects/your-frontend && cl
# Prompt: "Implement [frontend part] against this API contract: [contract]"
```

### 6. Integration Checklist
Generate a checklist for verifying the full feature works end-to-end:
- [ ] Migration applied (`RAILS_ENV=development rails db:migrate`)
- [ ] API endpoint returns correct shape
- [ ] Frontend displays data correctly
- [ ] i18n keys added in all locales (en, es, ca, fr)
- [ ] Specs written and passing
- [ ] No TypeScript errors (`pnpm typecheck`)
- [ ] Linear issue updated with implementation notes
