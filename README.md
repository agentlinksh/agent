# Agent Link

An opinionated way to build on Supabase with AI agents.

Agent Link is a set of composable skills that teach AI agents how to build complete applications on Supabase. Each skill covers a specific domain — schema development, RPCs, edge functions, auth — and Claude loads whichever skills are relevant to the current task automatically.

---

## Install

### As a Claude Code Plugin

```bash
# From the marketplace (when published)
/plugin install agentlink

# From a local directory during development
claude --plugin-dir ./path/to/agentlinksh/skills
```

All skills are namespaced under `agentlink:` — e.g., `/agentlink:backend-development`, `/agentlink:auth`.

### As Agent Skills

```bash
npx skills add agentlinksh/skills
```

Works with Claude Code, Cursor, Copilot, and other agents that support the [Agent Skills specification](https://agentskills.io/specification).

---

## Skills

### backend-development

Schema-driven development workflow. Project setup, schema file organization, development loop (write SQL, apply live, iterate), migration workflow, type generation, naming conventions.

### rpc

RPC-first data access. Every client operation is a function in the `api` schema — CRUD templates, pagination, search/filtering, input validation, error handling, batch operations.

### edge-functions

Edge functions with the `withSupabase` wrapper. External integrations, webhooks, service-to-service calls, secrets management, CORS, and the `config.toml` setup.

### auth

Authentication, authorization, and tenant isolation. Supabase Auth patterns, profile creation, RLS policies, RBAC, multi-tenancy model, JWT claims, invitation flows.

---

## How It Works

Skills use progressive disclosure to keep context lean:

1. **Metadata** (~100 tokens per skill) — name + description, always in context
2. **SKILL.md** — loads when a skill triggers, contains the core workflow
3. **References** — loaded on demand from SKILL.md for detailed patterns
4. **Assets** — ready-to-copy SQL and TypeScript files dropped into projects

Claude loads multiple skills simultaneously when a task spans domains. A request like "add a new entity with RLS and an edge function" triggers `backend-development`, `rpc`, `auth`, and `edge-functions` together.

---

## Documentation

- **[About Agent Link](./docs/ABOUT.md)** — Principles, architecture, and design philosophy
- **[Skill Catalog](./docs/CATALOG.md)** — Full catalog with status and roadmap

---

## Contributing

Agent Link is open source. If you've found a pattern that works, a mistake agents keep making, or a gap — we want to hear about it.

## License

MIT
