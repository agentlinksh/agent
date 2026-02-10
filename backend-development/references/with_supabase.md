# withSupabase Wrapper

The `withSupabase` wrapper is the **only** way to initialize Supabase clients in Edge Functions. It provides two clients, handles CORS preflight, and enforces authentication based on the function's key type.

---

## Rules

1. **ALWAYS use `withSupabase`** — never call `createClient()` in function code, never parse JWTs manually.
2. **ALWAYS use `ctx.client` and `ctx.serviceClient`** — they are provided by the wrapper. Never create your own clients.
3. **ALWAYS set `verify_jwt = false`** in `config.toml` for every function — the wrapper handles auth.

---

## Clients

Both clients are **always available** on every key type:

| Client | Behavior | Use for |
|--------|----------|---------|
| `ctx.client` | Respects RLS | Default choice. User data operations, queries that should be scoped by policies. |
| `ctx.serviceClient` | Bypasses RLS | Service-level operations that need full access. Use deliberately. |

How `ctx.client` is initialized depends on the key:

| Key | `ctx.client` is... |
|-----|---------------------|
| `user` | User-scoped — carries the caller's JWT, so RLS filters by user identity |
| `public` | Public — publishable key, no JWT. RLS `anon` role policies apply |
| `private` | Public — publishable key, no JWT. RLS `anon` role policies apply |

**Default to `ctx.client`.** Reserve `ctx.serviceClient` for operations where the function acts as the system, not on behalf of a user -- e.g., processing webhook payloads, cron jobs, writing to service-only tables. If RLS is blocking a user-facing operation, fix the RLS policy; do not switch to `serviceClient` to work around it.

---

## Key Types

### `user` — User-Facing Functions

For functions called from the app by a logged-in user. The wrapper validates the JWT and rejects the request if the user is not authenticated.

**Provides:** `ctx.user`, `ctx.claims`, `ctx.client` (user-scoped), `ctx.serviceClient`

```typescript
Deno.serve(
  withSupabase({ key: "user" }, async (_req, ctx) => {
    // ctx.user.id, ctx.user.email — user identity
    // ctx.client — queries scoped to this user via RLS
    const { data, error } = await ctx.client.rpc("profile_get_by_user");

    if (error) return errorResponse(error.message);
    return jsonResponse(data);
  })
);
```

### `public` — Webhooks, Public Endpoints, External Services

For functions that receive no Supabase JWT. Use this for:

- **External service webhooks** (Stripe, GitHub, etc.) — the handler validates the external signature itself
- **Supabase Auth Hooks** — called by Supabase Auth, not by a user session
- **Public endpoints** — health checks, open APIs
- Any call where the caller handles its own authentication outside of Supabase

No auth enforcement — the request passes through to the handler.

**Provides:** `ctx.client` (public), `ctx.serviceClient`

```typescript
// Stripe webhook — validates its own signature, uses serviceClient for DB writes
Deno.serve(
  withSupabase({ key: "public" }, async (req, ctx) => {
    const signature = req.headers.get("stripe-signature");
    if (!signature) return errorResponse("Missing signature", 401);

    const body = await req.json();
    // Webhook-specific validation here...

    const { error } = await ctx.serviceClient.rpc("payment_process_webhook", {
      p_event: body,
    });

    if (error) return errorResponse(error.message);
    return jsonResponse({ received: true });
  })
);
```

### `private` — Internal / Service-to-Service

For functions called with the secret key. The wrapper validates that the `apikey` header contains the correct secret key and rejects the request otherwise.

Use this for:
- Cron jobs / scheduled functions
- Database-triggered calls via `_internal_call_edge_function`
- Internal service-to-service calls

**Provides:** `ctx.client` (public), `ctx.serviceClient`

```typescript
// Cron job — only callable with the secret key
Deno.serve(
  withSupabase({ key: "private" }, async (_req, ctx) => {
    const { data, error } = await ctx.serviceClient.rpc(
      "cleanup_expired_sessions"
    );

    if (error) return errorResponse(error.message);
    return jsonResponse({ deleted: data });
  })
);
```

