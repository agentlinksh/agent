import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "./cors.ts";

type Role = "anon" | "auth" | "admin";

interface WithSupabaseConfig {
  role: Role;
}

interface SupabaseContext {
  req: Request;
  user?: Record<string, unknown>;
  claims?: Record<string, unknown>;
  client?: SupabaseClient;
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
        "Set it via: supabase secrets set SB_PUBLISHABLE_KEY=<your-anon-key>"
    );
  if (!secretKey)
    throw new Error(
      "Missing SB_SECRET_KEY. " +
        "Set it via: supabase secrets set SB_SECRET_KEY=<your-service-role-key>"
    );

  return { supabaseUrl, publishableKey, secretKey };
}

/**
 * Wraps an Edge Function handler with Supabase context.
 *
 * - role: 'anon'  → No auth required. Provides adminClient only.
 * - role: 'auth'  → Validates JWT, provides user, claims, user-scoped client, and adminClient.
 * - role: 'admin' → Validates secret key in Authorization header, provides adminClient.
 */
export function withSupabase(config: WithSupabaseConfig, handler: Handler) {
  const { supabaseUrl, publishableKey, secretKey } = getKeys();

  // Admin client — reused across requests (no user-specific state)
  const adminClient = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  return async (req: Request): Promise<Response> => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    try {
      const ctx: SupabaseContext = { req, adminClient };

      if (config.role === "auth") {
        // Validate user JWT
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return Response.json(
            { error: "Missing Authorization header" },
            { status: 401, headers: corsHeaders }
          );
        }

        const token = authHeader.replace("Bearer ", "");
        const anonClient = createClient(supabaseUrl, publishableKey);
        const { data, error } = await anonClient.auth.getClaims(token);

        if (error || !data?.claims) {
          return Response.json(
            { error: "Invalid or expired token" },
            { status: 401, headers: corsHeaders }
          );
        }

        ctx.claims = data.claims;
        ctx.user = {
          id: data.claims.sub,
          email: data.claims.email,
          role: data.claims.role,
          ...data.claims,
        };

        // User-scoped client — respects RLS
        ctx.client = createClient(supabaseUrl, publishableKey, {
          global: { headers: { Authorization: authHeader } },
        });
      }

      if (config.role === "admin") {
        // Validate that the caller is using the secret key
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return Response.json(
            { error: "Missing Authorization header" },
            { status: 401, headers: corsHeaders }
          );
        }

        const token = authHeader.replace("Bearer ", "");
        if (token !== secretKey) {
          return Response.json(
            { error: "Unauthorized: requires secret key" },
            { status: 403, headers: corsHeaders }
          );
        }
      }

      return await handler(req, ctx);
    } catch (err) {
      console.error("withSupabase error:", err);
      return Response.json(
        { error: "Internal server error" },
        { status: 500, headers: corsHeaders }
      );
    }
  };
}
