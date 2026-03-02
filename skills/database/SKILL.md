---
name: database
description: Schema files, migrations, and type generation for Supabase Postgres. Use when the task involves creating or modifying tables, columns, indexes, triggers, RLS policies, or database functions. Activate whenever the task touches supabase/schemas/, supabase/migrations/, or involves structural database changes.
license: MIT
compatibility: Requires Supabase CLI, psql, and Supabase MCP server
metadata:
  author: agentlink
  version: "0.1"
---

# Database

Schema files, migrations, and type generation. Architecture and core rules are in the builder agent.

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
- `extensions.*` — All Postgres extensions. Always `CREATE EXTENSION ... WITH SCHEMA extensions`
- Never create tables in `api` — it contains functions only

---

## Development Loop

1. **Write SQL** to the appropriate schema file (see organization above)
2. **Apply live** — Run the same SQL via `psql`
3. **Fix errors** with more SQL — never reset the database
4. **Iterate** until the feature is complete

> **Companion:** If `supabase-postgres-best-practices` is available, invoke it to review schema changes before proceeding.

5. **Generate types** — `supabase gen types typescript --local > src/types/database.ts`
6. **Create migration** — `supabase db diff --use-pg-delta -f descriptive_migration_name`

> **📝 Load [Development](./references/workflow.md) for the full workflow, error handling, and worked examples (new entity, new field, triggers).**

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

## Troubleshooting

If something is missing or broken, the CLI can fix it:

| Issue | Fix |
|-------|-----|
| Missing `_internal_*` functions | `npx create-agentlink check` — re-runs setup validation and fixes missing components |
| Missing extensions (`pg_net`, `supabase_vault`) | `npx create-agentlink check` |
| Missing vault secrets | `npx create-agentlink check` |
| Missing `api` schema or grants | `npx create-agentlink check` |
| Missing `supabase/schemas/` structure | `npx create-agentlink@latest` in project directory |

---

## Reference Files

- **[📝 Development](./references/workflow.md)** — Development loop, migration workflow, worked examples
- **[📋 Naming Conventions](./references/naming_conventions.md)** — Tables, columns, functions, schema files

