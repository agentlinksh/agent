# Agent Link — Skill Catalog

_The complete map of runes. Each rune is a skill that encodes opinionated patterns for one domain of building on Supabase._

---

## How to Read This Catalog

Each rune is described with:

- **Purpose** — What problem this rune solves
- **Core Opinions** — The opinionated decisions this rune makes for the agent
- **Key Patterns** — The main patterns the skill teaches
- **Assets** — Ready-to-use code files included with the skill
- **Depends On** — Other runes this one builds on
- **Status** — Current development state

---

## 🔧 Rune: Dev Workflow

> Foundation skill. How to set up, develop, and deploy a Supabase project.

**Status:** ✅ Built (existing `supabase-dev-workflow` skill — to be migrated and evolved)

**Purpose:** Establish the local development workflow, CLI usage, migration strategy, and deployment patterns that every other rune builds on.

**Core Opinions:**
- Supabase CLI is the single source of truth for local development
- Migrations are version-controlled SQL files, never auto-generated
- Local-first development: always develop against a local Supabase instance
- Environment separation: local → staging → production

**Key Patterns:**
- Project initialization and configuration
- Local development setup with `supabase start`
- Writing and applying migrations
- Seeding data for development
- Deployment workflow (CI/CD)
- Environment variable management

**Assets:**
- Starter migration templates
- Seed file patterns
- CI/CD configuration examples

**Depends On:** None (foundation rune)

---

## 📡 Rune: RPC Architecture

> The backbone. How to design your Postgres functions as a complete API layer.

**Status:** 🟡 To Build

**Purpose:** Teach agents to design and implement all CRUD and business logic as Postgres functions exposed via Supabase's RPC endpoint. One backend, many frontends.

**Core Opinions:**
- SECURITY INVOKER by default — RLS does the access control, not the function
- SECURITY DEFINER only for: auth helpers called by RLS policies, internal utilities needing elevated access
- Functions are your API. Name them like endpoints: `get_`, `create_`, `update_`, `delete_`, `list_`
- Return typed results using custom composite types or JSON
- Input validation happens inside the function, not in the frontend
- One function per operation, not one function per table

**Key Patterns:**
- CRUD function templates (single record, batch, with filters)
- Business logic functions (multi-step operations, transactions)
- Tenant-scoped queries (always filter by tenant context)
- Pagination patterns (cursor-based, offset-based)
- Error handling and custom error codes
- Function versioning strategy
- Search and filtering patterns
- Aggregate and reporting functions

**Assets:**
- SQL templates for common CRUD patterns
- Error handling utilities
- Pagination helpers
- Type definition templates

**Depends On:** Dev Workflow, Row-Level Security

---

## 🔐 Rune: Auth & Identity

> Who is the user? How do they prove it?

**Status:** 🟡 To Build

**Purpose:** Implement authentication flows that work correctly with Supabase Auth, including session management, provider configuration, and identity resolution.

**Core Opinions:**
- Use Supabase Auth as the single identity provider
- JWT claims are the source of truth for user identity in RLS and RPCs
- Always use `auth.uid()` and `auth.jwt()` — never pass user IDs from the frontend
- Email + password as the baseline, with OAuth as additive
- User metadata goes in a `profiles` table, not in auth metadata
- Session handling is the frontend's job, identity verification is the database's job

**Key Patterns:**
- Sign up / sign in / sign out flows
- OAuth provider setup (Google, GitHub, etc.)
- Email confirmation and magic link flows
- Password reset flow
- Profile creation on sign-up (using database triggers)
- Role assignment and role-based access
- Extracting tenant context from JWT claims

**Assets:**
- Profile trigger SQL template
- Role management functions
- Auth helper RPC functions

**Depends On:** Dev Workflow

---

## 🛡️ Rune: Row-Level Security

> The gatekeeper. Every row, every query, every time.

**Status:** 🟡 To Build

**Purpose:** Implement RLS policies that enforce access control at the database level, with multi-tenancy as the default isolation model.

**Core Opinions:**
- RLS is always enabled. No exceptions.
- Policies are the access control layer — not application code, not Edge Functions
- Tenant isolation is enforced via RLS, not application-level filtering
- Use `auth.uid()` for user-scoped access, JWT claims for tenant-scoped access
- Keep policies simple and composable: one policy per access pattern
- SECURITY DEFINER functions exist only to support RLS (e.g., checking membership), not to bypass it

**Key Patterns:**
- User-owns-row pattern (personal data)
- Tenant-scoped access pattern (team/org data)
- Role-based access within tenants (admin, member, viewer)
- Public read, authenticated write patterns
- Hierarchical access (org → team → member)
- Service-role bypass patterns (for internal operations only)
- Policy naming conventions
- Performance: index strategies for RLS predicates

