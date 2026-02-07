---
name: supabase-dev-workflow
description: Development workflow with Supabase backend. Activate when modifying database schema, creating tables, adding columns, writing RLS policies, building database functions, or implementing business logic in PostgreSQL. Use for any data layer changes including migrations, TypeScript type generation, and RPC development. Enforces RPC-first architecture where all data access uses database functions instead of direct supabase-js table calls. Triggers on - new table, new field, new function, add RLS, business logic, schema change, supabase db, execute_sql.
compatibility: Requires supabase CLI and Supabase MCP server with execute_sql tool
allowed-tools: execute_sql Bash(supabase:*)
---

# Supabase Local Dev Workflow

## Core Philosophy

1. **Schema-driven development** — all structural changes go to schema files, never direct SQL
2. **RPC-first architecture** — no direct `supabase-js` table calls; all data access through RPCs
3. **DB functions as first-class citizens** — business logic lives in the database

---

## Process

### Phase 1: Schema Changes

Write structural changes to the appropriate schema file based on the folder structure:

```
supabase/schemas/
├── 10_types/        # Enums, composite types, domains
├── 20_tables/       # Table definitions
├── 30_constraints/  # Check constraints, foreign keys
├── 40_indexes/      # Index definitions
├── 50_functions/    # RPCs, auth functions, internal utils
│   ├── _internal/   # Infrastructure utilities
│   └── _auth/       # RLS policy functions
├── 60_triggers/     # Trigger definitions
├── 70_policies/     # RLS policies
└── 80_views/        # View definitions
```

Files are organized by entity (e.g., `charts.sql`, `readings.sql`). Numeric prefixes ensure correct application order.

**📋 Load [Naming Conventions](./references/naming_conventions.md) for table, column, and function naming rules.**

### Phase 2: Apply & Fix

1. CLI auto-applies changes (`supabase start`)
2. Monitor logs for errors (constraint violations, dependencies)
3. If errors → use `execute_sql` MCP tool for data fixes only (UPDATE, DELETE, INSERT)
4. Never use `execute_sql` for schema structure — only schema files

### Phase 3: Generate Types

```bash
supabase gen types typescript --local > src/types/database.ts
```

### Phase 4: Iterate

Repeat Phases 1-3 until schema is stable and tested.

### Phase 5: Migration

1. Use `supabase db diff` to generate migration
2. Review migration — patch if manual SQL commands are missing

---

## Reference Files

Load these as needed during development:

### Conventions & Patterns
- **[📋 Naming Conventions](./references/naming_conventions.md)** — Tables, columns, functions, indexes
- **[🔐 RPC Patterns](./references/rpc_patterns.md)** — RPC-first architecture, auth functions, RLS policies
- **[⚡ Edge Functions](./references/edge_functions.md)** — withSupabase wrapper, auth, CORS, shared utilities

### Setup & Infrastructure
- **[⚙️ Setup Guide](./references/setup.sql)** — Vault secrets, internal utility functions

### Workflows
- **[📝 Common Workflows](./references/workflows.md)** — Adding entities, fields, creating RPCs

### Entity Tracking
- **[📊 Entity Registry Template](./references/ENTITIES.md)** — Track entities and schema files

---

## Tools & Dependencies

| Tool | Purpose |
|------|---------|
| Supabase CLI | Local development, type generation, migrations |
| Supabase MCP | `execute_sql` tool for data fixes |
| Edge Functions | See [Edge Functions patterns](./references/edge_functions.md) for `withSupabase` wrapper and shared utilities |

---

## Quick Reference

**Client-side rule** — Never direct table access:
```typescript
// ❌ WRONG
const { data } = await supabase.from('charts').select('*')

// ✅ CORRECT
const { data } = await supabase.rpc('chart_get_by_user', { p_user_id: userId })
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
