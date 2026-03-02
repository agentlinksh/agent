# Changelog

## [0.6.0] - 2026-03-01

The agent no longer sets up your project — the CLI does. This is a fundamental shift in how Agent Link works: infrastructure setup (`npx create-agentlink`) runs once in seconds, and the agent spends zero tokens verifying prerequisites, copying asset files, or scaffolding directories. Every token goes toward building your app.

This aligns with the Agent Link philosophy: **tools for agents, not agents as tools.** The CLI is purpose-built tooling that gives the agent a ready environment. The agent is a builder that assumes a working environment and gets to work. Each does what it's best at.

### Added

- `npx create-agentlink check` — CLI validation command for setup issues (extensions, internal functions, vault secrets, api schema)
- CORS headers now imported from `@supabase/supabase-js/cors` (SDK v2.95.0+) — no more local `cors.ts` file

### Changed

- **Agent no longer runs Phase 0 prerequisites** — CLI handles all project setup and validation. The agent builds, it does not scaffold.
- Replace `execute_sql` MCP tool with `psql` across all skills — direct SQL execution via DB URL from `supabase status`
- Tools reference table added to builder agent for quick lookup
- Update `withSupabase` references to match latest implementation — trailing commas, `Record<string, unknown>` context types, client reuse pattern documented
- Simplify README agent configuration section

### Removed

- **Database assets** — `setup.sql`, `check_setup.sql`, `seed.sql` (now CLI-owned)
- **Edge function assets** — `withSupabase.ts`, `cors.ts`, `responses.ts`, `types.ts` (now CLI-owned)
- **`cors.ts` as a shared utility** — replaced by SDK import `@supabase/supabase-js/cors`
- Phase 0 prerequisite system from builder agent (setup.md, scaffold_schemas.sh, setup_vault_secrets.sh)
- `auth.md` reference file (to be rewritten)
- `frontend` skill from builder agent preloads
- `docs/` directory (ABOUT.md, CATALOG.md)
- Agent memory configuration (`memory: project`)
- First migration rule (CLI creates api schema)

## [0.5.0] - 2026-02-28

### Changed

- Update README Install section with real installation methods — CLI (`npx create-agentlink@latest`), marketplace, and local directory

## [0.4.1] - 2026-02-28

### Changed

- Rename `app-developer` agent to `builder`
- Refine Path C detection — bare `supabase init` (no schema files) now routes to Path B instead of skipping to Step 2
- Path B expanded to cover both "existing project adding Supabase" and "Supabase initialized but bare" cases

## [0.4.0] - 2026-02-28

### Added

- Schema-qualify rule — all SQL must use fully-qualified names (`public.charts`, not `charts`)
- Database workflow rules in agent core — schema files as source of truth, first migration must create `api` schema, migration naming via `db diff`
- Plan-first instruction — agent plans before building greenfield projects and major features
- Marketplace manifest (`marketplace.json`)

### Changed

- Agent activates by default via `settings.json` — no need to `@mention` it
- Granular Phase 0 prerequisite tracking — each item saved to memory individually (`cli_installed`, `stack_running`, `mcp_connected`, `setup_check`)
- Grant `service_role` USAGE on `api` schema and set `db: { schema: "api" }` on all Supabase clients in `withSupabase.ts`
- Standardize skill references to "Load the `X` skill for..." pattern

### Removed

- ENTITIES.md — entity registry file and all references (scaffold script, workflow examples)
- Companion skills section from agent — was not picked up reliably, wasted context
- `companions_offered` prerequisite step

## [0.3.0] - 2026-02-27

### Added

- Recommended Companions section in CATALOG.md — curated community skills that enhance Agent Link workflows (supabase-postgres-best-practices, frontend-design, vercel-react-best-practices, next-best-practices, resend-skills, email-best-practices, react-email)
- CHANGELOG.md

## [0.2.0] - 2026-02-27

### Changed

- Rename `development.md` to `workflow.md` — clearer name for the write-apply-migrate workflow
- Rename `app-development` agent to `app-developer` — agent names should be roles, not activities
- Bump plugin version to 0.2.0
- Remove redundant `hooks` field from plugin manifest (auto-loaded by convention)

### Fixed

- Fix RPC "not found" errors: add schema grants and client schema option
- Make MCP setup editor-agnostic (Claude Code, Cursor, Windsurf)
- Fix extension schema references
- Inline SQL apply in examples, block db reset via hook

### Added

- Natural language usage examples in README
- Block `supabase db reset` via PreToolUse hook (was only in skill text before)

### Removed

- Remove `bypassPermissions` from agent config

## [0.1.0] - 2026-02-26

Initial release as a Claude Code plugin.

### Added

- **Plugin structure** — `.claude-plugin/plugin.json` manifest, hooks, skills, agents
- **App developer agent** — Phase 0 prerequisites, architecture enforcement, preloads all domain skills
- **Database skill** — Schema file organization, write-apply-migrate workflow, migration generation, type generation, naming conventions
- **RPC skill** — RPC-first data access, CRUD templates, pagination, search, input validation, error handling
- **Edge functions skill** — `withSupabase` wrapper, CORS utilities, secrets management, `config.toml` setup
- **Auth skill** — RLS policies, `_auth_*` functions, multi-tenancy, RBAC, invitation flows
- **Frontend skill** — Supabase client initialization, `supabase.rpc()` usage, auth state, SSR
- **Schema isolation** — `public` schema not exposed via Data API; all client access through `api` schema RPCs
- **PreToolUse hook** — Blocks `supabase db reset` and `supabase db push --force`
- **Progressive disclosure** — SKILL.md core workflows, references on demand, assets copied into projects
- **Documentation** — ABOUT.md (philosophy), CATALOG.md (full skill catalog and roadmap), README
