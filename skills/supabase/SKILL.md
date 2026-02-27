---
name: supabase-development
description: Supabase development. Use for ANY backend work in Supabase projects — schema changes, database functions, RLS policies, API endpoints, edge functions, auth, multi-tenancy, or data access. Activate whenever the task involves Supabase features.
license: MIT
compatibility: Requires Supabase CLI and Supabase MCP server
metadata:
  author: agentlink
  version: "0.1"
---

# Supabase Development

Entrypoint for all Supabase backend work. Enforce prerequisites before any database access, follow the architecture below, and load the right specialized skills for each task.

## Phase 0: Prerequisites

**Do not call `supabase:execute_sql` or any MCP tool until step 1 passes.** The MCP server may be connected to a different project's database.

**1. Verify local stack is running** — Run `supabase status` from the project root (bash, not MCP). This confirms the CLI is installed AND the local database is running for this project.

If it fails:
- **CLI not found** — the user must install the Supabase CLI
- **No `supabase/` directory** — run `supabase init` then `supabase start`
- **Stack not running** — run `supabase start`

**2. Verify Supabase MCP** — Confirm the `supabase` MCP server is connected. Required tools: `supabase:execute_sql`, `supabase:apply_migration`.

**3. Run the setup check** — Load the `database` skill and run its setup check (`assets/check_setup.sql`) via `supabase:execute_sql`. If `"ready": true` — proceed to development.

---

## Architecture: Schema Isolation

The `public` schema is **not** exposed via the Supabase Data API. All client-facing operations go through functions in a dedicated `api` schema:

```
api schema (exposed to Data API)
└── Functions only — the client's entire surface area
    ├── chart_create()
    ├── chart_get_by_id()
    └── chart_list_by_user()

public schema (NOT exposed — invisible to REST API)
├── Tables — charts, readings, profiles, ...
├── _auth_* functions — RLS policy helpers
└── _internal_* functions — vault, edge function calls
```

`supabase.from('charts').select()` literally doesn't work — the table isn't exposed. All data access goes through `supabase.rpc()`.

---

## Skills

Load the relevant skills based on the task. Multiple skills can be active simultaneously.

| Skill | Use when the task involves |
|-------|---------------------------|
| **database** | Tables, columns, indexes, triggers, migrations, schema files, type generation |
| **rpc** | Client-facing functions (`api.*`), CRUD, pagination, search, batch operations |
| **auth** | RLS policies, `_auth_*` functions, multi-tenancy, profiles, roles, invitations |
| **edge-functions** | Edge functions, external integrations, webhooks, `withSupabase` wrapper |

For a typical "build a new feature" task, load **database** + **rpc** + **auth** together.

---

## Core Rules

### Client-side: never direct table access

```typescript
// ❌ WRONG
const { data } = await supabase.from("charts").select("*");

// ✅ CORRECT
const { data } = await supabase.rpc("chart_create", { p_name: "My Chart" });
```

### Security context: SECURITY INVOKER by default

```sql
-- ✅ CORRECT — RLS handles access control automatically
CREATE FUNCTION api.chart_get_by_id(p_chart_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  SELECT ... FROM public.charts WHERE id = p_chart_id; -- RLS enforces permissions
END; $$;
```

**SECURITY DEFINER only when required:**
- `_auth_*` functions called by RLS policies (bypass RLS to query the table they protect)
- `_internal_*` utility functions that need elevated access (vault secrets, auth.users)
- Always document WHY: `-- SECURITY DEFINER: required because ...`

### Function prefixes

| Type | Pattern | Security |
|------|---------|----------|
| Client RPCs | `api.{entity}_{action}` | INVOKER |
| Auth (RLS) | `_auth_{entity}_{check}` | DEFINER |
| Internal | `_internal_{name}` | DEFINER |
