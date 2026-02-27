---
name: database
description: Schema files, migrations, and type generation for Supabase Postgres. Use when the task involves creating or modifying tables, columns, indexes, triggers, RLS policies, or database functions. Activate whenever the task touches supabase/schemas/, supabase/migrations/, or involves structural database changes.
license: MIT
compatibility: Requires Supabase CLI and Supabase MCP server
metadata:
  author: agentlink
  version: "0.1"
---

# Database

Schema files, migrations, and project setup. Prerequisites and architecture are in the `agentlink` agent.

## Setup Check

Run [`assets/check_setup.sql`](./assets/check_setup.sql) via `supabase:execute_sql`. If `"ready": true` → skip to the development loop. If anything is `false` → load [Setup Guide](./references/setup.md).

---

## Schema File Organization

```
supabase/schemas/
├── _schemas.sql              # CREATE SCHEMA api; + role grants
├── public/
│   ├── charts.sql            # table + indexes + triggers + policies (all in one)
│   ├── tenants.sql
│   ├── _auth.sql             # Shared _auth_* helper functions
│   └── _internal.sql         # Shared _internal_* utility functions
└── api/
    ├── chart.sql             # api.chart_* functions + grants
    ├── tenant.sql
    └── profile.sql
```

Files are grouped by Postgres schema (`public/`, `api/`) with entity-centric files inside. Statement ordering is handled automatically by `supabase db diff --use-pg-delta`.

**Conventions:**
- `public/` files = **plural** (match table names): `charts.sql`
- `api/` files = **singular** (match entity): `chart.sql`
- `_` prefix = shared/infrastructure: `_auth.sql`, `_internal.sql`, `_schemas.sql`
- Entity files in `public/` contain everything for that entity: table, indexes, triggers, policies

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
6. **Create migration** — `supabase db diff --use-pg-delta -f descriptive_migration_name`

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
## Scripts

- **[scaffold_schemas.sh](./scripts/scaffold_schemas.sh)** — Bootstrap schema directory structure
- **[setup_vault_secrets.sh](./scripts/setup_vault_secrets.sh)** — Store secrets in Vault
