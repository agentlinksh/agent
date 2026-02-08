# Common Workflows

Step-by-step guides for common development tasks.

---

## Initial Project Setup

Run once per project to ensure the required infrastructure is in place. This corresponds to **Phase 0** in SKILL.md.

### 1. Run the Setup Check

Load `assets/check_setup.sql` and execute it via `execute_sql`. The result is a JSON object:

```json
{
  "extensions": { "pg_net": true, "vault": true },
  "functions":  { "_internal_get_secret": true, "_internal_call_edge_function": true, "_internal_call_edge_function_sync": true },
  "secrets":    { "SUPABASE_URL": true, "SB_PUBLISHABLE_KEY": true, "SB_SECRET_KEY": true },
  "ready": true
}
```

If `"ready": true`, skip to the normal development phases. Otherwise continue below for each `false` value.

### 2. Enable Missing Extensions

If `extensions.pg_net` or `extensions.vault` is `false`, apply a migration:

```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS supabase_vault;
```

Use `apply_migration` with a descriptive name like `enable_required_extensions`.

### 3. Create Missing Internal Functions

If any function in the `functions` object is `false`:

1. Load `assets/setup.sql` — it contains the full definitions for all three `_internal_*` functions.
2. Copy the relevant function(s) into the project's `supabase/schemas/50_functions/_internal/` directory.
3. Apply via `apply_migration`.

The three functions and their purposes:

| Function | Purpose |
|----------|---------|
| `_internal_get_secret(text)` | Reads a secret from Vault by name |
| `_internal_call_edge_function(text, jsonb)` | Calls an Edge Function asynchronously via pg_net |
| `_internal_call_edge_function_sync(text, jsonb, integer)` | Synchronous wrapper with timeout/polling |

### 4. Store Missing Vault Secrets

If any secret in the `secrets` object is `false`, the values need to be stored in Vault.

**Required secrets:**

| Secret Name | Production Value | Local Dev Value | Source |
|-------------|-----------------|-----------------|--------|
| `SUPABASE_URL` | `https://abc.supabase.co` | `http://host.docker.internal:54321` | Dashboard > Settings > API |
| `SB_PUBLISHABLE_KEY` | Publishable (anon) API key | Same key from local config | `supabase status` or Dashboard |
| `SB_SECRET_KEY` | Secret (service role) API key | Same key from local config | `supabase status` or Dashboard |

> **⚠️ Local development (supabase start):** `SUPABASE_URL` in Vault must use `http://host.docker.internal:54321`, **not** `http://127.0.0.1:54321`. Postgres runs inside a Docker container — `127.0.0.1` resolves to the container itself, so `pg_net` HTTP calls will fail with "Couldn't connect to server". `host.docker.internal` is the standard Docker hostname that resolves to the host machine. This only affects the Vault secret used by `_internal_call_edge_function`; the CLI and client-side code still use `http://127.0.0.1:54321` as usual.

**Path A — Agent creates secrets via `execute_sql`:**

Ask the user for the missing values. If running locally (`supabase start`), use `http://host.docker.internal:54321` for `SUPABASE_URL`. Then run for each:

```sql
SELECT vault.create_secret('<value>', '<secret_name>');
```

Example for production:

```sql
SELECT vault.create_secret('https://your-project.supabase.co', 'SUPABASE_URL');
SELECT vault.create_secret('sb_publishable_...', 'SB_PUBLISHABLE_KEY');
SELECT vault.create_secret('sb_secret_...', 'SB_SECRET_KEY');
```

Example for local development:

```sql
SELECT vault.create_secret('http://host.docker.internal:54321', 'SUPABASE_URL');
SELECT vault.create_secret('sb_publishable_...', 'SB_PUBLISHABLE_KEY');
SELECT vault.create_secret('sb_secret_...', 'SB_SECRET_KEY');
```

**Path B — User runs the script manually:**

If `execute_sql` is not available, point the user to the setup script:

```bash
# Production
./scripts/setup_vault_secrets.sh \
  --url "https://your-project.supabase.co" \
  --publishable-key "sb_publishable_..." \
  --secret-key "sb_secret_..."

# Local development — note the Docker-internal URL
./scripts/setup_vault_secrets.sh \
  --url "http://host.docker.internal:54321" \
  --publishable-key "sb_publishable_..." \
  --secret-key "sb_secret_..."
```

The script handles upserts — it will update existing secrets if they already exist.

### 5. Re-run the Check

Run `assets/check_setup.sql` again via `execute_sql` and confirm `"ready": true` before proceeding to Phase 1.

### 6. Scaffold Schema Structure (if needed)

If `supabase/schemas/` doesn't exist yet, run the scaffold script:

```bash
./scripts/scaffold_schemas.sh /path/to/project
```

---

## Adding a New Entity

Example: Adding a `readings` entity.

### 1. Register Entity

Add to `ENTITIES.md`:
```markdown
## Entities
- chart
- reading  ← new
```

### 2. Create Table

`supabase/schemas/20_tables/readings.sql`:
```sql
CREATE TABLE IF NOT EXISTS public.readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chart_id uuid NOT NULL REFERENCES public.charts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content jsonb NOT NULL DEFAULT '{}',
  is_public boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.readings ENABLE ROW LEVEL SECURITY;
```

