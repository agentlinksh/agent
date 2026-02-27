# Agent Link — Skill Catalog

Skills that equip AI agents to build correctly on Supabase. Distributed as a Claude Code plugin — install once, get all skills and the Supabase development agent.

---

## Architecture

**Plugin:** `agentlink` — skills namespaced under `agentlink:`, agent available as `agentlink:supabase`.

**Schema isolation** — The `public` schema is not exposed via the Data API. All client-facing operations go through functions in a dedicated `api` schema. Tables, internal functions, and auth helpers live in `public`, invisible to the REST API. This enforces the RPC-first pattern at the infrastructure level.

**Agent + composable skills** — The `supabase` agent bundles all domain skills with prerequisites and architecture enforcement. Skills can also be used individually. A task like "add a new entity with RLS and an edge function" uses three skills at once, each contributing its domain.

**Progressive disclosure** — SKILL.md loads the core workflow. References load on demand from SKILL.md. Assets are copied into projects when used. Context cost stays low.

---

## Agent

### 🤖 supabase

> Supabase development agent. Enforces prerequisites, schema isolation, and RPC-first patterns for building on Supabase.

**Status:** ✅ Built

**Owns:** Phase 0 prerequisites (project context detection, setup routing), schema isolation architecture, RPC-first philosophy, security context rules.

**Preloads:** `database`, `rpc`, `auth`, `edge-functions`

---

## Skills

### 🔧 database

> Schema files, migrations, and project setup.

**Status:** ✅ Built

**Owns:** Schema file organization, development loop (write SQL + apply live), migration workflow, type generation, naming conventions, `api` schema creation and grants.

**References:** `setup.md`, `development.md`, `naming_conventions.md`
**Assets:** `check_setup.sql`, `setup.sql`, `seed.sql`, `scaffold_schemas.sh`

---

### 📡 rpc

> RPC-first data access. Every client operation is a function in the `api` schema.

**Status:** ✅ Built

**Owns:** Client-facing functions (`api` schema), CRUD templates, pagination, search/filtering, input validation, error handling, return types, multi-table operations, batch operations.

**References:** `rpc_patterns.md`

---

### ⚡ edge-functions

> Edge functions with the `withSupabase` wrapper. External integrations, webhooks, and service-to-service calls.

**Status:** ✅ Built

**Owns:** Edge function project structure, `withSupabase` wrapper, shared utilities (CORS, responses), `config.toml` setup, secrets management, API key migration.

**References:** `edge_functions.md`, `with_supabase.md`, `api_key_migration.md`
**Assets:** `withSupabase.ts`, `cors.ts`, `responses.ts`, `types.ts`

---

### 🔐 auth

> Authentication, authorization, and tenant isolation. Who can access what, enforced by the database.

**Status:** ✅ Built

**Owns:** Supabase Auth patterns, profile creation, RLS policies, `_auth_*` functions, multi-tenancy model, RBAC, JWT custom claims, tenant isolation, invitation flows.

**References:** `auth.md`, `rls_patterns.md`
**Assets:** `profile_trigger.sql`, `tenant_tables.sql`, `common_policies.sql`

---

## Future Skills

### 📊 analytics

> Flexible read access for dashboards, reports, and data exploration.

**Status:** 📋 Planned

**Owns:** Views in the `api` schema, materialized views for performance, aggregate functions, reporting patterns, dashboard query optimization.

**Why separate:** App development uses RPCs for full control over every query. Analytics needs flexible ad-hoc access — views in `api` with PostgREST's filtering, sorting, and pagination.

---

### ⏰ cron

> Scheduled jobs and async task processing, powered by Postgres.

**Status:** 📋 Planned

**Owns:** `pg_cron` scheduled jobs, async task queues (`pgmq` or custom), retry/backoff, dead-letter handling, database-triggered edge function calls.

---

### 📁 storage

> File storage with tenant-scoped access control.

**Status:** 📋 Planned

**Owns:** Bucket configuration, upload flows, storage RLS policies, signed URLs, image transformations, file organization.

---

### 📢 realtime

> Live updates, presence, and broadcast.

**Status:** 📋 Planned

**Owns:** Table change subscriptions, presence channels, broadcast patterns, channel authorization, reconnection handling.

---

### 🧪 testing

> Prove it works. Test RPCs, RLS policies, and edge functions.

**Status:** 📋 Planned

**Owns:** RLS policy testing, RPC function testing, edge function integration testing, tenant isolation verification, seed data strategies.

---

## Plugin Structure

```
agentlink/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (name, version, author)
├── agents/
│   └── supabase.md           # Agent — prereqs, architecture, core rules
├── skills/
│   ├── database/
│   │   ├── SKILL.md          # Schema files, migrations, setup
│   │   ├── references/
│   │   ├── assets/
│   │   └── scripts/
│   ├── rpc/
│   │   ├── SKILL.md          # RPC-first data access
│   │   └── references/
│   ├── edge-functions/
│   │   ├── SKILL.md          # withSupabase wrapper
│   │   ├── references/
│   │   └── assets/
│   └── auth/
│       ├── SKILL.md          # Auth, RLS, multi-tenancy
│       ├── references/
│       └── assets/
├── docs/
└── README.md
```

SKILL.md stays under 500 lines. References are loaded only when the agent needs them. Assets are copied into the user's project when used.
