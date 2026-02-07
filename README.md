# Skills

Custom AI agent skills for my Supabase development workflow. Each skill teaches the assistant opinionated patterns and processes so it produces consistent output without repeated prompting.

## Skills

### [supabase-dev-workflow](./supabase-dev-workflow/)

Local development workflow for Supabase-backed projects. Enforces schema-driven development with an RPC-first architecture — all client data access goes through database functions, never direct table queries.

**Features:**

- Ordered schema folder structure (`10_types/` through `80_views/`) with auto-apply
- Naming conventions for all database objects
- RPC patterns with `SECURITY INVOKER` by default, `SECURITY DEFINER` only where justified
- RLS policies delegated to auth functions
- Edge function patterns with `withSupabase` wrapper, CORS, and error helpers
- Ready-to-use shared utility assets for edge functions
- Vault-based secret management and edge function invocation from SQL
- Migration workflow via `supabase db diff`
- Scaffolding script to bootstrap the schema structure in new projects

**Requires:** Supabase CLI, Supabase MCP server

## Installation

Copy or symlink a skill directory into your assistant's skills location:

```bash
cp -r supabase-dev-workflow ~/.cursor/skills/
```

Skills activate automatically when the assistant detects a relevant task.

## License

Personal development toolkit. Use at your own discretion.
