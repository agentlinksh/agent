# Agent Link — Skill Catalog

Skills that equip AI agents to build correctly on Supabase. Each skill is a composable, self-contained package — agents load one or several simultaneously depending on the task.

---

## Architecture

**Schema isolation** — The `public` schema is not exposed via the Data API. All client-facing operations go through functions in a dedicated `api` schema. Tables, internal functions, and auth helpers live in `public`, invisible to the REST API. This enforces the RPC-first pattern at the infrastructure level.

**Composable skills** — Each skill has a focused description. Claude loads whichever skills are relevant to the current task and coordinates them automatically. A task like "add a new entity with RLS and an edge function" loads three skills at once, each contributing its domain.

**Progressive disclosure** — Only name + description are always in context (~100 tokens per skill). SKILL.md loads when triggered. References load on demand from SKILL.md. Context cost stays low.

---

## Beta Skills

### 🔧 link-backend-development

> Schema-driven development. How to set up, build, and evolve a Supabase database.

**Status:** 🟡 Restructuring (content exists, needs schema isolation + new SKILL.md)

**Owns:** Project setup, schema file organization, development loop (write SQL + apply live), migration workflow, type generation, naming conventions, `api` schema creation and grants.

**Core opinions:**
- All structural changes go to schema files, never direct SQL only
- Schema files are the source of truth, the live database is the working copy
- `api` schema for client-facing functions, `public` for tables and internals
- Supabase MCP (`execute_sql`, `apply_migration`) is the primary tooling
- The database is never reset unless the user explicitly requests it

**References:** `setup.md`, `development.md`, `naming_conventions.md`, `schema_organization.md`
**Assets:** `check_setup.sql`, `setup.sql`, `seed.sql`, `entities.md`, `scaffold_schemas.sh`

---

### 📡 link-rpc

> RPC-first data access. Every client operation is a function in the `api` schema.

**Status:** 🟡 Expanding (foundation exists in `rpc_patterns.md`, needs CRUD templates + pagination + error handling)

**Owns:** Client-facing functions (`api` schema), CRUD templates, pagination, search/filtering, input validation, error handling, return types, multi-table operations, batch operations.

**Core opinions:**
- All client data access goes through `api.` functions — no direct table queries, no views
- SECURITY INVOKER by default — RLS handles access control
- SECURITY DEFINER only for `_auth_*` (RLS helpers) and `_internal_*` (elevated access)
- Functions are your API — name them like endpoints: `create`, `get_by_id`, `list`, `update`, `delete`
- Input validation happens inside the function, not in the frontend
- Return `jsonb` with a consistent structure

**References:** `rpc_patterns.md` (expanded)
**Assets:** SQL templates for CRUD, pagination helpers

---

### ⚡ link-edge-functions

> Edge functions with the `withSupabase` wrapper. External integrations, webhooks, and service-to-service calls.

**Status:** ✅ Ready (extract from current skill, write new SKILL.md)

**Owns:** Edge function project structure, `withSupabase` wrapper, shared utilities (CORS, responses), `config.toml` setup, secrets management, API key migration.

**Core opinions:**
- Edge Functions are for external integrations — not for CRUD, not for business logic
- Every function uses the `withSupabase` wrapper with explicit allow declaration
- `verify_jwt = false` always — the wrapper handles auth
- `SB_PUBLISHABLE_KEY` and `SB_SECRET_KEY` must be configured as secrets
- One function per integration concern

**References:** `edge_functions.md`, `with_supabase.md`, `api_key_migration.md`
**Assets:** `withSupabase.ts`, `cors.ts`, `responses.ts`, `types.ts`

---

### 🔐 link-auth

> Authentication, authorization, and tenant isolation. Who can access what, enforced by the database.

**Status:** 🔴 To Build (largest new content need)

**Owns:** Supabase Auth patterns, profile creation, RLS policies, `_auth_*` functions, multi-tenancy model, RBAC, JWT custom claims, tenant isolation, invitation flows.

**Core opinions:**
- Supabase Auth is the single identity provider
- `auth.uid()` and `auth.jwt()` are the source of truth — never trust client-sent user IDs
- RLS is always enabled, but it's defense-in-depth — the `api` schema is the primary access boundary
- `_auth_*` functions support RLS policies and live in `public` (not exposed to clients)
- Multi-tenancy uses shared database + `tenant_id` column + JWT custom claims
- Profile data goes in a `profiles` table, not in auth metadata

**References:** `auth.md` (new), `rls_patterns.md` (new)
**Assets:** Profile trigger SQL, tenant/membership table templates, common RLS policy templates

---

## Future Skills

### 📊 link-analytics

> Flexible read access for dashboards, reports, and data exploration.

**Status:** 📋 Planned

**Owns:** Views in the `api` schema, materialized views for performance, aggregate functions, reporting patterns, dashboard query optimization.

**Core opinions:**
- Views in `api` are the right pattern for analytics — flexible filtering, sorting, and pagination via PostgREST
- Materialized views for expensive aggregations, refreshed on schedule
- RLS applies through views — tenant isolation is automatic
- Separate from the app dev pattern (RPCs) by design — different access patterns, different tradeoffs

**Why separate:** App development uses RPCs for full control over every query. Analytics needs flexible ad-hoc access. These are different use cases with different tradeoffs — views shine here, RPCs don't.

---

### ⏰ link-cron

> Scheduled jobs and async task processing, powered by Postgres.

**Status:** 📋 Planned

**Owns:** `pg_cron` scheduled jobs, async task queues (`pgmq` or custom), retry/backoff, dead-letter handling, database-triggered edge function calls.

---

### 📁 link-storage

> File storage with tenant-scoped access control.

**Status:** 📋 Planned

**Owns:** Bucket configuration, upload flows, storage RLS policies, signed URLs, image transformations, file organization.

---

### 📢 link-realtime

> Live updates, presence, and broadcast.

**Status:** 📋 Planned

**Owns:** Table change subscriptions, presence channels, broadcast patterns, channel authorization, reconnection handling.

---

### 🧪 link-testing

> Prove it works. Test RPCs, RLS policies, and edge functions.

**Status:** 📋 Planned

**Owns:** RLS policy testing, RPC function testing, edge function integration testing, tenant isolation verification, seed data strategies.

---

## Build Order (Beta)

```
1. link-edge-functions   ✅ Ready    → extract + new SKILL.md
2. link-backend-development  🟡      → restructure + schema isolation
3. link-rpc              🟡          → expand rpc_patterns.md significantly
4. link-auth             🔴          → mostly new content
```

---

## Skill Structure

Each skill follows the [Agent Skills specification](https://agentskills.io/specification):

```
skill-name/
├── SKILL.md              # Frontmatter (name, description) + core instructions
├── references/           # Loaded on demand from SKILL.md
│   └── *.md
├── assets/               # Ready-to-copy code and SQL
│   └── ...
└── scripts/              # Executable utilities
    └── ...
```

SKILL.md stays under 500 lines. References are loaded only when the agent needs them. Assets are copied into the user's project when used.
