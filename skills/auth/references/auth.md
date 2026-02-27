# Auth Patterns

Authentication flows and session management with Supabase Auth.

## Contents
- Core Principles
- Sign Up / Sign In
- OAuth Providers
- Email Confirmation & Magic Links
- Password Reset
- Session Management
- Auth Hooks

---

## Core Principles

- **Supabase Auth is the single identity provider.** Don't build custom auth.
- **`auth.uid()` is the source of truth** in SQL. Never accept user IDs from the client.
- **Profile data goes in a `profiles` table**, not in auth user metadata. Auth metadata is for auth configuration (roles, tenant context), not application data.
- **The frontend manages sessions.** The database only sees JWTs — it doesn't know or care about session state.

---

## Sign Up / Sign In

### Email + password (baseline)

```typescript
// Sign up
const { data, error } = await supabase.auth.signUp({
  email: "user@example.com",
  password: "secure-password",
});

// Sign in
const { data, error } = await supabase.auth.signInWithPassword({
  email: "user@example.com",
  password: "secure-password",
});

// Sign out
const { error } = await supabase.auth.signOut();
```

On sign-up, the `trg_auth_users_new_user` trigger (see SKILL.md) automatically creates a profile row.

### What the database sees

After sign-in, every request carries a JWT. Database functions access the user via:

```sql
auth.uid()                              -- user's UUID
auth.jwt() ->> 'email'                  -- user's email
auth.jwt() -> 'app_metadata'            -- custom claims (tenant_id, role)
auth.jwt() -> 'user_metadata'           -- user-editable metadata
```

---

## OAuth Providers

### Setup

OAuth providers are configured in the Supabase Dashboard (Authentication > Providers). Each provider needs a client ID, client secret, and redirect URL.

Common providers: Google, GitHub, Apple, Microsoft, Discord.

### Client-side flow

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "google",
  options: {
    redirectTo: "https://yourapp.com/auth/callback",
  },
});
```

### Handling the callback

The callback page exchanges the auth code for a session:

```typescript
// On the /auth/callback page
const { data, error } = await supabase.auth.exchangeCodeForSession(code);
```

### Profile creation with OAuth

The same `trg_auth_users_new_user` trigger handles OAuth users. It extracts the display name from `raw_user_meta_data.full_name` (set by most OAuth providers).

---

## Email Confirmation & Magic Links

### Email confirmation

Enable in Dashboard > Authentication > Settings. When enabled, `signUp` sends a confirmation email automatically. The user isn't fully authenticated until they confirm.

```typescript
// Check if email is confirmed
const { data: { user } } = await supabase.auth.getUser();
if (user?.email_confirmed_at) {
  // Email is confirmed
}
```

### Magic links (passwordless)

```typescript
const { data, error } = await supabase.auth.signInWithOtp({
  email: "user@example.com",
  options: {
    emailRedirectTo: "https://yourapp.com/auth/callback",
  },
});
```

The user receives an email with a login link. No password needed.

---

## Password Reset

```typescript
// Request reset email
const { data, error } = await supabase.auth.resetPasswordForEmail(
  "user@example.com",
  { redirectTo: "https://yourapp.com/auth/reset-password" }
);

// On the reset page, after the user clicks the email link
const { data, error } = await supabase.auth.updateUser({
  password: "new-secure-password",
});
```

---

## Session Management

### Frontend responsibilities

- Listen for auth state changes: `supabase.auth.onAuthStateChange()`
- Handle token refresh (supabase-js does this automatically)
- Redirect on sign-out or session expiry
- Store session in cookies for SSR frameworks (Next.js, SvelteKit)

### SSR / Server-side

For server-side rendering, use `@supabase/ssr`:

```typescript
import { createServerClient } from "@supabase/ssr";

const supabase = createServerClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  { cookies: { /* cookie handlers */ } }
);
```

### Token refresh after claim changes

When you update JWT claims (e.g., `api.tenant_select()`), the client must refresh to get the new token:

```typescript
await supabase.auth.refreshSession();
```

Without this, RLS policies will use stale claims until the token naturally expires.

---

## Auth Hooks

Supabase Auth Hooks let you customize auth behavior with edge functions. These are configured in the Dashboard under Authentication > Hooks.

Common hooks:

| Hook | Trigger | Use case |
|------|---------|----------|
| Custom Access Token | Before token issued | Inject custom claims into JWT |
| MFA Verification | After MFA challenge | Custom MFA logic |
| Password Verification | During sign-in | Custom password rules |
| Send Email | When email triggered | Custom email provider (Resend, etc.) |
| Send SMS | When SMS triggered | Custom SMS provider |

### Custom Access Token Hook

Use this to inject tenant context into every JWT automatically, instead of updating `app_metadata` manually:

```typescript
// Edge function: custom-access-token
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse } from "../_shared/responses.ts";

Deno.serve(
  withSupabase({ allow: "public" }, async (req, ctx) => {
    const { user_id, claims } = await req.json();

    // Look up the user's active tenant
    const { data: membership } = await ctx.adminClient
      .from("memberships")
      .select("tenant_id, role")
      .eq("user_id", user_id)
      .limit(1)
      .single();

    if (membership) {
      claims.app_metadata = {
        ...claims.app_metadata,
        tenant_id: membership.tenant_id,
        tenant_role: membership.role,
      };
    }

    return jsonResponse({ claims });
  })
);
```

This runs every time a token is issued, ensuring tenant context is always fresh.
