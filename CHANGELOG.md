# Changelog

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
