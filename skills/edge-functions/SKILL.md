---
name: edge-functions
description: Supabase Edge Functions with the withSupabase wrapper pattern. Use when the task involves creating, modifying, or debugging edge functions, webhooks, external API integrations, service-to-service calls, or anything that runs in the Deno edge runtime. Also use for configuring edge function secrets, CORS, config.toml, or migrating from legacy Supabase API keys (anon/service_role to publishable/secret). Activate whenever the task touches supabase/functions/ or mentions edge functions.
license: MIT
compatibility: Requires Supabase CLI
metadata:
  author: agentlink
  version: "0.1"
---

# Edge Functions

Edge Functions handle everything that needs to talk to the outside world — webhooks, third-party APIs, scheduled triggers, service-to-service calls. They are **not** for CRUD or business logic (that belongs in database functions via RPCs).

Every edge function uses the `withSupabase` wrapper. No exceptions.

## Quick Start

### First edge function in a project?

Check if `supabase/functions/_shared/withSupabase.ts` exists. If not:

1. Ask the user if they'd like you to set up the shared utilities
2. Copy files from this skill's `assets/functions/` into the project's `supabase/functions/_shared/`:
   - `withSupabase.ts` — context wrapper (the core utility)
   - `cors.ts` — CORS headers
   - `responses.ts` — `jsonResponse`, `errorResponse`, `notFound` helpers
   - `types.ts` — shared TypeScript types
3. Verify secrets are configured (see below)

### Creating a new function

1. **Create the function directory** — `supabase/functions/my-function/index.ts`
2. **Choose the `allow` type** — who can call this function? (see Selection Guide below)
3. **Write the handler** using `withSupabase`:

```typescript
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse, errorResponse } from "../_shared/responses.ts";

Deno.serve(
  withSupabase({ allow: "user" }, async (_req, ctx) => {
    const { data, error } = await ctx.client.rpc("my_rpc_function");

    if (error) return errorResponse(error.message);
    return jsonResponse(data);
  })
);
```

4. **Add to `config.toml`** — every function needs `verify_jwt = false`:

```toml
[functions.my-function]
verify_jwt = false
```

This is required because the `withSupabase` wrapper handles auth itself. If `verify_jwt` is left as `true` (the default), Supabase's gateway rejects requests before they reach the wrapper.

5. **Test locally** — `supabase functions serve`

---

## Selection Guide

| Scenario | Allow | Why |
|----------|-------|-----|
| User clicks a button in the app | `"user"` | Need user identity + RLS-scoped queries |
| External webhook (Stripe, GitHub) | `"public"` | No Supabase JWT — validate webhook signature yourself |
| Supabase Auth Hook | `"public"` | Called by Supabase Auth, not a user session |
| Public API / health check | `"public"` | Open access, no auth needed |
| Cron job / scheduled function | `"private"` | No user context — needs secret key validation |
| Called from DB via `_internal_call_edge_function` | `"private"` | DB calls use the secret key |
| Called by users AND by other services | `["user", "private"]` | Dual-auth — accepts either credential |

**When in doubt:** logged-in user → `"user"`. External service → `"public"`. Internal infrastructure → `"private"`.

> **For the full wrapper API, dual-auth patterns, anti-patterns, and context reference, load [withSupabase Reference](./references/with_supabase.md).**

---

## Secrets

Edge functions need `SB_PUBLISHABLE_KEY` and `SB_SECRET_KEY` configured as secrets — they are **not** available by default.

```bash
# Local development — add to supabase/.env or .env.local
SB_PUBLISHABLE_KEY=sb_publishable_...
SB_SECRET_KEY=sb_secret_...

# Production
supabase secrets set SB_PUBLISHABLE_KEY=sb_publishable_...
supabase secrets set SB_SECRET_KEY=sb_secret_...
```

`SUPABASE_URL` is available by default and does not need to be set.

---

## Project Structure

```
supabase/functions/
├── _shared/                    # Shared utilities (NOT deployed)
│   ├── withSupabase.ts         # Context wrapper
│   ├── cors.ts                 # CORS headers
│   ├── responses.ts            # Response helpers
│   └── types.ts                # Shared types
├── _feature-name/              # Feature-specific shared modules (NOT deployed)
│   └── helpers.ts
├── my-function/
│   └── index.ts
└── another-function/
    └── index.ts
```

Folders prefixed with `_` are shared modules — they are not deployed as edge functions.

---

## Reference Files

Load these as needed:

- **[🔧 withSupabase Wrapper](./references/with_supabase.md)** — Full wrapper API: allow types, dual-auth, clients, anti-patterns, context reference
- **[📁 Edge Function Patterns](./references/edge_functions.md)** — Folder structure details, CORS, response helpers, feature-specific modules
- **[🔑 API Key Migration](./references/api_key_migration.md)** — Migrate from legacy anon/service_role keys to new publishable/secret keys
