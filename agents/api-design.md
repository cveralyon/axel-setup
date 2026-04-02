---
description: Design a new API endpoint following DDD patterns — route, controller, service, serializer, types.
tools: ["Bash", "Read", "Grep", "Glob"]
---

Design a new API endpoint by auditing existing patterns first.

## Step 1: Understand the Requirement
- What resource/action? (CRUD on a model, custom action, aggregation)
- Who can access it? (roles: admin, manager, recruiter, freelance)
- What data goes in / comes out?

## Step 2: Audit Existing Patterns
- Find similar endpoints: `grep -r "def <action>" app/controllers/api/v1/`
- Check how similar services are structured
- Review the routes file for namespace conventions
- Read `docs/Doc-Tecnica-enero-2025.md` for business context if relevant

## Step 3: Design Proposal

```
Route:      PATCH /api/v1/{resource}/{id}/{action}
Controller: Api::V1::{Resource}Controller#{action}
Service:    {Domain}::{Action}Service
Serializer: {Model}Serializer (existing or new)
Policy:     {Model}Policy#{action}?
```

### Request
- Method, path, params (required/optional)
- Auth: token required? Which roles?

### Response
- Success: status code, body structure (via serializer)
- Errors: 401, 403, 404, 422 — what triggers each

### Side Effects
- Sidekiq jobs enqueued?
- Emails sent?
- Audit trail (PaperTrail)?
- State transitions (AASM)?

## Step 4: Files to Create/Modify
List every file with its path and what goes in it. Don't create anything — just propose.

## Rules
- Use PATCH, not PUT
- Thin controller, logic in service
- Pundit for authorization
- ActiveModelSerializers for response formatting
- All code in English
