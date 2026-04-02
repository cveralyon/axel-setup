---
description: End-to-end feature scaffolding following repo patterns — service, endpoints, types, hooks, components.
tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob"]
---

Scaffold a new feature end-to-end by following the exact patterns in the current repo.

## Step 1: Detect project type and audit patterns

- Rails (Gemfile) → DDD service layer pattern
- Next.js (package.json + next.config) → service + hooks + components pattern
- Read 2-3 existing examples of similar features to match conventions exactly

## Step 2: Rails (API)

Create in order:
1. **Types/Model** — `app/models/` with validations, associations, Paranoia, PaperTrail if needed
2. **Service** — `app/services/{domain}/` following `Namespace::Action` naming, single responsibility
3. **Serializer** — `app/serializers/` for JSON formatting
4. **Controller** — `app/controllers/api/v1/` thin, delegates to service, RESTful
5. **Routes** — `config/routes.rb` using PATCH (not PUT), namespaced
6. **Migration** — Only if user confirms. Check timestamp consistency with last migration
7. **Specs** — `spec/` matching the created files: model spec, request spec, service spec

## Step 3: Next.js (Frontend)

Create in order:
1. **Types** — `services/{domain}/types.ts` or `lib/types/{domain}.ts`
2. **Endpoints** — `services/{domain}/endpoints.ts` with SCREAMING_SNAKE_CASE
3. **Services** — `services/{domain}/servicesClient.ts` + `servicesServer.ts`
4. **Hooks** — `hooks/{domain}/use-{feature}.ts` with React Query
5. **Components** — `components/{domain}/` with PascalCase names, kebab-case files
6. **Route** — `app/[locale]/(workspace)/{domain}/page.tsx`
7. **Translations** — Add keys to all 4 locales (en, es, ca, fr)

## Rules
- Read existing patterns before creating anything — never assume
- kebab-case files, PascalCase components, SCREAMING_SNAKE_CASE constants
- All code in English, explanations in Spanish
- Ask before creating migrations
- Run validation after: `rubocop` / `pnpm check`
