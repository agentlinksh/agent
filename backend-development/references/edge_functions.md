# Edge Functions Patterns

Patterns for building Supabase Edge Functions with minimal boilerplate and consistent security.

---

## Core Principle

Every Edge Function uses a `withSupabase` wrapper that provides context (clients, user, etc.) based on the function's required access level. No manual client initialization, no repeated JWT validation, no scattered environment variable reads.

```typescript
// ❌ WRONG — boilerplate in every function
Deno.serve(async (req) => {
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SB_PUBLISHABLE_KEY')!)
  const authHeader = req.headers.get('Authorization')!
  const token = authHeader.replace('Bearer ', '')
  const { data, error } = await supabase.auth.getClaims(token)
  if (error) return Response.json({ msg: 'Invalid JWT' }, { status: 401 })
  // ... finally do actual work
})

// ✅ CORRECT — wrapper handles everything
Deno.serve(withSupabase({ role: 'auth' }, async (req, ctx) => {
  // ctx.user, ctx.client, ctx.adminClient — all ready to use
  return Response.json({ message: `hello ${ctx.user.email}` })
}))
```

---

## Folder Structure

```
supabase/functions/
├── _shared/                    # Global shared utilities
│   ├── withSupabase.ts         # Context wrapper (core utility)
│   ├── cors.ts                 # CORS headers
│   ├── errors.ts               # Error response helpers
│   └── types.ts                # Shared TypeScript types
├── _feature-name/              # Feature-specific shared modules
│   ├── someHelper.ts           # Shared logic for this feature
│   └── types.ts                # Feature-specific types
├── my-function/                # An edge function
│   └── index.ts
└── another-function/
    └── index.ts
```

Folders prefixed with `_` are shared modules and are NOT deployed as edge functions. Use `_shared/` for global utilities and `_feature-name/` for logic shared across related functions.

### Setting Up Shared Utilities

Ready-to-use shared utility files are provided as assets in this skill:

```
assets/functions/
├── withSupabase.ts    # Context wrapper
├── cors.ts            # CORS headers
├── errors.ts          # Error/response helpers
└── types.ts           # TypeScript types
```

**When creating the first edge function for a project**, check if `supabase/functions/_shared/withSupabase.ts` exists. If not:

1. **Ask the user** if they'd like you to set up the shared edge function utilities
2. If yes, copy the files from `assets/functions/` into the project's `supabase/functions/_shared/` directory
3. Verify the required secrets (`SB_PUBLISHABLE_KEY`, `SB_SECRET_KEY`) are configured

---

## Required Secrets

Edge Functions need the new `SB_` prefixed API keys. These are **NOT** available by default in the Edge Functions environment — they must be manually configured as secrets.

**Before writing any edge function**, verify these secrets exist. If they don't, prompt the user to set them up:

```bash
# Check if secrets are set (locally)
supabase secrets list

# Set secrets locally (in supabase/.env or .env.local)
SB_PUBLISHABLE_KEY=sb_publishable_...
SB_SECRET_KEY=sb_secret_...

# Set secrets in production
supabase secrets set SB_PUBLISHABLE_KEY=sb_publishable_...
supabase secrets set SB_SECRET_KEY=sb_secret_...
```

> **Note:** `SUPABASE_URL` is available by default. `SB_PUBLISHABLE_KEY` and `SB_SECRET_KEY` must be set manually.

---

## The `withSupabase` Wrapper

### Configuration

The wrapper accepts a config object that determines the access level:

| Role | Use Case | What's Provided |
|------|----------|-----------------|
| `anon` | Webhooks, public endpoints, health checks | `req`, `adminClient` |
| `auth` | User-facing functions | `req`, `user`, `claims`, `client`, `adminClient` |
| `admin` | Cron jobs, internal service-to-service calls | `req`, `adminClient` |

### Context Object

```typescript
interface SupabaseContext {
  // Always available
  req: Request

  // Available when role is 'auth'
  user: User                    // Full user object from getClaims
  claims: JWTClaims             // JWT claims (email, sub, role, etc.)
  client: SupabaseClient        // User-scoped client (respects RLS)

  // Available when role is 'auth' or 'admin'
  adminClient: SupabaseClient   // Service role client (bypasses RLS)
}
```

### Implementation

The full implementation is provided as an asset file — see `assets/functions/withSupabase.ts`. Do not rewrite this from scratch; copy the asset file into the project's `supabase/functions/_shared/` directory.

