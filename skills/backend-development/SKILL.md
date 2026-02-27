---
name: backend-development
description: Supabase schema-driven development workflow. Use when the task involves creating or modifying database tables, columns, indexes, triggers, migrations, schema files, project setup, or scaffolding a new Supabase project. Also use for database infrastructure like extensions, vault secrets, seed files, or type generation. Activate whenever the task touches supabase/schemas/, supabase/migrations/, or involves structural database changes.
license: MIT
compatibility: Requires Supabase CLI and Supabase MCP server
metadata:
  author: agentlink
  version: "0.1"
---

# Schema-Driven Development

Every structural database change goes to a schema file AND the live database simultaneously. Schema files are the source of truth. The live database is the working copy. Both must always reflect the same state.

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

This enforces the RPC-first pattern at the infrastructure level: `supabase.from('charts').select()` is not just discouraged — it literally doesn't work because the table isn't exposed.

---

## Phase 0: Setup Verification (run once per project)

Before starting any backend work, verify the project's infrastructure is in place.

**1. Verify Supabase MCP** — Confirm the `supabase` MCP server is connected. The skill depends on `supabase:execute_sql` and `supabase:apply_migration`.

**2. Run the setup check** — Load [`assets/check_setup.sql`](./assets/check_setup.sql) and execute it via `supabase:execute_sql`. If `"ready": true` → skip to the development loop.

**3. Fix what's missing** — Load [Setup Guide](./references/setup.md) and follow the steps for any `false` values (extensions, api schema, internal functions, vault secrets, seed file).

---

## Schema File Organization

```
supabase/schemas/
├── 00_schemas/              # Schema creation + grants
│   └── api.sql              # CREATE SCHEMA api; + role grants
├── 20_tables/               # Tables (public schema)
│   └── charts.sql
├── 40_indexes/              # Indexes
│   └── charts.sql
├── 50_functions/            # Non-client functions (public schema)
│   ├── _auth/               # RLS policy helpers (SECURITY DEFINER)
│   │   └── chart.sql
│   └── _internal/           # Utility functions (SECURITY DEFINER)
│       └── secrets.sql
├── 55_api/                  # Client-facing RPCs (api schema)
│   └── chart.sql            # api.chart_create, api.chart_get_by_id
├── 60_triggers/             # Triggers
│   └── charts.sql
└── 70_policies/             # RLS policies
    └── charts.sql
```

**Why numbered folders:** The numbers define execution order for fresh setups — schemas before tables, tables before indexes, functions before triggers, triggers before policies.

**Which schema for what:**
- `api.*` — Client-facing RPCs (the only things exposed via the Data API)
- `public.*` — Tables, `_auth_*` functions, `_internal_*` functions, triggers
- Never create tables in `api` — it contains functions only

---

## Development Loop

1. **Write SQL** to the appropriate schema file (see organization above)
2. **Apply live** — Run the same SQL via `supabase:execute_sql`
3. **Fix errors** with more SQL — never reset the database
4. **Iterate** until the feature is complete
5. **Generate types** — `supabase gen types typescript --local > src/types/database.ts`
6. **Create migration** — `supabase db diff -f descriptive_migration_name`

> **📝 Load [Development](./references/development.md) for the full workflow, error handling, and worked examples (new entity, new field, triggers).**

The database is **never** reset unless the user explicitly requests it.

---

## Naming Conventions (summary)

| Object | Pattern | Example |
|--------|---------|---------|
| Tables | plural, snake_case | `charts`, `user_profiles` |
| Columns | singular, snake_case | `user_id`, `created_at` |
| Client RPCs | `api.{entity}_{action}` | `api.chart_create`, `api.chart_get_by_id` |
| Auth functions | `_auth_{entity}_{check}` | `_auth_chart_can_read` |
| Internal functions | `_internal_{name}` | `_internal_get_secret` |
| Indexes | `idx_{table}_{columns}` | `idx_charts_user_id` |
| Policies | descriptive English | `"Users can read own charts"` |
| Triggers | `trg_{table}_{event}` | `trg_charts_updated_at` |

> **📋 Load [Naming Conventions](./references/naming_conventions.md) for the full reference.**

---

## Reference Files

- **[🛠️ Setup Guide](./references/setup.md)** — Phase 0 walkthrough: extensions, api schema, internal functions, vault secrets, seed file
- **[📝 Development](./references/development.md)** — Development loop, migration workflow, worked examples
- **[📋 Naming Conventions](./references/naming_conventions.md)** — Tables, columns, functions, schema files

## Assets

- **[🔍 Setup Check](./assets/check_setup.sql)** — Verify infrastructure is in place
- **[⚙️ Internal Functions](./assets/setup.sql)** — `_internal_get_secret`, `_internal_call_edge_function`
- **[🌱 Seed Template](./assets/seed.sql)** — Vault secrets for local dev
- **[📊 Entity Registry](./assets/entities.md)** — Track entities and schema files

## Scripts

- **[scaffold_schemas.sh](./scripts/scaffold_schemas.sh)** — Bootstrap schema directory structure
- **[setup_vault_secrets.sh](./scripts/setup_vault_secrets.sh)** — Store secrets in Vault
