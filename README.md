# Agent Link

An opinionated way to build on Supabase with AI agents.

Agent Link is a Claude Code plugin with composable skills and an app development agent. Each skill covers a specific domain — schema development, RPCs, edge functions, auth, frontend — and Claude loads whichever skills are relevant to the current task automatically. The agent bundles all skills together with prerequisites and architecture enforcement.

---

## Install

Agent Link is a [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code/plugins). Install it at project scope so every conversation in that project has access to the skills and agent.

```bash
# Project scope (recommended) — from the marketplace when published
/install-plugin agentlink

# Local directory during development
claude --plugin-dir ./path/to/agentlink
```

---

## Usage

Describe what you want to build and tell Claude to use Agent Link. The agent handles the rest — prerequisites, architecture, and the right skills for the job.

```
Build me an uptime monitor with Supabase. Use agent link to plan.
```

```
Review my schema and suggest improvements. Use agent link.
```

```
Add a multi-tenant invitation flow to my app. Use agent link.
```

The agent auto-triggers when you mention it in your prompt. You can also call it directly with `@agentlink:app-development`.

### Use skills directly

Skills also activate automatically when Claude detects a relevant task. You can invoke them explicitly with slash commands:

- `/agentlink:database` — schema files, migrations, type generation
- `/agentlink:rpc` — RPC-first data access, CRUD templates, pagination
- `/agentlink:edge-functions` — `withSupabase` wrapper, webhooks, secrets
- `/agentlink:auth` — RLS policies, RBAC, multi-tenancy, invitation flows
- `/agentlink:frontend` — Supabase client setup, RPC calls, auth state, SSR

---

## How It Works

Skills use progressive disclosure to keep context lean:

1. **Metadata** (~100 tokens per skill) — name + description, always in context
2. **SKILL.md** — loads when a skill triggers, contains the core workflow
3. **References** — loaded on demand from SKILL.md for detailed patterns
4. **Assets** — ready-to-copy SQL and TypeScript files dropped into projects

The `@agentlink:app-development` agent preloads all domain skills and enforces prerequisites and architecture before any work begins. Individual skills can also be used standalone — Claude loads multiple skills simultaneously when a task spans domains.

---

## Agent Configuration

The app development agent ships with opinionated defaults that affect how it runs:

### Memory

The agent has persistent memory scoped to your project (`.claude/agent-memory/app-development/`). It builds knowledge across sessions — schema decisions, entity names, setup state, patterns specific to your codebase. You can:

- **Read it** to see what the agent remembers about your project
- **Edit it** to correct mistakes or add context the agent should know
- **Delete it** to start fresh
- **Commit it** to share project knowledge with your team via version control

### Blocked Commands

As a protective measure, the agent is blocked from running these destructive database commands:

- `supabase db reset` — destroys and recreates the local database
- `supabase db push --force` / `-f` — overwrites remote schema without diffing

If you need to run these, run them manually in your terminal.

### MCP Server

The agent requires a Supabase MCP server connected to `http://localhost:54321/mcp` — the native endpoint exposed by `supabase start`. During Phase 0, the agent checks if the MCP is available and guides you through configuring it in your environment (Claude Code, Cursor, Windsurf, etc.) if it isn't. All SQL execution goes through `supabase:execute_sql` — the agent never falls back to `psql`.

---

## Documentation

- **[About Agent Link](./docs/ABOUT.md)** — Principles, architecture, and design philosophy
- **[Skill Catalog](./docs/CATALOG.md)** — Full catalog with status and roadmap
- **[Website](https://agentlink.sh)** — Full manifesto, architecture overview, and waitlist

---

## Contributing

Agent Link is open source. If you've found a pattern that works, a mistake agents keep making, or a gap — we want to hear about it.

## License

MIT