The wrapper handles:
- CORS preflight (`OPTIONS` requests) automatically
- Key resolution with fallback from new `SB_` keys to legacy keys
- Clear error messages if secrets are missing
- JWT validation via `getClaims` for `auth` role
- Secret key validation for `admin` role
- User-scoped client creation with the caller's JWT for RLS
```

---

## CORS

CORS is handled as a separate utility, following the [official Supabase pattern](https://supabase.com/docs/guides/functions/cors). See `assets/functions/cors.ts` — copy it to `supabase/functions/_shared/cors.ts` in the project.

Always include `corsHeaders` in your responses:

```typescript
import { corsHeaders } from "../_shared/cors.ts";

return Response.json(data, {
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});
```

The `withSupabase` wrapper already handles `OPTIONS` preflight requests automatically.

---

## Error Helpers

See `assets/functions/errors.ts` — copy it to `supabase/functions/_shared/errors.ts` in the project. Utilities:

```typescript
import { jsonResponse, errorResponse, notFound } from "../_shared/errors.ts";

// Success
return jsonResponse({ id: "123", name: "test" });

// Error with status
return errorResponse("Invalid input", 400);

// 404
return notFound("User not found");
```

These helpers automatically include CORS headers in every response.

---

## Usage Examples

### Authenticated Function (most common)

```typescript
// supabase/functions/get-profile/index.ts
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse, errorResponse } from "../_shared/errors.ts";

Deno.serve(
  withSupabase({ role: "auth" }, async (_req, ctx) => {
    // ctx.user and ctx.client are available
    const { data, error } = await ctx.client!.rpc("profile_get_by_user");

    if (error) return errorResponse(error.message);

    return jsonResponse(data);
  })
);
```

### Public / Webhook Function (no auth)

```typescript
// supabase/functions/stripe-webhook/index.ts
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse, errorResponse } from "../_shared/errors.ts";

Deno.serve(
  withSupabase({ role: "anon" }, async (req, ctx) => {
    // Validate webhook signature yourself
    const signature = req.headers.get("stripe-signature");
    if (!signature) return errorResponse("Missing signature", 401);

    const body = await req.json();

    // Use adminClient for service-level operations
    const { error } = await ctx.adminClient.rpc("payment_process_webhook", {
      p_event: body,
    });

    if (error) return errorResponse(error.message);

    return jsonResponse({ received: true });
  })
);
```

### Admin / Internal Function (service role only)

```typescript
// supabase/functions/daily-cleanup/index.ts
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse, errorResponse } from "../_shared/errors.ts";

Deno.serve(
  withSupabase({ role: "admin" }, async (_req, ctx) => {
    // Only callable with service role key
    const { data, error } = await ctx.adminClient.rpc("cleanup_expired_sessions");

    if (error) return errorResponse(error.message);

    return jsonResponse({ deleted: data });
  })
);
```

### Using Feature-Specific Shared Modules

```typescript
// supabase/functions/contribute-thread-process/index.ts
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse, errorResponse } from "../_shared/errors.ts";
import { extractThreadMetadata } from "../_contribute/extraction/extractThreadMetadata.ts";

Deno.serve(
  withSupabase({ role: "admin" }, async (req, ctx) => {
    const body = await req.json();
    const metadata = await extractThreadMetadata(body.conversation);

    const { error } = await ctx.adminClient.rpc("thread_update_metadata", {
      p_thread_id: body.thread_id,
      p_metadata: metadata,
    });

    if (error) return errorResponse(error.message);

    return jsonResponse({ success: true });
  })
);
```

---

## Choosing the Right Role

| Scenario | Role | Why |
|----------|------|-----|
| User clicks button in app | `auth` | Need user identity + RLS-scoped queries |
| External webhook (Stripe, GitHub) | `anon` | No Supabase JWT; validate webhook signature yourself |
| Cron job / scheduled function | `admin` | No user context; needs full DB access |
| Called from another edge function | `admin` | Internal service-to-service; use service role key |
| Called from database via `_internal_call_edge_function` | `admin` | DB calls with secret key |
| Public API endpoint (no auth needed) | `anon` | Open access, use adminClient for DB if needed |

---

## Function Configuration

When using `withSupabase`, disable the built-in JWT verification since the wrapper handles auth:

###### `supabase/functions/config.toml` (or per-function config)

```toml
[functions.my-function]
verify_jwt = false
```

This is required for `anon` and `admin` role functions, and recommended for `auth` functions since `withSupabase` handles validation with the newer JWT signing keys pattern.

---

## Key Rules

1. **Always use `withSupabase`** — never manually create clients or parse JWTs in function code
2. **Use `ctx.client` for user operations** — it respects RLS automatically
3. **Use `ctx.adminClient` for service operations** — bypasses RLS, use with care
4. **CORS is separate** — `_shared/cors.ts` handles headers, `withSupabase` handles OPTIONS preflight
5. **Shared modules in `_shared/`** — global utilities; `_feature/` for feature-specific code
6. **RPC-first** — Edge Functions should call database RPCs, not query tables directly (consistent with the overall Supabase dev workflow)
