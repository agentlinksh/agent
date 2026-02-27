# Agent Link

An opinionated way to build on Supabase with AI agents.

Agent Link is a Claude Code plugin with composable skills and a Supabase development agent. Each skill covers a specific domain — schema development, RPCs, edge functions, auth — and Claude loads whichever skills are relevant to the current task automatically. The agent bundles all skills together with prerequisites and architecture enforcement.

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

Once installed, you have two ways to use it:

### Call the agent

Type `@agentlink:supabase` in the Claude Code prompt to start the Supabase development agent. It enforces prerequisites (CLI installed, local stack running, MCP connected), loads architecture rules, and preloads all four domain skills — ready to build.

### Use skills directly

Skills activate automatically when Claude detects a relevant task. You can also invoke them explicitly with slash commands:

- `/agentlink:database` — schema files, migrations, type generation
- `/agentlink:rpc` — RPC-first data access, CRUD templates, pagination
- `/agentlink:edge-functions` — `withSupabase` wrapper, webhooks, secrets
- `/agentlink:auth` — RLS policies, RBAC, multi-tenancy, invitation flows

---

## How It Works

Skills use progressive disclosure to keep context lean:

1. **Metadata** (~100 tokens per skill) — name + description, always in context
2. **SKILL.md** — loads when a skill triggers, contains the core workflow
3. **References** — loaded on demand from SKILL.md for detailed patterns
4. **Assets** — ready-to-copy SQL and TypeScript files dropped into projects

The `@agentlink:supabase` agent preloads all four domain skills and enforces prerequisites and architecture before any work begins. Individual skills can also be used standalone — Claude loads multiple skills simultaneously when a task spans domains.

---

## Documentation

- **[About Agent Link](./docs/ABOUT.md)** — Principles, architecture, and design philosophy
- **[Skill Catalog](./docs/CATALOG.md)** — Full catalog with status and roadmap

---

## Contributing

Agent Link is open source. If you've found a pattern that works, a mistake agents keep making, or a gap — we want to hear about it.

## License

MIT
