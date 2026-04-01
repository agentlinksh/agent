-- =============================================================================
-- COMMON RLS POLICIES: Reusable patterns
-- =============================================================================
-- These are templates — replace table names and column names with your own.
-- Copy the relevant patterns into the entity file: supabase/schemas/public/<table>.sql
-- Policy names use snake_case: {role}_{action}_{table}
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Pattern 1: User-owns-row
-- ---------------------------------------------------------------------------
-- Use when: each row belongs to one user, no team/tenant concept
-- Requires: table has a `user_id` column

DROP POLICY IF EXISTS users_read_own_<table> ON public.<table>;
CREATE POLICY users_read_own_<table>
ON public.<table> FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS users_insert_own_<table> ON public.<table>;
CREATE POLICY users_insert_own_<table>
ON public.<table> FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS users_update_own_<table> ON public.<table>;
CREATE POLICY users_update_own_<table>
ON public.<table> FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS users_delete_own_<table> ON public.<table>;
CREATE POLICY users_delete_own_<table>
ON public.<table> FOR DELETE
USING (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- Pattern 2: Tenant-scoped (all members can read, members+ can write)
-- ---------------------------------------------------------------------------
-- Use when: data belongs to a tenant/org, all members can see it
-- Requires: table has a `tenant_id` column, _auth_tenant_id() function exists

DROP POLICY IF EXISTS members_read_<table> ON public.<table>;
CREATE POLICY members_read_<table>
ON public.<table> FOR SELECT
USING (tenant_id = public._auth_tenant_id());

DROP POLICY IF EXISTS members_insert_<table> ON public.<table>;
CREATE POLICY members_insert_<table>
ON public.<table> FOR INSERT
WITH CHECK (
  tenant_id = public._auth_tenant_id()
  AND public._auth_has_role('member')
);

DROP POLICY IF EXISTS members_update_<table> ON public.<table>;
CREATE POLICY members_update_<table>
ON public.<table> FOR UPDATE
USING (tenant_id = public._auth_tenant_id() AND public._auth_has_role('member'))
WITH CHECK (tenant_id = public._auth_tenant_id());

DROP POLICY IF EXISTS admins_delete_<table> ON public.<table>;
CREATE POLICY admins_delete_<table>
ON public.<table> FOR DELETE
USING (tenant_id = public._auth_tenant_id() AND public._auth_has_role('admin'));


-- ---------------------------------------------------------------------------
-- Pattern 3: Public read, authenticated write
-- ---------------------------------------------------------------------------
-- Use when: content is publicly visible but only authors can create/edit

DROP POLICY IF EXISTS anon_read_published_<table> ON public.<table>;
CREATE POLICY anon_read_published_<table>
ON public.<table> FOR SELECT
USING (status = 'published');

DROP POLICY IF EXISTS authors_read_own_drafts ON public.<table>;
CREATE POLICY authors_read_own_drafts
ON public.<table> FOR SELECT
USING (user_id = auth.uid());

DROP POLICY IF EXISTS users_insert_<table> ON public.<table>;
CREATE POLICY users_insert_<table>
ON public.<table> FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS authors_update_own_<table> ON public.<table>;
CREATE POLICY authors_update_own_<table>
ON public.<table> FOR UPDATE
USING (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- Pattern 4: User-owns-row with public sharing
-- ---------------------------------------------------------------------------
-- Use when: rows are private by default but can be shared publicly
-- Requires: table has `user_id` and `is_public` boolean columns

DROP POLICY IF EXISTS users_read_own_or_public_<table> ON public.<table>;
CREATE POLICY users_read_own_or_public_<table>
ON public.<table> FOR SELECT
USING (user_id = auth.uid() OR is_public = true);

DROP POLICY IF EXISTS users_insert_own_<table> ON public.<table>;
CREATE POLICY users_insert_own_<table>
ON public.<table> FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS users_update_own_<table> ON public.<table>;
CREATE POLICY users_update_own_<table>
ON public.<table> FOR UPDATE
USING (user_id = auth.uid());

DROP POLICY IF EXISTS users_delete_own_<table> ON public.<table>;
CREATE POLICY users_delete_own_<table>
ON public.<table> FOR DELETE
USING (user_id = auth.uid());
