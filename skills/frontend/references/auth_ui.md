# Auth UI Patterns

Client-side authentication UI — sign-in/sign-up forms, OAuth redirect flows, and protected routes.

> **Vite projects:** The scaffold provides auth infrastructure (`AuthProvider`, `_auth.tsx` guard) but not auth pages. Build login/sign-up pages based on the project's auth strategy.

## Contents
- Vite Auth Infrastructure
- Sign-In / Sign-Up Forms
- Handling Supabase Auth Responses
- OAuth Redirect Flow
- Protected Routes
- Post-Auth Actions (e.g., invitation acceptance)

---

## Vite Auth Infrastructure

### Auth context

The scaffold provides `AuthProvider` and `useAuth()` in `src/contexts/auth-context.tsx`:

```typescript
import { useAuth } from "@/contexts/auth-context";

function MyComponent() {
  const { user, session, loading } = useAuth();
  // user: User | null, session: Session | null, loading: boolean
}
```

The `AuthProvider` wraps the app in `main.tsx` and manages a single Supabase auth subscription. All components share the same auth state — no duplicate subscriptions.

### Protected routes (TanStack Router layout)

The scaffold uses a `_auth.tsx` layout route that guards all child routes via `beforeLoad`:

```typescript
// src/routes/_auth.tsx
import { createFileRoute, Outlet, redirect } from "@tanstack/react-router";
import { supabase } from "@/lib/supabase";
import { ErrorBoundary } from "@/components/error-boundary";

export const Route = createFileRoute("/_auth")({
  beforeLoad: async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw redirect({ to: "/login" });
    return { session };
  },
  component: AuthLayout,
});

function AuthLayout() {
  return (
    <main className="min-h-dvh bg-background">
      <ErrorBoundary>
        <Outlet />
      </ErrorBoundary>
    </main>
  );
}
```

All routes under `src/routes/_auth/` are automatically protected. No wrapper component needed — the router handles it before the page even renders.

### Auth callback (PKCE flow)

For OAuth redirects, magic links, and email confirmations, `onAuthStateChange` handles the token exchange automatically. Create a dedicated route if you need custom post-auth logic:

```typescript
// src/routes/auth-callback.tsx
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { supabase } from "@/lib/supabase";

export const Route = createFileRoute("/auth-callback")({
  component: AuthCallbackPage,
});

function AuthCallbackPage() {
  const navigate = useNavigate();

  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event) => {
        if (event === "SIGNED_IN") {
          navigate({ to: "/", replace: true });
        }
      }
    );
    return () => subscription.unsubscribe();
  }, [navigate]);

  return <div>Completing sign in...</div>;
}
```

### Post-auth action (e.g., invitation acceptance)

When the auth callback must perform an action after sign-in (RPC call, session refresh), two concurrent paths race for the auth lock:

1. `onAuthStateChange` fires `SIGNED_IN` when the URL hash fragment is consumed
2. `getSession()` resolves once the session is established

If both trigger the same async work, three operations compete for the lock and produce **"Lock broken by another request"** errors.

Rules:
- **Guard flag** — `let handled = false` ensures only the first path executes
- **Non-async `onAuthStateChange` callback** — do not `await` inside the callback (holds the lock)
- **Defer `refreshSession()`** — call it in a `setTimeout` after the RPC succeeds, never in the same tick

❌ Wrong — both paths fire, async callback holds the lock:

```typescript
// src/routes/accept-invitation.tsx — BROKEN
function AcceptInvitationPage() {
  const navigate = useNavigate();
  const { token } = Route.useSearch();

  useEffect(() => {
    async function acceptInvitation() {
      await supabase.rpc("invitation_accept", { p_token: token });
      await supabase.auth.refreshSession(); // competes for auth lock
      navigate({ to: "/", replace: true });
    }

    // Path 1: fires on SIGNED_IN
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event) => {
        if (event === "SIGNED_IN") {
          await acceptInvitation(); // holds the auth lock
        }
      }
    );

    // Path 2: fires when session resolves
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) acceptInvitation(); // races with Path 1
    });

    return () => subscription.unsubscribe();
  }, [token, navigate]);

  return <div>Accepting invitation...</div>;
}
```

✅ Correct — guard flag, non-async callback, deferred refresh:

