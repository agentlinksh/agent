# Naming Conventions

Consistent naming across all database objects.

## Contents
- Tables
- Columns
- Functions (common action verbs)
- Other Objects
- Schema File Naming

## Tables

- **Plural**, snake_case
- Examples: `charts`, `user_profiles`, `readings`, `subscriptions`

## Columns

- **Singular**, snake_case
- Primary key: `id`
- Foreign keys: `{table_singular}_id` (e.g., `user_id`, `chart_id`)
- Timestamps: `created_at`, `updated_at`
- Booleans: `is_`, `has_` prefix (e.g., `is_active`, `has_verified`)
- Soft delete: `deleted_at` (nullable timestamp)

## Functions

| Type | Pattern | Example |
|------|---------|---------|
| Business logic | `api.{entity}_{action}` | `api.chart_create`, `api.chart_get_by_id`, `api.reading_archive` |
| Auth (RLS) | `public._auth_{entity}_{check}` | `public._auth_chart_can_read`, `public._auth_reading_is_owner` |
| Internal admin | `public._internal_admin_{name}` | `public._internal_admin_get_secret`, `public._internal_admin_call_edge_function` |
| Auth hooks | `public._hook_{hook_name}` | `public._hook_before_user_created` |

### Function Actions (Common Verbs)

| Action | Use Case |
|--------|----------|
| `create` | Insert new record |
| `get_by_{field}` | Retrieve by specific field |
| `list` / `list_by_{field}` | Retrieve multiple records |
| `update` | Modify existing record |
| `delete` / `archive` | Remove or soft-delete |
| `{domain_action}` | Business operations (e.g., `close`, `assign`, `approve`) |

## Other Objects

| Object | Pattern | Example |
|--------|---------|---------|
| Indexes | `idx_{table}_{column(s)}` | `idx_charts_user_id`, `idx_readings_created_at` |
| Views | `v_{name}` | `v_active_readings`, `v_user_chart_summary` |
| Materialized Views | `mv_{name}` | `mv_daily_stats` |
| Triggers | `trg_{table}_{event}` | `trg_charts_updated_at`, `trg_readings_audit` |
| Check Constraints | `chk_{table}_{description}` | `chk_charts_valid_type` |
| Unique Constraints | `uq_{table}_{column(s)}` | `uq_users_email` |

## Schema File Naming

| Folder | File Name | Contains |
|--------|-----------|----------|
| `public/` | `{entity_plural}.sql` | `charts.sql` — table + indexes + triggers + policies |
| `public/` | `_auth_{entity}.sql` | `_auth_tenant.sql` — `_auth_*` helper functions for an entity |
| `public/` | `{related_entities}.sql` | `multitenancy.sql` — multiple related tables with FK dependencies |
| `public/` | `_internal_admin.sql` | Shared `_internal_admin_*` utility functions |
| `public/` | `_hook_{hook_name}.sql` | Supabase auth hook PG functions |
| `api/` | `{entity_singular}.sql` | `chart.sql` — `api.*` functions + grants |
| (root) | `_schemas.sql` | `CREATE SCHEMA api;` + role grants |

- `public/` files use **plural** names (match table names)
- `api/` files use **singular** names (match entity)
- `_` prefix = shared/infrastructure files
