# About Agent Link

**An opinionated way to build on Supabase with AI agents.**

---

## Principles

What we believe. These shape every decision in Agent Link and help you decide if it's right for you.

### Agent-First

Every pattern is optimized for agents to get it right on the first try.

Skills are not documentation. Documentation says "here's what you can do." A skill says "here's what you should do, and here's the code to do it." One clear path, no ambiguity, no "choose your own adventure." The difference matters when the one reading it is an agent making decisions on your behalf.

### SQL as a Superpower

The reason we moved away from SQL in the first place no longer applies.

SQL was hard. Writing it, maintaining it, debugging it at scale — it was hard for us. So we built layers on top. ORMs, backend frameworks, migration tools — all designed to put distance between us and the database. And for a long time, that made sense. But agents don't share our limitations. They write SQL fluently. They generate and maintain migrations, catch schema diffs, and reason about database structures with a speed and accuracy that surpasses what we could do on our own. The abstraction layer that was helping us was actually adding complexity for them. More files, more configuration, more things to get wrong. Going RPC-first isn't a step backward — it's the natural path forward.

### Tools over Abstractions

We don't hide complexity from agents. We give them better tools to handle it.

Agents are getting smarter and faster. They merge commits, catch schema diffs, and write proper migrations with a speed and accuracy we couldn't match — which is exactly why we built abstractions in the first place. The bet here is that agent capabilities will keep increasing, so instead of dumbing down the work, we sharpen the inputs. CLIs that output clean diffs, MCP servers that expose the right context, utilities that do the heavy computation — these give agents what they need to make the right decision faster and cheaper, without hiding what's actually happening. Every pattern should ask: can we give the agent a tool that makes this faster, instead of an abstraction that makes it simpler?

### Built for Business

Designed for internal tools, business software, and operational applications.

The kind of software that companies run on — dashboards, workflows, CRMs, admin panels, back-office systems. This won't fit every use case, and that's intentional. By narrowing the focus, every pattern can be specific, practical, and immediately useful for the kind of applications where getting it right matters most.

Every pattern assumes multi-tenancy from day one. RLS policies, data isolation, tenant-scoped queries — it's all baked in from the start. If you only have one tenant, everything still works. But you never have to rearchitect when your second tenant shows up.

### Opinionated by Design

We renounce flexibility to give agents fixed patterns that produce reliable outcomes.

Supabase offers many valid ways to do things. That flexibility is powerful in the hands of an experienced engineer. But when an agent is making decisions, options become risk. Every fork in the road is a chance to take the wrong path.

Agent Link picks the path. One way to do auth. One way to structure RLS. One way to handle async work. Not because it's the only way — but because it's a way that works, every time, without human intervention.

---

## Architecture

How Agent Link applications are built. These are the technical decisions baked into every pattern.

### Schema Isolation

The `public` schema is not exposed via the Data API. All client-facing operations go through functions in a dedicated `api` schema. Tables, internal functions, and auth helpers live in `public`, invisible to the REST API. This enforces the RPC-first pattern at the infrastructure level — `supabase.from('table')` literally doesn't work.

### RPC-First

Your database is your backend. Business logic lives in Postgres functions in the `api` schema, exposed as RPCs through Supabase's auto-generated API. One backend serves every frontend — web, mobile, desktop, other agents.

No ORM. No middleware. Your database does the heavy lifting because it's the best tool for the job.

### Edge Functions for the Outside World

Edge Functions exist for one purpose: integrating with external systems. Webhooks, third-party APIs, payment processors, AI services — anything that lives outside your database.

They extend the RPC layer outward. They don't replace it.

### RLS Always On

Row-Level Security is enabled on every table. No exceptions. RLS is your defense-in-depth layer — the `api` schema is the primary access boundary, and RLS catches anything that slips through. It's your tenant isolation and access control, all enforced by the database itself.

### Local Development Ready

You start with the Supabase CLI on your local machine, and it's ready to deploy on Supabase. Local-first development means your agent can build, test, and iterate without touching production. Migrations are version-controlled SQL files. What runs locally runs in production.

---

## Relationship to Supabase Official Skills

Supabase provides and will continue to release their own official agent skills. These are feature-focused — they teach agents how to use specific Supabase features correctly (Postgres best practices, Auth, Realtime, etc.).

Agent Link is complementary, not competing. Where Supabase skills say "here's how this feature works," Agent Link says "here's the pattern for building a complete application using these features together."

Think of it this way: Supabase skills are the reference manual for each tool in the workshop. Agent Link is the blueprint that tells you which tools to use, in what order, and how they fit together to build something solid.