```typescript
// src/routes/accept-invitation.tsx
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { z } from "zod";

const searchSchema = z.object({
  token: z.string().uuid(),
});

export const Route = createFileRoute("/accept-invitation")({
  validateSearch: searchSchema,
  component: AcceptInvitationPage,
});

function AcceptInvitationPage() {
  const navigate = useNavigate();
  const { token } = Route.useSearch();

  useEffect(() => {
    let handled = false;

    async function acceptInvitation() {
      if (handled) return;
      handled = true;

      const { error } = await supabase.rpc("invitation_accept", {
        p_token: token,
      });

      if (error) {
        console.error("Failed to accept invitation:", error.message);
        navigate({ to: "/login", replace: true });
        return;
      }

      // Defer refreshSession — let the auth flow settle first
      setTimeout(async () => {
        await supabase.auth.refreshSession();
        navigate({ to: "/", replace: true });
      }, 0);
    }

    // Path 1: auth state listener
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_IN") {
        // Non-async — do not hold the auth lock
        acceptInvitation();
      }
    });

    // Path 2: session may already exist
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) acceptInvitation();
    });

    return () => subscription.unsubscribe();
  }, [token, navigate]);

  return <div>Accepting invitation...</div>;
}
```

Key differences from the simple auth callback above:
- `let handled = false` guard prevents double execution
- `onAuthStateChange` callback is **not** `async` — calls `acceptInvitation()` without `await`
- `refreshSession()` runs inside `setTimeout` so it does not compete for the auth lock
- Error handling navigates to `/login` as fallback

---

## Sign-In / Sign-Up Forms

### Email + password form

```typescript
"use client";
import { createClient } from "@/lib/supabase/client";
import { useState } from "react";

export function SignInForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const supabase = createClient();

  async function handleSignIn(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }

    // Redirect — middleware or onAuthStateChange handles navigation
    window.location.href = "/dashboard";
  }

  return (
    <form onSubmit={handleSignIn}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
        required
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
        required
      />
      {error && <p>{error}</p>}
      <button type="submit" disabled={loading}>
        {loading ? "Signing in..." : "Sign in"}
      </button>
    </form>
  );
}
```

### Sign-up form

Use `supabase.auth.signUp()` and branch on `data.session`, not on `email_confirmed_at`:

```typescript
const { data, error } = await supabase.auth.signUp({ email, password });
if (error) throw error;

// Supabase returns a user but NO session when email confirmation is required.
// This is the reliable check — `data.user.email_confirmed_at` may be populated
// asynchronously and is not safe to race on.
if (!data.session) {
  // Show a "check your inbox" UI, DO NOT navigate into the app.
  setPendingConfirmationEmail(email);
  return;
}

// Session exists → refresh to pick up tenant_id claim (see note below).
await supabase.auth.refreshSession();
router.push("/dashboard");
```

**Why refresh the session after signup?** The `_internal_admin_handle_new_user`
trigger writes the default `tenant_id` into the JWT **after** Supabase issues
the initial token. Without `refreshSession()`, every tenant-scoped RPC fails
with `missing tenant_id` until the user reloads the page.

### Magic link (passwordless)

```typescript
const { error } = await supabase.auth.signInWithOtp({
  email,
  options: {
    emailRedirectTo: `${window.location.origin}/auth/callback`,
  },
});

if (error) {
  setError(error.message);
  return;
}

setMessage("Check your email for a login link.");
```

---

## Handling Supabase Auth Responses

Supabase's auth responses have sharp edges. Handle them explicitly so users
don't get stranded on errors they can't understand or loop in confirmation
dead-ends.

### Email confirmation — branch on `data.session`, not on `email_confirmed_at`

`supabase.auth.signUp()` returns `{ user, session }`. When email confirmation
is required, `session` is `null`. Always check `data.session` — not
`data.user.email_confirmed_at`, which can be written asynchronously.

```typescript
const { data, error } = await supabase.auth.signUp({ email, password });
if (error) throw error;

if (!data.session) {
  // Confirmation required — show a "check your inbox" UI. Do NOT navigate,
  // the user isn't signed in yet.
  return showConfirmationPending(email);
}

// Session exists — refresh to pick up the tenant_id claim from the
// `_internal_admin_handle_new_user` trigger, then continue into the app.
await supabase.auth.refreshSession();
router.push("/dashboard");
```

