# Entity Registry

Track all database entities. Update when creating or modifying schema files.

---

## Entities

| Entity | Description |
|--------|-------------|
| | |

---

## Schema Files

| Entity | Tables | Functions | Auth | Policies |
|--------|--------|-----------|------|----------|
| | `20_tables/.sql` | `50_functions/.sql` | `50_functions/_auth/.sql` | `70_policies/.sql` |

---

## Business Logic RPCs

| Entity | Function | Description |
|--------|----------|-------------|
| | | |

---

## Auth Functions

| Entity | Function | Policy |
|--------|----------|--------|
| | | |

---

## Internal Functions

| Function | Description |
|----------|-------------|
| `_internal_get_secret` | Retrieves secret from Vault by name |
| `_internal_call_edge_function` | Invokes edge function via pg_net |
| `_internal_call_edge_function_sync` | Sync version with polling |

---

## Naming Reminder

- Tables: **plural** (`charts.sql`)
- Functions: **singular** (`chart.sql`)
- Auth: `_auth/` subdirectory
