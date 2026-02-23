import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "./cors.ts";

type Allow = "public" | "user" | "private";

interface WithSupabaseConfig {
  allow: Allow | Allow[];
}

interface SupabaseContext {
  req: Request;
  user?: Record<string, unknown>;
  claims?: Record<string, unknown>;
  client: SupabaseClient;
  adminClient: SupabaseClient;
}

type Handler = (req: Request, ctx: SupabaseContext) => Promise<Response>;

function getKeys() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SB_PUBLISHABLE_KEY");
  const secretKey = Deno.env.get("SB_SECRET_KEY");

  if (!supabaseUrl) throw new Error("Missing SUPABASE_URL");
  if (!publishableKey)
    throw new Error(
      "Missing SB_PUBLISHABLE_KEY. " +
        "Set it via: supabase secrets set SB_PUBLISHABLE_KEY=<your-anon-key>",
    );
  if (!secretKey)
    throw new Error(
      "Missing SB_SECRET_KEY. " +
        "Set it via: supabase secrets set SB_SECRET_KEY=<your-service-role-key>",
    );

  return { supabaseUrl, publishableKey, secretKey };
}

/**
 * Wraps an Edge Function handler with Supabase context.
 *
 * Provides two clients:
 * - client:        respects RLS (user-scoped for 'user', public for 'public'/'private')
 * - adminClient: bypasses RLS (service role, use deliberately)
 *
 * Allow (single or array for dual-auth):
 * - 'public'  → No auth required. Use for webhooks, public endpoints.
 * - 'user'    → Validates JWT. Provides user, claims, and user-scoped client.
 * - 'private' → Validates secret key via apikey header.
 *
 * Array tries each type in order — first match wins:
 * - ["user", "private"] → accepts either user JWT or secret key
 */
export function withSupabase(config: WithSupabaseConfig, handler: Handler) {
  const { supabaseUrl, publishableKey, secretKey } = getKeys();

  // Public client — reused across requests, respects RLS (no user context)
  const anonClient = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Service client — reused across requests, bypasses RLS
  const adminClient = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const allowed = Array.isArray(config.allow) ? config.allow : [config.allow];

  return async (req: Request): Promise<Response> => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    try {
      // Default client uses the public key — overridden if 'user' auth succeeds
      const ctx: SupabaseContext = { req, client: anonClient, adminClient };

      // 'public' — no auth needed, always passes
      if (allowed.includes("public")) {
        return await handler(req, ctx);
      }

      // Try each type in order — first successful auth wins
      let authenticated = false;

      if (allowed.includes("user")) {
        const authHeader = req.headers.get("Authorization");
        if (authHeader) {
          const token = authHeader.replace("Bearer ", "");
          const { data, error } = await anonClient.auth.getClaims(token);

          if (!error && data?.claims) {
            ctx.claims = data.claims;
            ctx.user = {
              id: data.claims.sub,
              email: data.claims.email,
              role: data.claims.role,
              ...data.claims,
            };

            // User-scoped client — carries the caller's JWT, RLS filters by identity
            ctx.client = createClient(supabaseUrl, publishableKey, {
              global: { headers: { Authorization: authHeader } },
            });

            authenticated = true;
          }
        }
      }

      if (!authenticated && allowed.includes("private")) {
        const apikey = req.headers.get("apikey");
        if (apikey && apikey === secretKey) {
          authenticated = true;
        }
      }

      if (!authenticated) {
        return Response.json(
          { error: "Unauthorized" },
          { status: 401, headers: corsHeaders },
        );
      }

      return await handler(req, ctx);
    } catch (err) {
      console.error("withSupabase error:", err);
      return Response.json(
        { error: "Internal server error" },
        { status: 500, headers: corsHeaders },
      );
    }
  };
}
