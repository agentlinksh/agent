# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Cursor, Copilot, etc.) when working with code in this repository.

## Repository Overview

A collection of custom skills for AI coding assistants, focused on Supabase development workflows. Skills are packaged instructions, reference files, and assets that extend an agent's capabilities with opinionated patterns and conventions.

## Skill Structure

```
skills/
  {skill-name}/             # kebab-case directory name
    SKILL.md                # Required: skill definition (entry point)
    references/             # Optional: detailed reference docs loaded on demand
    scripts/                # Optional: executable helper scripts
    assets/                 # Optional: ready-to-use files to copy into projects
```

### Key Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Main skill definition with frontmatter metadata. This is the only file loaded into context when the skill activates. |
| `references/*.md` | Detailed conventions, patterns, and workflows. Loaded on demand when the agent needs deeper context. |
| `scripts/*.sh` | Bash scripts for scaffolding or automation. Executed via shell, not loaded into context. |
| `assets/` | Template files meant to be copied into the user's project (e.g., shared TypeScript utilities). |

## Creating a New Skill

### SKILL.md Frontmatter

```yaml
---
name: skill-name
description: When to activate this skill. Include trigger words and phrases.
compatibility: Required tools, CLIs, or MCP servers.
allowed-tools: Space-separated list of tools the skill needs access to.
---
```

- **`description`** — Write it for the agent, not the user. Include specific trigger phrases so the agent knows when to activate (e.g., "new table", "add RLS", "schema change").
- **`compatibility`** — List hard dependencies so the agent can warn if something is missing.
- **`allowed-tools`** — Whitelist the tools the skill is permitted to use.

### Content Guidelines

- Keep `SKILL.md` concise — it loads into context on every activation.
- Put detailed reference material in `references/` and link to it from `SKILL.md`.
- Use progressive disclosure: `SKILL.md` links to references, references link to each other.
- Prefer scripts over inline code — script execution doesn't consume context (only output does).
- Assets should be ready to copy with no modifications needed.

### Naming Conventions

- **Skill directory**: `kebab-case` (e.g., `supabase-dev-workflow`)
- **SKILL.md**: Always uppercase, always this exact filename.
- **References**: `snake_case.md` (e.g., `naming_conventions.md`, `rpc_patterns.md`)
- **Scripts**: `snake_case.sh` (e.g., `scaffold_schemas.sh`)
- **Assets**: Match the naming convention of their target ecosystem (e.g., `camelCase.ts` for TypeScript)

### Script Requirements

- Use `#!/usr/bin/env bash` shebang for portability.
- Use `set -e` for fail-fast behavior.
- Accept optional arguments with sensible defaults.
- Include a usage comment block at the top of the file.

## Installation

Skills are installed by copying or symlinking into the agent's skills directory:

```bash
# Cursor
cp -r {skill-name} ~/.cursor/skills/

# Claude Code
cp -r {skill-name} ~/.claude/skills/
```

Skills activate automatically based on their `description` trigger phrases when the agent detects a relevant task.
