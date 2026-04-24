# Common Workflows

A flow-by-flow playbook for the scenarios users actually trigger. Each section has the same shape:

- **Trigger** — what the user says / what situation you're in
- **Questions to ask** — before running any command
- **Commands** — exact sequence to execute
- **Watch-outs** — common pitfalls

Use this as a lookup. When a user prompt matches a trigger below, follow that section end-to-end.

---

## 1. Start a new project from zero

**Trigger:** user says "I want to build a new app / SaaS / Supabase project," "start from scratch," "build me a [thing]," or is in an empty directory asking to begin.

**Questions to ask**

- **What are you building?** (A one-liner is fine — becomes the prompt passed to Claude Code.)
- **Frontend?** React + Vite (default), Next.js (`--nextjs`), or backend-only (`--no-frontend`).
- **Where?** New subdirectory (default, pass the project name) or the current directory (`.` as the name).

If the user asks to run the scaffold for them through you (agent-driven): you do NOT have browser access, so you can't complete Supabase OAuth. Use `--skip-env`.

**Commands — agent-driven (`--skip-env`)**

```bash
npx create-agentlink@latest <name> --skip-env
# or for an existing directory:
npx create-agentlink@latest . --skip-env
```

This lays down the full project — templates, schemas, config, frontend, plugin, companion skills — and installs deps. No Supabase touching. Then hand off:

> "Scaffold done. Open a terminal in `<path>` and run `agentlink env add dev` to create the Supabase project. I can't do that step — it needs a browser for OAuth."

The scaffolded `CLAUDE.md` already surfaces this as a prominent "▶ Next step" callout, so the next session of Claude Code (or a different agent) will see it immediately.

**Commands — user running directly (cloud default)**

If the user is doing it themselves in a terminal:

```bash
npx create-agentlink@latest <name>
```

The wizard prompts for Supabase login (browser OAuth), org selection, region.

**Commands — user has credentials from Supabase connector MCP**

```bash
npx create-agentlink@latest <name> --link \
  --project-ref <ref> --db-url "<url>" --api-url "<api>" \
  --publishable-key "<anon>" --secret-key "<secret>"
```

**Commands — local Docker dev (no cloud)**

```bash
npx create-agentlink@latest <name> --local
```

Requires Docker running + `psql` installed. Prompts at `agentlink.sh/start` if missing.

**Watch-outs**

- `--skip-env`, `--link`, `--local` are mutually exclusive; pass only one.
- If `claude` or `supabase` isn't on PATH, point the user at `https://agentlink.sh/start` and tell them to open a new terminal after install.
- Do NOT run any `db apply` / `db sql` / `db migrate` / `deploy` commands on a `--skip-env`-scaffolded project before the user completes `env add dev` — the env doesn't exist yet.

---

## 2. Add a production environment

**Trigger:** user says "I want to deploy to prod," "add a production env," "set up prod," "ship this live."

**Questions to ask**

- **Does the prod cloud project already exist, or should we create a new one?** The CLI asks this in the wizard, but confirming up front lets you warn about data risk for existing.
- **Same Supabase org as dev, or different?** The picker shows cached orgs + an "Authorize a different organization" option. Different-org is common when dev is in a personal org and prod is in a company org.

**Commands**

```bash
npx create-agentlink@latest env add prod
```

Interactive flow:

1. Clean-tree check (use `--allow-dirty` to bypass — rare).
2. Org picker: shows API-visible + cached orgs + "+ Authorize a different organization…"
3. "Connect existing" or "Create new" project — picks inside the chosen org.
4. Deploy prompt (default Yes) — runs the full bootstrap: migrations push, vault secrets, edge functions, PostgREST + auth config.

**Watch-outs**

- Only `dev` and `prod` are valid names for `env add`. `staging`, `dev2`, `production` will error immediately.
- `env add prod` never activates prod as the working env — prod is deploy-only. After it succeeds, the active dev env remains whatever it was before.
- If the target prod project already has data in `public` / `api` schemas, the CLI prompts a safety confirmation (default No). `--force` skips the prompt — use sparingly.
- For CI / non-interactive: `env add prod --project-ref <ref> --non-interactive`.

---

## 3. Switch active dev environment

**Trigger:** user says "work locally," "go offline," "switch to local Docker," "switch back to the cloud dev env," "use dev."

**Questions to ask**

- None usually — but if switching to `local`, confirm Docker is running.

**Commands**

```bash
npx create-agentlink@latest env use local        # Local Docker
npx create-agentlink@latest env use dev          # Cloud dev
npx create-agentlink@latest env list             # See what's configured
```

`env use` rewrites the managed block of `.env.local` so `db apply` / `supabase functions serve` / etc. hit the right env. User-added env vars outside the block are preserved.

**Watch-outs**

- `env use prod` is **blocked**. If the user asks "switch to prod," redirect: "Prod is deploy-only. Use `agentlink deploy --prod` to push changes."
- Only `local` and `dev` are valid `env use` targets (prod is blocked; anything else is off-model).
- If switching to `local`, the user still needs to run `supabase start` to bring up the Docker stack.

---

## 4. Ship changes to production

**Trigger:** user says "deploy," "push to prod," "ship it," "release."