### Where is email confirmation configured?

| Environment | Setting | Default in scaffold |
| --- | --- | --- |
| Local (`config.toml`) | `[auth.email].enable_confirmations` | `false` (dev) |
| Cloud (Management API) | `mailer_autoconfirm` | `true` on initial scaffold (dev), `false` otherwise |

The scaffold disables email confirmation on dev so the first sign-up lands in
the app without SMTP. The `!data.session` branch is a safety net: it handles
prod (where confirmation stays on) and any project where an admin re-enables it.

### Map Supabase errors to friendly messages

The scaffold ships `lib/auth-errors.ts` with `formatAuthError(err)`. It checks
the stable `code` field first, falls back to message substrings. Use it at
every auth call site instead of surfacing raw Supabase strings:

```typescript
import { formatAuthError } from "@/lib/auth-errors";

try {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
} catch (err) {
  setError(formatAuthError(err));  // "Wrong email or password." etc.
}
```

Extend the helper when you add new flows (magic link, OAuth, password reset)
— the map is just a `switch` on `err.code`.

### Known auth response quirks

- **`User already registered`** on sign-up with an existing *unconfirmed* email
  is returned when "Confirm email" is on. It looks like a duplicate but the
  user just never finished confirmation. Send them to resend.
- **`Email not confirmed`** on sign-in means the session isn't issued yet.
  Offer a "resend confirmation" action — don't ask for a different password.
- **`Email rate limit exceeded`** fires after ~4 sign-ups from the same IP
  within an hour. Show the rate-limit copy, not a generic error.
- **`refreshSession()` deadlock**: never call it inside `onAuthStateChange`.
  The SDK re-fires the event and hangs. Refresh after explicit user actions
  (signup, invitation accept), not inside auth listeners.

---

## OAuth Redirect Flow

### Trigger sign-in

```typescript
async function handleOAuthSignIn(provider: "google" | "github") {
  const { error } = await supabase.auth.signInWithOAuth({
    provider,
    options: {
      redirectTo: `${window.location.origin}/auth/callback`,
    },
  });

  if (error) {
    setError(error.message);
  }
  // Browser redirects to the OAuth provider — no need to handle success here
}
```

### Callback page

After the OAuth provider redirects back, exchange the code for a session:

```typescript
// Next.js: src/app/auth/callback/route.ts
import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  // Auth failed — redirect to error page
  return NextResponse.redirect(`${origin}/auth/error`);
}
```

```typescript
// SvelteKit: src/routes/auth/callback/+server.ts
import { redirect } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { createClient } from "$lib/supabase/server";

export const GET: RequestHandler = async ({ url, cookies }) => {
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/dashboard";

  if (code) {
    const supabase = createClient(cookies);
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      redirect(303, next);
    }
  }

  redirect(303, "/auth/error");
};
```

---

## Protected Routes

### Server-side (recommended)

Check auth in server components or load functions. This prevents flash of unauthenticated content.

```typescript
// Next.js: src/app/dashboard/layout.tsx
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  return <>{children}</>;
}
```

```typescript
// SvelteKit: src/routes/dashboard/+layout.server.ts
import { redirect } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ locals }) => {
  if (!locals.user) redirect(303, "/login");
  return { user: locals.user };
};
```

### Client-side guard (Vite SPA)

For Vite projects, the `_auth.tsx` layout route handles this automatically via `beforeLoad`. No separate guard component is needed — see the "Vite Auth Patterns" section above.

For Next.js projects without SSR, guard in client components:

```typescript
"use client";
import { createClient } from "@/lib/supabase/client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const supabase = createClient();

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) {
        router.push("/login");
      } else {
        setLoading(false);
      }
    });
  }, []);

  if (loading) return null; // or a spinner

  return <>{children}</>;
}
```

### Sign-out

Call `supabase.auth.signOut()` directly — no wrapper needed:

```typescript
import { supabase } from "@/lib/supabase";
import { useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";

function SignOutButton() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    queryClient.clear(); // clear cached data
    navigate({ to: "/login" });
  };

  return <button onClick={handleSignOut}>Sign out</button>;
}
```