### 3. Add Indexes

`supabase/schemas/40_indexes/readings.sql`:
```sql
CREATE INDEX IF NOT EXISTS idx_readings_chart_id ON public.readings(chart_id);
CREATE INDEX IF NOT EXISTS idx_readings_user_id ON public.readings(user_id);
CREATE INDEX IF NOT EXISTS idx_readings_created_at ON public.readings(created_at DESC);
```

### 4. Create Auth Functions

`supabase/schemas/50_functions/_auth/reading.sql`:
```sql
CREATE OR REPLACE FUNCTION _auth_reading_can_read(p_reading_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.readings
    WHERE id = p_reading_id
    AND (user_id = auth.uid() OR is_public = true)
  );
END;
$$;

CREATE OR REPLACE FUNCTION _auth_reading_is_owner(p_reading_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.readings
    WHERE id = p_reading_id
    AND user_id = auth.uid()
  );
END;
$$;
```

### 5. Create Business Logic

`supabase/schemas/50_functions/reading.sql`:
```sql
CREATE OR REPLACE FUNCTION reading_create(
  p_chart_id uuid,
  p_content jsonb DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_reading_id uuid;
BEGIN
  -- RLS INSERT policy checks user_id = auth.uid()
  INSERT INTO public.readings (chart_id, user_id, content)
  VALUES (p_chart_id, auth.uid(), p_content)
  RETURNING id INTO v_reading_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'reading_id', v_reading_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION reading_get_by_id(p_reading_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- RLS SELECT policy handles access control (own or public readings)
  SELECT jsonb_build_object(
    'id', r.id,
    'chart_id', r.chart_id,
    'content', r.content,
    'is_public', r.is_public,
    'created_at', r.created_at
  ) INTO v_result
  FROM public.readings r
  WHERE r.id = p_reading_id;
  
  RETURN v_result;
END;
$$;
```

### 6. Add RLS Policies

`supabase/schemas/70_policies/readings.sql`:
```sql
CREATE POLICY "Users can read own or public readings"
ON readings FOR SELECT
USING (_auth_reading_can_read(id));

CREATE POLICY "Users can insert own readings"
ON readings FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own readings"
ON readings FOR UPDATE
USING (_auth_reading_is_owner(id));

CREATE POLICY "Users can delete own readings"
ON readings FOR DELETE
USING (_auth_reading_is_owner(id));
```

### 7. Generate Types

```bash
supabase gen types typescript --local > src/types/database.ts
```

### 8. Update Entity Registry

Complete the mapping in `ENTITIES.md`.

---

## Adding a Field to Existing Table

Example: Adding `archived_at` to `readings`.

### 1. Update Table Definition

`supabase/schemas/20_tables/readings.sql`:
```sql
-- Add to table definition
archived_at timestamptz DEFAULT NULL
```

### 2. Add Index (if needed)

`supabase/schemas/40_indexes/readings.sql`:
```sql
CREATE INDEX IF NOT EXISTS idx_readings_archived_at 
ON public.readings(archived_at) 
WHERE archived_at IS NOT NULL;
```

### 3. Update Functions

Add to `50_functions/reading.sql`:
```sql
CREATE OR REPLACE FUNCTION reading_archive(p_reading_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  -- RLS UPDATE policy ensures only owners can update
  UPDATE public.readings
  SET archived_at = now()
  WHERE id = p_reading_id
    AND archived_at IS NULL;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not found or already archived');
  END IF;
  
  RETURN jsonb_build_object('success', true);
END;
$$;
```

### 4. Fix Data Errors (if any)

If CLI reports constraint violations:
```sql
-- Use execute_sql MCP tool
UPDATE readings SET archived_at = NULL WHERE archived_at = '0001-01-01';
```

### 5. Generate Types

```bash
supabase gen types typescript --local > src/types/database.ts
```

---

## Creating a Trigger

Example: Auto-update `updated_at` timestamp.

### 1. Create Trigger Function (once)

`supabase/schemas/50_functions/_internal/set_updated_at.sql`:
```sql
CREATE OR REPLACE FUNCTION _internal_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
```

### 2. Create Trigger

`supabase/schemas/60_triggers/readings.sql`:
```sql
DROP TRIGGER IF EXISTS trg_readings_updated_at ON public.readings;
CREATE TRIGGER trg_readings_updated_at
  BEFORE UPDATE ON public.readings
  FOR EACH ROW
  EXECUTE FUNCTION _internal_set_updated_at();
```

---

## Migration Workflow

### During Development

1. Make changes to schema files
2. CLI auto-applies (watch mode)
3. Fix any data errors via `execute_sql`
4. Test thoroughly

### When Ready to Commit

```bash
# Generate migration from current changes
supabase db diff -f my_migration_name
```

### Review Migration

1. Check generated SQL in `supabase/migrations/`
2. Verify all changes are captured
3. If `execute_sql` commands are missing, add them manually
4. Test migration on fresh database:
   ```bash
   supabase db reset
   ```
