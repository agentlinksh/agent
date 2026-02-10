# Edge Functions

Project structure, shared utilities, and setup for Supabase Edge Functions.

Every Edge Function uses the `withSupabase` wrapper. **See [withSupabase Reference](./with_supabase.md) for usage rules, role selection, client patterns, and examples.**

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

## Feature-Specific Shared Modules

For logic shared across related functions, use a `_feature-name/` directory:

```typescript
// supabase/functions/generate-summary/index.ts
import { withSupabase } from "../_shared/withSupabase.ts";
import { jsonResponse, errorResponse } from "../_shared/errors.ts";
import { buildPrompt } from "../_ai/prompts.ts";
import { callOpenAI } from "../_ai/openai.ts";

Deno.serve(
  withSupabase({ key: "user" }, async (req, ctx) => {
    const { document_id } = await req.json();

    const { data: doc, error } = await ctx.client.rpc("document_get_by_id", {
      p_document_id: document_id,
    });

    if (error) return errorResponse(error.message);

    const summary = await callOpenAI(buildPrompt("summarize", doc.content));

    const { error: updateError } = await ctx.serviceClient.rpc(
      "document_update_summary",
      { p_document_id: document_id, p_summary: summary }
    );

    if (updateError) return errorResponse(updateError.message);
    return jsonResponse({ summary });
  })
);
```