**Questions to ask**

- **Is the working tree clean?** If not, stop and ask them to commit or stash first. The CLI enforces this, but catching it earlier saves a round-trip.
- **Dev vs prod?** `agentlink deploy` targets DEV by default. Most "deploy" requests mean prod — confirm before running.

**Commands**

```bash
# Confirm clean tree first
git status

# Dev push (default target)
npx create-agentlink@latest deploy

# Prod push
npx create-agentlink@latest deploy --prod

# Preview before shipping
npx create-agentlink@latest deploy --prod --dry-run
```

**Watch-outs**

- **Default target is `dev`, not `prod`.** If the user says "deploy" and means production, explicitly add `--prod`.
- Clean-tree gate: `deploy` aborts on a dirty tree. `--allow-dirty` bypasses (don't recommend unless the user asks). `--dry-run` skips the gate.
- Data-risk warnings (DROP TABLE, NOT NULL without DEFAULT, destructive column changes) block in interactive mode unless confirmed, and block in CI unless `--allow-warnings` is passed.
- The agent never runs `deploy`. Point the user at the command; don't execute it yourself.

---

## 5. Recover from a failed deploy / missing cloud project / wrong DB URL

**Trigger:** user says "my deploy died halfway," "env add failed," "connection refused," "cloud project was deleted," "wrong DB URL."

**Questions to ask** (decision tree)

- **Did a previous `env add` / `env relink` / `deploy` fail mid-bootstrap?** (manifest has the env but the cloud project is partially set up) → `--retry`
- **Was the cloud project deleted, or do you want to point at a different one?** → full relink (re-run `env add <name>`, pick "Relink to a different project")
- **Is the DB URL in `.env.local` stale?** (connection errors but project exists) → `db url --fix`
- **Credentials no longer accepted** (`Forbidden` / 403)? — the CLI handles this automatically on newer versions; if on older, upgrade.

**Commands**

```bash
# Recovery A: mid-bootstrap failure against the SAME project
npx create-agentlink@latest env add dev --retry
npx create-agentlink@latest env add prod --retry

# Recovery B: relink to a different project (or the project was deleted)
npx create-agentlink@latest env add dev          # interactive — pick "Relink"
npx create-agentlink@latest env add dev --project-ref <new-ref> --non-interactive

# Recovery C: stale DB URL
npx create-agentlink@latest db url               # See current vs expected
npx create-agentlink@latest db url --fix         # Rewrite .env.local with the right pooler URL

# Recovery D: broken migration state (duplicates, timestamp conflicts)
npx create-agentlink@latest db rebuild
```

**Watch-outs**

- `--retry` requires the env to already exist in the manifest — it re-runs bootstrap against the stored `projectRef` without touching the manifest or `.env.local`.
- Full relink overwrites `.env.local`'s managed block — preserved user vars outside the block survive.
- `db rebuild` deletes and regenerates migration files; safe on new projects, destructive if you've already pushed hand-edited migrations.

---

## 6. Connect an existing Supabase project without a full scaffold

**Trigger:** user already has a Supabase project (created via dashboard / via another tool) and wants AgentLink to pick it up. Or the user re-cloned the repo and needs to re-link.

**Questions to ask**

- **Is the project already scaffolded (has `agentlink.json`)?** If yes, `env add dev` is the right command. If no, use `--link` during scaffold.
- **Do you have the project ref + DB password?** `env add dev` prompts for the password interactively. `--non-interactive` expects `SUPABASE_DB_PASSWORD` in env.

**Commands**

```bash
# Already scaffolded, just need to register an env
npx create-agentlink@latest env add dev --project-ref <ref>

# Not scaffolded yet, but have all credentials
npx create-agentlink@latest <name> --link \
  --project-ref <ref> --db-url "..." --api-url "..." \
  --publishable-key "..." --secret-key "..."
```

**Watch-outs**

- If the user has a fresh scaffold from `--skip-env` and is ready to complete setup, this is exactly the `env add dev` step — no `--project-ref` needed if they want to create a new project (the wizard offers both).

---

## 7. Rotate a database password

**Trigger:** user says "I reset the DB password in the dashboard," "password changed," "`db apply` is failing with auth error."

**Questions to ask**

- None — the command does what's needed.

**Commands**

```bash
# Interactive — shows the dashboard reset link, then prompts for the new password
npx create-agentlink@latest db password

# Non-interactive
npx create-agentlink@latest db password "new-password-here"
```

**Watch-outs**

- Stores the password in `~/.config/agentlink/credentials.json` (per project ref, file mode 0600) — never in `.env.local`.
- If `.env.local`'s `SUPABASE_DB_URL` embeds the old password, run `env use <env>` or `env add <env> --retry` afterward to rewrite it.

---

## What the agent does NOT do

- **Does not deploy.** Always point users at `agentlink deploy` / `deploy --prod`.
- **Does not install tooling.** If Claude Code / Supabase CLI / psql is missing, point at `https://agentlink.sh/start`.
- **Does not create envs beyond dev/prod.** If the user asks for `staging`, explain the fixed model and ask what they actually need (usually a separate `prod` cloud project under a different org serves the "staging" role).
