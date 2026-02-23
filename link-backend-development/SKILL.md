---
name: link-backend-development
description: Supabase backend development workflow. Use for ANY backend work in Supabase projects — schema changes, API endpoints, database functions, RLS policies, edge functions, auth, storage, business logic, or data access. Activate whenever the task involves server-side logic, data layer, or Supabase features.
license: MIT
compatibility: Requires Supabase CLI and Supabase MCP server
metadata:
  author: agentlink
  version: "0.1"
---

# Supabase Local Dev Workflow

## Core Philosophy

1. **Schema-driven development** — all structural changes go to schema files, never direct SQL
2. **RPC-first architecture** — no direct `supabase-js` table calls; all data access through RPCs
3. **DB functions as first-class citizens** — business logic lives in the database

---

## Process

### Phase 0: Setup Verification (run once per project)

Before starting any backend work, verify the project's infrastructure is in place.

**1. Verify Supabase MCP** — Confirm the `supabase` MCP server is connected (the skill
depends on `supabase:execute_sql` and `supabase:apply_migration`).

**2. Run the setup check** — Load [`assets/check_setup.sql`](./assets/check_setup.sql) and execute it via
`supabase:execute_sql`. If `"ready": true` → skip to Phase 1.

**3. Fix what's missing** — Load [Setup](./references/setup.md) and follow the steps for
any `false` values (extensions, internal functions, vault secrets, seed file).

---

### Phases 1-5: Development Loop

1. **Schema Changes** — Write SQL to the appropriate schema file in `supabase/schemas/`
2. **Apply & Fix** — Run the same SQL against the live database via `supabase:execute_sql`; fix errors with more SQL
3. **Generate Types** — Regenerate TypeScript types after each set of changes
4. **Iterate** — Repeat until the feature is complete
5. **Migration** — Run `supabase db diff` to capture all changes as a single migration

> **📝 Load [Development](./references/development.md) for the full workflow, error handling, and examples.**
> **📋 Load [Naming Conventions](./references/naming_conventions.md) for table, column, and function naming rules.**

---

## Reference Files

Load these as needed during development:

### Conventions & Patterns

- **[📋 Naming Conventions](./references/naming_conventions.md)** — Tables, columns, functions, indexes
- **[🔐 RPC Patterns](./references/rpc_patterns.md)** — RPC-first architecture, auth functions, RLS policies
- **[⚡ Edge Functions](./references/edge_functions.md)** — Project structure, shared utilities, CORS, error helpers
- **[🔧 withSupabase Wrapper](./references/with_supabase.md)** — Wrapper rules, allow selection, client usage patterns

### Setup & Infrastructure

- **[🔍 Setup Check](./assets/check_setup.sql)** — Verify extensions, functions, and secrets exist
- **[⚙️ Setup Guide](./assets/setup.sql)** — Internal utility function definitions
- **[🌱 Seed Template](./assets/seed.sql)** — Vault secrets for local dev (append to `supabase/seed.sql`)
- **[🔐 Vault Secrets Script](./scripts/setup_vault_secrets.sh)** — Store secrets in Vault (manual fallback)

### Workflows

- **[🛠️ Setup](./references/setup.md)** — Initial project setup, extensions, vault secrets
- **[📝 Development](./references/development.md)** — Development loop, migrations, adding entities and fields

### Entity Tracking

- **[📊 Entity Registry Template](./assets/entities.md)** — Track entities and schema files

---

## Tools & Dependencies

| Tool           | Purpose                                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| Supabase CLI   | Local development, type generation, migrations                                                                |
| Supabase MCP   | `supabase:execute_sql` tool for data fixes                                                                             |
| Edge Functions | See [Edge Functions](./references/edge_functions.md) for project structure and [withSupabase](./references/with_supabase.md) for wrapper usage |

---

## Quick Reference

**Client-side rule** — Never direct table access:

```typescript
// ❌ WRONG
const { data } = await supabase.from("charts").select("*");

// ✅ CORRECT
const { data } = await supabase.rpc("chart_get_by_user", { p_user_id: userId });
```

**Security context rule** — SECURITY INVOKER by default:

```sql
-- ❌ WRONG — bypasses RLS then reimplements filtering manually
CREATE FUNCTION chart_get_by_id(p_chart_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  SELECT ... FROM public.charts WHERE id = p_chart_id AND user_id = auth.uid(); -- manual filter = fragile
END; $$;

-- ✅ CORRECT — RLS handles access control automatically
CREATE FUNCTION chart_get_by_id(p_chart_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  SELECT ... FROM public.charts WHERE id = p_chart_id; -- RLS enforces permissions
END; $$;
```

**When to use SECURITY DEFINER (rare exceptions):**

- `_auth_*` functions called by RLS policies (they run during policy evaluation, need to bypass RLS to query the table they protect)
- `_internal_*` utility functions that need elevated access (e.g., reading vault secrets)
- Multi-table operations that need cross-table access the user's role can't reach
- Always document WHY with a comment: `-- SECURITY DEFINER: required because ...`

**Function prefixes:**

- Business logic: `{entity}_{action}` → `chart_create` (SECURITY INVOKER)
- Auth (RLS): `_auth_{entity}_{check}` → `_auth_chart_can_read` (SECURITY DEFINER — needed by RLS)
- Internal: `_internal_{name}` → `_internal_get_secret` (SECURITY DEFINER — elevated access)
