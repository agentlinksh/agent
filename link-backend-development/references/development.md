# Development

The daily development loop. How agents build features, apply changes, and produce migrations.

---

## Core Principle

The agent applies every change in two places simultaneously:

1. **The live local database** — via MCP `execute_sql`, so changes take effect immediately
2. **The schema files** — in `supabase/schemas/`, so the source of truth stays in sync

Schema files are the canonical representation of your database. The live database is the working copy. Both must always reflect the same state.

**The database is never reset unless the user explicitly requests it.**

---

## Development Loop

### Making Changes

When building a feature, the agent:

1. Writes the SQL in the appropriate schema file (see naming conventions)
2. Runs the same SQL against the local database via `execute_sql`
3. If something breaks, fixes it with more SQL — never resets
4. Continues building until the feature is complete

This applies to everything: tables, indexes, functions, policies, triggers. The agent writes the schema file AND applies it live. Always both.

### Fixing Errors

When `execute_sql` returns an error:

- **Constraint violation** — Fix the data, then retry the schema change
- **Duplicate object** — The schema file should already use `IF NOT EXISTS` / `CREATE OR REPLACE`
- **Dependency conflict** — Drop and recreate in the correct order
- **Data type mismatch** — Migrate the data first, then alter the column

The agent handles errors with more SQL. The database accumulates real state during development — treat it like a production database that happens to be local.

---

## Migration Workflow

### During Development

No migrations are created. The agent works directly against the live database while keeping schema files in sync. Changes accumulate in the local Postgres instance.

### When Ready to Commit

Generate a single migration capturing all un-migrated changes:

```bash
supabase db diff -f descriptive_migration_name
```

This compares the live local database against the migrations folder and outputs everything that's different as one migration file.

### Review

Check the generated file in `supabase/migrations/`:

- Verify all changes are captured
- Confirm the order makes sense (tables before indexes, functions before policies)
- If any `execute_sql` data fixes are needed for the migration to replay cleanly, add them manually

### Verify (requires user confirmation)

To confirm the migration replays cleanly from scratch:

```bash
supabase db reset
```

**This destroys and recreates the local database.** Only run this when the user explicitly asks for it. Never run it automatically. After reset, `seed.sql` runs automatically to restore Vault secrets and seed data.

---

## Generating Types

After any schema change, regenerate the TypeScript types:

```bash
supabase gen types typescript --local > src/types/database.ts
```

Run this after completing a set of related changes, not after every individual statement.

---

## Examples

### Adding a New Entity

Example: Adding a `readings` entity to a project that already has `charts`.

**1. Register the entity** in `ENTITIES.md`:
```markdown
## Entities
- chart
- reading  ← new
```

**2. Create the table** — `supabase/schemas/20_tables/readings.sql`:
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

**3. Add indexes** — `supabase/schemas/40_indexes/readings.sql`:
```sql
CREATE INDEX IF NOT EXISTS idx_readings_chart_id ON public.readings(chart_id);
CREATE INDEX IF NOT EXISTS idx_readings_user_id ON public.readings(user_id);
CREATE INDEX IF NOT EXISTS idx_readings_created_at ON public.readings(created_at DESC);
```

**4. Create auth functions** — `supabase/schemas/50_functions/_auth/reading.sql`:
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

**5. Create business logic** — `supabase/schemas/50_functions/reading.sql`:
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

**6. Add RLS policies** — `supabase/schemas/70_policies/readings.sql`:
```sql
CREATE POLICY "Users can read own or public readings"
ON public.readings FOR SELECT
USING (_auth_reading_can_read(id));

CREATE POLICY "Users can insert own readings"
ON public.readings FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own readings"
ON public.readings FOR UPDATE
USING (_auth_reading_is_owner(id));

CREATE POLICY "Users can delete own readings"
ON public.readings FOR DELETE
USING (_auth_reading_is_owner(id));
```

**7. Apply everything** — Run each file's SQL via `execute_sql` in order: table → indexes → auth functions → business functions → policies.

**8. Generate types:**
```bash
supabase gen types typescript --local > src/types/database.ts
```

**9. Update entity registry** in `ENTITIES.md` with the complete mapping.

---

### Adding a Field to an Existing Table

Example: Adding `archived_at` to `readings`.

**1. Update the table definition** in `supabase/schemas/20_tables/readings.sql`:
```sql
-- Add to the CREATE TABLE (for fresh setups)
archived_at timestamptz DEFAULT NULL
```

**2. Apply to live database** via `execute_sql`:
```sql
ALTER TABLE public.readings ADD COLUMN IF NOT EXISTS archived_at timestamptz DEFAULT NULL;
```

**3. Add index** if needed — `supabase/schemas/40_indexes/readings.sql`:
```sql
CREATE INDEX IF NOT EXISTS idx_readings_archived_at 
ON public.readings(archived_at) 
WHERE archived_at IS NOT NULL;
```

**4. Add the function** — `supabase/schemas/50_functions/reading.sql`:
```sql
CREATE OR REPLACE FUNCTION reading_archive(p_reading_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
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

**5. Fix data errors** if any exist:
```sql
-- via execute_sql
UPDATE public.readings SET archived_at = NULL WHERE archived_at = '0001-01-01';
```

**6. Generate types:**
```bash
supabase gen types typescript --local > src/types/database.ts
```

---

### Creating a Trigger

Example: Auto-update `updated_at` on row changes.

**1. Create trigger function** (once per project) — `supabase/schemas/50_functions/_internal/set_updated_at.sql`:
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

**2. Create trigger** — `supabase/schemas/60_triggers/readings.sql`:
```sql
DROP TRIGGER IF EXISTS trg_readings_updated_at ON public.readings;
CREATE TRIGGER trg_readings_updated_at
  BEFORE UPDATE ON public.readings
  FOR EACH ROW
  EXECUTE FUNCTION _internal_set_updated_at();
```

**3. Apply both** via `execute_sql` in order: function first, then trigger.