---

## Key Selection Guide

| Scenario | Key | Why |
|----------|-----|-----|
| User clicks a button in the app | `user` | Need user identity + RLS-scoped queries |
| External webhook (Stripe, GitHub) | `public` | No Supabase JWT; validate webhook signature yourself |
| Supabase Auth Hook | `public` | Called by Supabase Auth, not a user session |
| Public API / health check | `public` | Open access, no auth needed |
| Cron job / scheduled function | `private` | No user context; needs secret key validation |
| Called from another edge function | `private` | Internal service-to-service; uses secret key |
| Called from DB via `_internal_call_edge_function` | `private` | DB calls with secret key |

**When in doubt:** if there's a logged-in user, use `user`. If it's an external service, use `public`. If it's internal infrastructure, use `private`.

---

## Function Configuration

Every function using `withSupabase` must disable built-in JWT verification since the wrapper handles auth itself:

###### `config.toml`

```toml
[functions.my-function]
verify_jwt = false
```

This is **required** for `public` and `private` keys (they don't send a Supabase JWT), and **required** for `user` key because the wrapper validates tokens using the newer `getClaims` pattern.

---

## Anti-Patterns

### Creating clients manually

```typescript
// ❌ WRONG — manual client creation inside the handler
Deno.serve(
  withSupabase({ key: "user" }, async (req, ctx) => {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SB_PUBLISHABLE_KEY")!
    );
    const { data } = await supabase.rpc("some_function");
    // ...
  })
);

// ✅ CORRECT — use ctx.client
Deno.serve(
  withSupabase({ key: "user" }, async (_req, ctx) => {
    const { data } = await ctx.client.rpc("some_function");
    // ...
  })
);
```

### Using `serviceClient` when `client` would suffice

```typescript
// ❌ WRONG — bypasses RLS unnecessarily
Deno.serve(
  withSupabase({ key: "user" }, async (_req, ctx) => {
    const { data } = await ctx.serviceClient.rpc("profile_get_by_user");
    // ...
  })
);

// ✅ CORRECT — let RLS scope the query to the user
Deno.serve(
  withSupabase({ key: "user" }, async (_req, ctx) => {
    const { data } = await ctx.client.rpc("profile_get_by_user");
    // ...
  })
);
```

### Using `user` key for a webhook

```typescript
// ❌ WRONG — Stripe doesn't send a Supabase JWT, this will always 401
Deno.serve(
  withSupabase({ key: "user" }, async (req, ctx) => {
    const signature = req.headers.get("stripe-signature");
    // ...
  })
);

// ✅ CORRECT — use none, validate the webhook signature yourself
Deno.serve(
  withSupabase({ key: "public" }, async (req, ctx) => {
    const signature = req.headers.get("stripe-signature");
    if (!signature) return errorResponse("Missing signature", 401);
    // ...
  })
);
```

---

## Context Reference

```typescript
interface SupabaseContext {
  req: Request;

  // Always available
  client: SupabaseClient;       // Respects RLS
  serviceClient: SupabaseClient;  // Bypasses RLS

  // Available when key is 'user'
  user?: {
    id: string;
    email?: string;
    role?: string;
    [key: string]: unknown;
  };
  claims?: Record<string, unknown>;
}
```

### Implementation

The full implementation is provided as an asset file — see `assets/functions/withSupabase.ts`. Do not rewrite this from scratch; copy the asset file into the project's `supabase/functions/_shared/` directory.

The wrapper handles:
- CORS preflight (`OPTIONS` requests) automatically
- Key resolution for `SB_PUBLISHABLE_KEY` and `SB_SECRET_KEY`
- Clear error messages if secrets are missing
- JWT validation via `getClaims` for `user` key
- Secret key validation for `private` key
- User-scoped client creation with the caller's JWT for `user` key
- Public client for `public` and `private` keys