**Assets:**
- RLS policy templates for common patterns
- Tenant isolation SQL patterns
- Role-checking helper functions
- Policy testing queries

**Depends On:** Auth & Identity

---

## ⚡ Rune: Edge Functions

> The bridge to the outside world.

**Status:** ✅ Partially Built (withSupabase pattern exists in dev-workflow — to be extracted and expanded)

**Purpose:** Implement Edge Functions using the opinionated `withSupabase` wrapper pattern for all external integrations.

**Core Opinions:**
- Edge Functions are for external integrations only — not for CRUD, not for business logic
- Every function uses the `withSupabase` wrapper with explicit role declaration
- Three roles: `anon` (webhooks, public), `auth` (user-facing, JWT validated), `admin` (internal, service key)
- CORS is handled automatically by the wrapper
- Error responses follow a consistent structure
- One function per integration concern, not one function per action

**Key Patterns:**
- Webhook receivers (Stripe, GitHub, etc.)
- Third-party API calls (payment processing, email, AI services)
- File processing pipelines
- Scheduled triggers (called by pg_cron via HTTP)
- Inter-service communication
- Secret management (Supabase Vault or environment variables)

**Assets:**
- `withSupabase.ts` — The core wrapper
- `cors.ts` — CORS handling utility
- `errors.ts` — Standardized error responses
- `types.ts` — Shared type definitions
- Integration templates (Stripe, Resend, OpenAI, etc.)

**Depends On:** Dev Workflow, RPC Architecture

---

## 📁 Rune: Storage

> Files, images, and assets — organized and secured.

**Status:** 🟡 To Build

**Purpose:** Implement file storage with proper bucket configuration, access control, and organization patterns.

**Core Opinions:**
- Storage buckets follow the same tenant isolation model as your database
- RLS on storage objects mirrors your table-level policies
- Use signed URLs for private content, public buckets only for truly public assets
- File paths encode ownership: `{tenant_id}/{entity_type}/{entity_id}/{filename}`
- Image transformations use Supabase's built-in transform API
- Upload validation (size, type) happens at the policy level

**Key Patterns:**
- Bucket creation and configuration
- Upload flows (direct from frontend, via Edge Function)
- Access control policies for storage objects
- Signed URL generation
- Image optimization and transformation
- File organization strategies
- Cleanup patterns (orphaned files)

**Assets:**
- Storage policy templates
- Upload helper RPCs
- File path utility functions

**Depends On:** Dev Workflow, Row-Level Security

---

## 📢 Rune: Realtime

> Live updates, presence, and communication.

**Status:** 🟡 To Build

**Purpose:** Implement Realtime subscriptions, presence tracking, and broadcast patterns that work with RLS and multi-tenancy.

