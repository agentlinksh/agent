# Agent Link — Repo Structure

## Repository

`github.com/agentlinksh/skills`

## Directory Layout

```
agentlinksh/skills/
├── README.md                              # Manifesto (principles + architecture)
├── AGENTS.md                              # Guidance for AI agents working in this repo
├── LICENSE                                # MIT
├── .gitignore
│
├── docs/                                  # Project-level documentation (not part of any skill)
│   ├── WHY_AGENT_LINK.md                  # Origin story, naming, Zelda inspiration
│   ├── WHY_SQL.md                         # Deep dive on SQL as a Superpower
│   └── CATALOG.md                         # Full skill catalog with status and roadmap
│
└── link-backend-development/              # The skill (single entry point for all backend work)
    ├── SKILL.md                           # ~400 lines: philosophy, routing, core workflow
    ├── references/
    │   ├── naming_conventions.md          # Tables, columns, functions, indexes
    │   ├── rpc_patterns.md                # RPC-first architecture, security context
    │   ├── edge_functions.md              # Project structure, shared utilities
    │   ├── with_supabase.md               # Wrapper rules, role selection, client usage
    │   ├── workflows.md                   # Step-by-step guides for common tasks
    │   └── entities.md                    # Entity registry template
    ├── scripts/
    │   ├── scaffold_schemas.sh            # Bootstrap schema structure
    │   └── setup_vault_secrets.sh         # Store secrets in Vault
    └── assets/
        ├── check_setup.sql                # Verify infrastructure is in place
        ├── setup.sql                      # Internal utility function definitions
        ├── seed.sql                       # Vault secrets for local dev
        └── functions/
            ├── withSupabase.ts            # Core edge function wrapper
            ├── cors.ts                    # CORS handling
            ├── responses.ts               # Response helpers
            └── types.ts                   # Shared TypeScript types
```

---

## Design Decisions

### One Skill, Internal Modules

Agent Link ships as a single skill (`link-backend-development`) rather than multiple separate skills. This is an intentional decision based on how agent skill activation works in practice:

- **Agents match on descriptions at startup.** Multiple Supabase-related skills with overlapping descriptions cause activation conflicts. One broad skill with a wide-net description guarantees the right skill activates on any Supabase backend work.
- **The conditional workflow pattern handles routing.** SKILL.md stays lean and routes to domain-specific reference files based on the task type. The agent loads only the references it needs.
- **Progressive disclosure keeps context costs low.** Reference files are loaded on demand. A builder working on edge functions doesn't pay the context cost for RLS patterns.

As domains grow, new reference files are added — not new skills. If a domain eventually grows large enough to justify separation, it can be split out then.

### Naming

`link-backend-development` keeps the broad "backend development" trigger that has proven effective for agent activation, while branding it as part of Agent Link. Naming it just `supabase` or `supabase-backend` did not work as well in practice.

### Relationship to Supabase Official Skills

Supabase provides feature-focused skills (e.g., `supabase-postgres-best-practices`). Agent Link is pattern-focused — it teaches agents how to build complete applications using Supabase features together. The two are complementary:

- **Supabase skills** → "Here's how this feature works"
- **Agent Link skills** → "Here's the pattern for using these features correctly in a real application"

Agent Link references Supabase official skills where they exist and avoids duplicating feature-level documentation.

---

## Distribution

### Via skills.sh

```bash
npx skills add agentlinksh/skills
```

This installs the skill into the appropriate location for the user's agent (Claude Code, Cursor, etc.).

### Manual Installation

```bash
# Claude Code
cp -r link-backend-development ~/.claude/skills/

# Cursor
cp -r link-backend-development .cursor/skills/

# Project-level (shared with team via git)
cp -r link-backend-development .claude/skills/
```

---

## agentskills.io Compliance

The skill follows the [Agent Skills specification](https://agentskills.io/specification).

### SKILL.md Frontmatter

```yaml
---
name: link-backend-development
description: >
  Supabase backend development workflow. Use for ANY backend work in Supabase
  projects — schema changes, API endpoints, database functions, RLS policies,
  edge functions, auth, storage, business logic, or data access. Activate
  whenever the task involves server-side logic, data layer, or Supabase features.
license: MIT
compatibility: Requires Supabase CLI and Supabase MCP server
metadata:
  author: agentlink
  version: "0.1"
---
```

### Spec Requirements

| Requirement | Status |
|---|---|
| `name` matches directory name | ✅ `link-backend-development` |
| `name` max 64 chars, lowercase + hyphens | ✅ |
| `description` max 1024 chars, non-empty | ✅ |
| SKILL.md under 500 lines | ✅ Target ~400 lines |
| References one level deep | ✅ All in `references/` |
| Progressive disclosure | ✅ SKILL.md routes, references loaded on demand |

---

## Growth Path

New domains are added as reference files inside the single skill:

| Domain | Reference File | Status |
|---|---|---|
| Core workflow | `workflows.md` | ✅ Built |
| Naming conventions | `naming_conventions.md` | ✅ Built |
| RPC patterns | `rpc_patterns.md` | ✅ Built |
| Edge functions | `edge_functions.md`, `with_supabase.md` | ✅ Built |
| Entity tracking | `entities.md` | ✅ Built |
| Auth & identity | `auth_identity.md` | 🟡 To build |
| Row-level security | `row_level_security.md` | 🟡 To build |
| Cron & queues | `cron_queues.md` | 🟡 To build |
| Storage | `storage.md` | 🟡 To build |
| Realtime | `realtime.md` | 🟡 To build |
| Testing | `testing.md` | 🟡 To build |
| Multi-tenancy | `multi_tenancy.md` | 🟡 To build |