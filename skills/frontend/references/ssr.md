# SSR Patterns

Server-side rendering with `@supabase/ssr` — cookie-based auth for Next.js and SvelteKit.

## Contents
- Why @supabase/ssr
- Next.js App Router
- SvelteKit
- Cookie Handling

---

## Why @supabase/ssr

Browser clients store the session in `localStorage`. Server-side code can't access `localStorage`, so `@supabase/ssr` uses cookies instead. This lets server components, API routes, and middleware make authenticated Supabase calls.

```bash
npm install @supabase/ssr @supabase/supabase-js
```

---

## Next.js App Router

### Utility: create clients

Create a utility file that both server and client code import:

```typescript
// src/lib/supabase/client.ts
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
  );
}
```

```typescript
// src/lib/supabase/server.ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // setAll called from a Server Component — ignore.
            // Middleware will refresh the session.
          }
        },
      },
    }
  );
}
```

### Middleware: refresh tokens on every request

```typescript
// src/middleware.ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // Refresh the session — this is the whole point of the middleware
  const { data: { user } } = await supabase.auth.getUser();

  // Optional: redirect unauthenticated users away from protected routes
  if (!user && request.nextUrl.pathname.startsWith("/dashboard")) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    // Run on all routes except static files and images
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

### Using in Server Components

```typescript
// src/app/dashboard/page.tsx
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data } = await supabase.rpc("chart_list");

  return <div>{/* render data */}</div>;
}
```

### Using in Client Components

```typescript
"use client";
import { createClient } from "@/lib/supabase/client";
import { useEffect, useState } from "react";

export function ChartList() {
  const [charts, setCharts] = useState([]);
  const supabase = createClient();

  useEffect(() => {
    supabase.rpc("chart_list").then(({ data }) => {
      if (data) setCharts(data.items);
    });
  }, []);

  return <div>{/* render charts */}</div>;
}
```

---

## SvelteKit

### Utility: create clients

```typescript
// src/lib/supabase/client.ts
import { createBrowserClient } from "@supabase/ssr";
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY } from "$env/static/public";

export function createClient() {
  return createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY);
}
```

```typescript
// src/lib/supabase/server.ts
import { createServerClient } from "@supabase/ssr";
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY } from "$env/static/public";
import type { Cookies } from "@sveltejs/kit";

export function createClient(cookies: Cookies) {
  return createServerClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
    cookies: {
      getAll() {
        return cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) => {
          cookies.set(name, value, { ...options, path: "/" });
        });
      },
    },
  });
}
```

### Hooks: refresh tokens on every request

```typescript
// src/hooks.server.ts
import { createClient } from "$lib/supabase/server";
import { redirect, type Handle } from "@sveltejs/kit";

export const handle: Handle = async ({ event, resolve }) => {
  const supabase = createClient(event.cookies);

  // Refresh the session
  const { data: { user } } = await supabase.auth.getUser();

  // Make available to load functions and actions
  event.locals.supabase = supabase;
  event.locals.user = user;

  // Optional: protect routes
  if (!user && event.url.pathname.startsWith("/dashboard")) {
    redirect(303, "/login");
  }

  return resolve(event);
};
```

### Using in load functions

```typescript
// src/routes/dashboard/+page.server.ts
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ locals }) => {
  const { data } = await locals.supabase.rpc("chart_list");
  return { charts: data?.items ?? [] };
};
```

---

## Cookie Handling

### Why cookies?

`@supabase/ssr` stores auth tokens in cookies so both the browser and server have access. The middleware/hooks refresh the token on every request, keeping the session alive without client-side JavaScript.

### Security defaults

- Cookies are `HttpOnly`, `Secure`, and `SameSite=Lax` by default
- The session is split across multiple cookies to stay within browser cookie size limits
- Never manually read or write Supabase auth cookies — let the library handle it