**Core Opinions:**
- Realtime is a delivery mechanism, not a data source — the database is always the source of truth
- Channel design follows tenant boundaries
- Presence is for UI state (who's online, cursor positions), not for business logic
- Broadcast is for ephemeral events that don't need persistence
- Database changes (INSERT/UPDATE/DELETE) use Realtime subscriptions with RLS enforcement

**Key Patterns:**
- Table change subscriptions (filtered by tenant)
- Presence channels (who's online, typing indicators)
- Broadcast patterns (notifications, live updates)
- Channel authorization strategies
- Handling reconnection and missed events
- Scaling considerations

**Assets:**
- Channel setup templates
- Presence management utilities
- Subscription helper patterns

**Depends On:** Dev Workflow, Row-Level Security, Auth & Identity

---

## ⏰ Rune: Cron & Queues

> Reliable async work, powered by Postgres.

**Status:** 🟡 To Build

**Purpose:** Implement scheduled jobs and async task processing using Postgres extensions, keeping all orchestration inside the database.

**Core Opinions:**
- `pg_cron` for scheduled work — no external schedulers
- Queue tables (or `pgmq`) for async task processing
- Tasks are database rows with status tracking: pending → processing → completed/failed
- Retry logic and dead-letter handling are built into the pattern
- Complex async workflows are orchestrated via database state, not Edge Function chains
- Cron jobs can call Edge Functions via `net.http_post` for external integrations

**Key Patterns:**
- Scheduled maintenance jobs (cleanup, aggregation, reports)
- Async task queue with workers
- Retry and backoff strategies
- Dead-letter queue for failed tasks
- Tenant-scoped job scheduling
- Monitoring and alerting on job health
- Idempotency patterns

**Assets:**
- Queue table migration templates
- Worker function patterns
- Cron job setup SQL
- Monitoring query templates

**Depends On:** Dev Workflow, RPC Architecture

---

## 🧪 Rune: Testing

> Prove it works. Every pattern, every policy, every function.

**Status:** 🟡 To Build

**Purpose:** Provide testing strategies and patterns for validating RPCs, RLS policies, Edge Functions, and the full application stack.

**Core Opinions:**
- RLS policies must be tested — they're your security boundary
- Test as different roles: anon, authenticated (different users), service_role
- RPC functions get unit tests via SQL (pgTAP or plain assertions)
- Edge Functions get integration tests
- Tenant isolation is always verified in tests
- Tests run against local Supabase, never against production

**Key Patterns:**
- RLS policy testing (can user A see user B's data? can tenant X access tenant Y?)
- RPC function testing (input validation, expected results, error cases)
- Edge Function integration testing
- Auth flow testing
- Multi-tenant isolation verification
- Performance testing for RLS-heavy queries
- Seed data strategies for tests

**Assets:**
- Test setup SQL scripts
- pgTAP test templates
- Edge Function test utilities
- Tenant isolation test suite

**Depends On:** Dev Workflow, Row-Level Security, RPC Architecture

---

## 🏢 Rune: Multi-Tenancy

> Isolation by default. One pattern, every table, every query.

**Status:** 🟡 To Build

**Purpose:** Provide the overarching multi-tenancy architecture that every other rune references. This rune defines *how* tenancy works; other runes implement it within their domain.

**Core Opinions:**
- Shared database, shared schema, tenant column isolation (not schema-per-tenant)
- Every tenant-scoped table has a `tenant_id` column
- Tenant context is derived from JWT claims, never from request parameters
- RLS enforces isolation — application code doesn't need to filter
- Tenant creation, membership, and invitation patterns are standardized
- Cross-tenant queries are only possible with service_role, and are explicitly designed

**Key Patterns:**
- Tenant table and membership model
- JWT claim injection for tenant context
- RLS policy template for tenant isolation
- Tenant switching (users who belong to multiple tenants)
- Invitation and onboarding flows
- Tenant-scoped data export
- Cross-tenant admin patterns (platform-level reporting)
- Tenant deletion and data cleanup

**Assets:**
- Core tenancy migration (tenants, memberships, invitations tables)
- Tenant context helper functions
- Membership management RPCs
- Invitation flow templates

**Depends On:** Dev Workflow, Auth & Identity, Row-Level Security

---

## Dependency Graph

```
                    ┌──────────────┐
                    │ Dev Workflow  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
      ┌───────▼──────┐ ┌──▼───────┐ ┌──▼──────────┐
      │ Auth &       │ │ RPC      │ │ Edge        │
      │ Identity     │ │ Arch     │ │ Functions   │
      └───────┬──────┘ └──┬───────┘ └─────────────┘
              │            │
      ┌───────▼──────┐    │
      │ Row-Level    │◄───┘
      │ Security     │
      └──┬──┬──┬──┬──┘
         │  │  │  │
    ┌────┘  │  │  └────┐
    │       │  │       │
┌───▼──┐ ┌─▼──▼─┐ ┌───▼────┐
│Store │ │Real  │ │Cron &  │
│      │ │time  │ │Queues  │
└──────┘ └──────┘ └────────┘
    │       │         │
    └───────┼─────────┘
            │
    ┌───────▼───────┐
    │   Testing     │
    └───────────────┘
            │
    ┌───────▼───────┐
    │ Multi-Tenancy │
    │  (cross-cut)  │
    └───────────────┘
```

_Multi-Tenancy is both a standalone rune and a cross-cutting concern referenced by every other rune._

---

## Build Order

Recommended order for developing the runes:

1. **Dev Workflow** ✅ — Migrate and evolve existing skill
2. **Edge Functions** 🟡 — Extract and expand from dev-workflow
3. **Auth & Identity** — Foundation for security runes
4. **Row-Level Security** — Foundation for everything that touches data
5. **RPC Architecture** — The core API layer
6. **Multi-Tenancy** — The cross-cutting pattern
7. **Cron & Queues** — Async work layer
8. **Storage** — File handling
9. **Realtime** — Live features
10. **Testing** — Validation across all runes

---

## Contributing a Rune

Each rune follows a consistent structure:

```
rune-name/
├── SKILL.md              # Core instructions for the agent
├── references/           # Detailed patterns and decision trees
│   ├── patterns.md
│   ├── anti-patterns.md
│   └── decisions.md
└── assets/               # Ready-to-copy code files
    ├── sql/
    └── typescript/
```

The SKILL.md is what the agent reads first. It should be opinionated, direct, and complete enough for the agent to act without asking questions. References provide depth for complex scenarios. Assets provide code that works out of the box.
