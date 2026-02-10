import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "./cors.ts";

type Key = "public" | "user" | "private";

interface WithSupabaseConfig {
  key: Key;
}

interface SupabaseContext {
  req: Request;
  user?: Record<string, unknown>;
  claims?: Record<string, unknown>;
  client: SupabaseClient;
  serviceClient: SupabaseClient;
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
 * Provides two clients on every key type:
 * - client:      respects RLS (user-scoped for 'user', public for 'public'/'private')
 * - serviceClient: bypasses RLS (service role, use deliberately)
 *
 * Keys:
 * - 'public'    → No auth required. Use for webhooks, public endpoints.
 * - 'user'    → Validates JWT. Provides user, claims, and user-scoped client.
 * - 'private' → Validates secret key via apikey header.
 */
export function withSupabase(config: WithSupabaseConfig, handler: Handler) {
  const { supabaseUrl, publishableKey, secretKey } = getKeys();

  // Public client — reused across requests, respects RLS (no user context)
  const anonClient = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Private client — reused across requests, bypasses RLS
  const serviceClient = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  return async (req: Request): Promise<Response> => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    try {
      // Default client uses the public key — overridden for 'user' key below
      const ctx: SupabaseContext = { req, client: anonClient, serviceClient };

      if (config.key === "user") {
        // Validate user JWT
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return Response.json(
            { error: "Missing Authorization header" },
            { status: 401, headers: corsHeaders },
          );
        }

        const token = authHeader.replace("Bearer ", "");
        const { data, error } = await anonClient.auth.getClaims(token);

        if (error || !data?.claims) {
          return Response.json(
            { error: "Invalid or expired token" },
            { status: 401, headers: corsHeaders },
          );
        }

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
      }

      if (config.key === "private") {
        // Validate that the caller is using the secret key via apikey header
        const apikey = req.headers.get("apikey");
        if (!apikey) {
          return Response.json(
            { error: "Missing apikey header" },
            { status: 401, headers: corsHeaders },
          );
        }

        if (apikey !== secretKey) {
          return Response.json(
            { error: "Unauthorized: requires secret key" },
            { status: 403, headers: corsHeaders },
          );
        }
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
