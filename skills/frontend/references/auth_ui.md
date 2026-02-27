# Auth UI Patterns

Client-side authentication UI — sign-in/sign-up forms, OAuth redirect flows, and protected routes.

## Contents
- Sign-In / Sign-Up Forms
- OAuth Redirect Flow
- Protected Routes

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

Same pattern as sign-in, but use `supabase.auth.signUp()`:

```typescript
const { data, error } = await supabase.auth.signUp({
  email,
  password,
});

if (error) {
  setError(error.message);
  return;
}

// If email confirmation is enabled, tell the user to check their inbox
if (data.user && !data.user.email_confirmed_at) {
  setMessage("Check your email for a confirmation link.");
}
```

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

### Client-side guard (SPA fallback)

For apps without SSR, guard in client components:

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

```typescript
async function handleSignOut() {
  const supabase = createClient();
  await supabase.auth.signOut();
  window.location.href = "/login";
}
```
