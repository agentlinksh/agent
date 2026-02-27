# Agent Link — Repo Structure

## Repository

`github.com/agentlinksh/skills`

## Directory Layout

```
agentlinksh/skills/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest (name: agentlink)
├── README.md                          # Overview and installation
├── LICENSE                            # MIT
├── .gitignore
│
├── docs/                              # Project-level documentation
│   ├── WHY_AGENT_LINK.md             # Origin story, naming, Zelda inspiration
│   ├── WHY_SQL.md                    # Deep dive on SQL as a Superpower
│   ├── CATALOG.md                    # Full skill catalog with status and roadmap
│   └── REPO_STRUCTURE.md            # This file
│
└── skills/                            # All skills live here
    ├── backend-development/           # Schema-driven dev workflow
    │   ├── SKILL.md
    │   ├── references/
    │   │   ├── setup.md              # Project setup, extensions, vault secrets
    │   │   ├── development.md        # Dev loop, migrations, examples
    │   │   └── naming_conventions.md # Tables, columns, functions, indexes
    │   ├── assets/
    │   │   ├── check_setup.sql       # Verify infrastructure
    │   │   ├── setup.sql             # Internal utility functions
    │   │   ├── seed.sql              # Vault secrets for local dev
    │   │   └── entities.md           # Entity registry template
    │   └── scripts/
    │       ├── scaffold_schemas.sh   # Bootstrap schema structure
    │       └── setup_vault_secrets.sh
    │
    ├── rpc/                           # RPC-first data access
    │   ├── SKILL.md
    │   └── references/
    │       └── rpc_patterns.md       # CRUD, pagination, search, batch, errors
    │
    ├── edge-functions/                # Edge functions + withSupabase
    │   ├── SKILL.md
    │   ├── references/
    │   │   ├── edge_functions.md     # Structure, secrets, config, CORS
    │   │   ├── with_supabase.md      # Wrapper rules, allow types, clients
    │   │   └── api_key_migration.md  # Legacy → new API keys
    │   └── assets/
    │       └── functions/
    │           ├── withSupabase.ts    # Core wrapper
    │           ├── cors.ts           # CORS headers
    │           ├── responses.ts      # Response helpers
    │           └── types.ts          # Shared types
    │
    └── auth/                          # Auth, RLS, multi-tenancy
        ├── SKILL.md
        ├── references/
        │   ├── auth.md               # Auth flows, OAuth, sessions
        │   └── rls_patterns.md       # RLS policies, RBAC, tenancy
        └── assets/
            ├── profile_trigger.sql   # Auto-create profile on sign-up
            ├── tenant_tables.sql     # Tenants, memberships, invitations
            └── common_policies.sql   # Reusable RLS policy templates
```

---

## Design Decisions

### Plugin Architecture

Agent Link ships as a Claude Code plugin (`agentlink`). Skills are namespaced under `agentlink:` — e.g., `/agentlink:backend-development`, `/agentlink:auth`.

### Composable Skills

Each domain has its own skill with a focused description. Claude loads multiple skills simultaneously when a task spans domains — a request like "add a new entity with RLS and an edge function" triggers `backend-development`, `rpc`, `auth`, and `edge-functions` together.

This replaced the earlier single-skill architecture because:
- **Focused descriptions trigger more reliably** than one broad catch-all
- **Context stays lean** — each skill loads only its own references
- **Plugin namespacing prevents conflicts** — no need for `link-` prefixes

### Schema Isolation

The `api` schema is the only schema exposed via the Data API. Tables live in `public` and are invisible to clients. This enforces the RPC-first pattern at the infrastructure level — `supabase.from('table')` literally doesn't work.

### Relationship to Supabase Official Skills

Supabase provides feature-focused skills (e.g., `supabase-postgres-best-practices`). Agent Link is pattern-focused — it teaches agents how to build complete applications using Supabase features together. The two are complementary:

- **Supabase skills** → "Here's how this feature works"
- **Agent Link skills** → "Here's the pattern for using these features correctly in a real application"

---

## Distribution

### As a Claude Code Plugin

```bash
# Install from marketplace (when published)
/plugin install agentlink

# Or load from local directory during development
claude --plugin-dir ./path/to/agentlinksh/skills
```

### Manual Installation

```bash
# Copy all skills at once
cp -r skills/* ~/.claude/skills/

# Or individual skills
cp -r skills/auth ~/.claude/skills/
```
