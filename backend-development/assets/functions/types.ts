import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type Role = "anon" | "auth" | "admin";

export interface WithSupabaseConfig {
  role: Role;
}

export interface SupabaseContext {
  /** The original request object */
  req: Request;

  /** User object — available when role is 'auth' */
  user?: {
    id: string;
    email?: string;
    role?: string;
    [key: string]: unknown;
  };

  /** Raw JWT claims — available when role is 'auth' */
  claims?: Record<string, unknown>;

  /** User-scoped Supabase client (respects RLS) — available when role is 'auth' */
  client?: SupabaseClient;

  /** Service role Supabase client (bypasses RLS) — always available */
  adminClient: SupabaseClient;
}

export type SupabaseHandler = (
  req: Request,
  ctx: SupabaseContext
) => Promise<Response>;
