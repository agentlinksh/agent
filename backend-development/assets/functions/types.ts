import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type Allow = "public" | "user" | "private";

export interface WithSupabaseConfig {
  allow: Allow | Allow[];
}

export interface SupabaseContext {
  /** The original request object */
  req: Request;

  /** User object — available when allow is 'user' */
  user?: {
    id: string;
    email?: string;
    role?: string;
    [key: string]: unknown;
  };

  /** Raw JWT claims — available when allow is 'user' */
  claims?: Record<string, unknown>;

  /**
   * Supabase client that respects RLS — always available.
   * - 'user': user-scoped (carries the caller's JWT)
   * - 'public'/'private': public client (publishable key, no user context)
   */
  client: SupabaseClient;

  /** Service role Supabase client (bypasses RLS) — always available */
  serviceClient: SupabaseClient;
}

export type SupabaseHandler = (
  req: Request,
  ctx: SupabaseContext
) => Promise<Response>;
