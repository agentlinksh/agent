# RPC Patterns

RPC-first architecture patterns for Supabase.

## Contents
- Core Principle
- Security Context: INVOKER vs DEFINER
- Function Categories (business logic, auth, internal)
- RLS Policy Pattern
- Multi-Table Operations
- Security Checklist

## Core Principle

All client data access goes through database functions (RPCs). No direct table queries.

```typescript
// ❌ NEVER - direct table access
const { data } = await supabase.from('charts').select('*')

// ✅ ALWAYS - RPC call
const { data } = await supabase.rpc('chart_get_by_user', { p_user_id: userId })
```

---

## Security Context: INVOKER vs DEFINER

**Default: SECURITY INVOKER** — the function runs as the calling user, so RLS policies apply automatically. This is correct for all business logic RPCs.

**Exception: SECURITY DEFINER** — the function runs as the owner (bypasses RLS). Only use for:
- `_auth_*` functions used inside RLS policies (they need to query the table they protect)
- `_internal_*` utilities that need elevated access (vault secrets, edge function calls)
- Multi-table operations where the user role genuinely can't access a needed table
- Always add a comment explaining why: `-- SECURITY DEFINER: required because ...`

```sql
-- ❌ WRONG — bypasses RLS then manually reimplements access checks
CREATE FUNCTION chart_get_by_id(p_chart_id uuid)
RETURNS jsonb LANGUAGE plpgsql
SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  SELECT ... FROM public.charts
  WHERE id = p_chart_id AND user_id = auth.uid(); -- fragile manual filter
END; $$;

-- ✅ CORRECT — let RLS handle access control
CREATE FUNCTION chart_get_by_id(p_chart_id uuid)
RETURNS jsonb LANGUAGE plpgsql
SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  SELECT ... FROM public.charts
  WHERE id = p_chart_id; -- RLS enforces who can see what
END; $$;
```

---

## Function Categories

### 1. Business Logic RPCs (SECURITY INVOKER)

Called from client via `supabase.rpc()`. Handle CRUD and domain logic. RLS policies protect the data automatically.

```sql
CREATE OR REPLACE FUNCTION chart_get_by_id(p_chart_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'user_id', c.user_id,
    'created_at', c.created_at
  ) INTO v_result
  FROM public.charts c
  WHERE c.id = p_chart_id;
  -- No user_id filter needed — RLS policy handles access control
  
  RETURN v_result;
END;
$$;
```

### 2. Auth Functions (SECURITY DEFINER — justified)

Called by RLS policies. Always return `boolean`. These MUST use SECURITY DEFINER because they run during policy evaluation and need to query the very table the policy protects.

```sql
-- SECURITY DEFINER: required because this is called by RLS policies
-- and needs to access the table being protected
CREATE OR REPLACE FUNCTION _auth_chart_can_read(p_chart_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.charts
    WHERE id = p_chart_id
    AND user_id = auth.uid()
  );
END;
$$;
```

### 3. Internal Utilities (SECURITY DEFINER — justified)

Called by other functions. Never exposed to client. Need elevated access for infrastructure tasks.

```sql
-- See assets/setup.sql for implementations:
-- _internal_get_secret(name)        — reads vault, requires elevated access
-- _internal_call_edge_function()    — calls edge functions, requires service role
```

---

## RLS Policy Pattern

All policies delegate to auth functions:

```sql
-- Policy calls auth function
CREATE POLICY "Users can read own charts"
ON charts FOR SELECT
USING (_auth_chart_can_read(id));

CREATE POLICY "Users can update own charts"
ON charts FOR UPDATE
USING (_auth_chart_can_write(id));

CREATE POLICY "Users can insert own charts"
ON charts FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own charts"
ON charts FOR DELETE
USING (_auth_chart_is_owner(id));
```

---

## Multi-Table Operations

For operations spanning multiple tables (e.g., `order_close`, `project_assign_to_team`):

### Choosing Security Context

**Start with SECURITY INVOKER.** If all tables involved have appropriate RLS policies for the calling user, INVOKER is correct and simpler.

**Use SECURITY DEFINER only when** the operation needs to touch tables the user's role shouldn't access directly (e.g., internal audit logs, system config). Document why.

### Naming
- Use primary entity + action: `{primary_entity}_{action}`
- Place in primary entity's function file

### Pattern (SECURITY INVOKER — preferred)

```sql
CREATE OR REPLACE FUNCTION order_close(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_order record;
  v_invoice_id uuid;
BEGIN
  -- 1. Validate and lock (RLS ensures user can only see their orders)
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  IF v_order.status = 'closed' THEN
    RAISE EXCEPTION 'Order already closed: %', p_order_id;
  END IF;
  
  -- 2. Update primary entity
  UPDATE public.orders
  SET status = 'closed', closed_at = now()
  WHERE id = p_order_id;
  
  -- 3. Update related entities
  UPDATE public.inventory i
  SET quantity = quantity - ol.quantity
  FROM public.order_lines ol
  WHERE ol.order_id = p_order_id
    AND i.product_id = ol.product_id;
  
  -- 4. Create new records
  INSERT INTO public.invoices (order_id, amount, created_at)
  VALUES (p_order_id, v_order.total, now())
  RETURNING id INTO v_invoice_id;
  
  -- 5. Trigger side effects (async)
  PERFORM _internal_call_edge_function(
    'notify-order-closed',
    jsonb_build_object('order_id', p_order_id, 'invoice_id', v_invoice_id)
  );
  
  -- 6. Return result
  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'invoice_id', v_invoice_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;
```

### Key Patterns

| Pattern | Purpose |
|---------|---------|
| `FOR UPDATE` | Lock rows, prevent race conditions |
| Validate first | Check preconditions before changes |
| `SECURITY INVOKER` | Default — let RLS handle access |
| `SECURITY DEFINER` | Only when justified — document why |
| `SET search_path = ''` | Security: prevent search path injection |
| Fully qualified names | `public.tablename` for clarity |
| Structured response | Return `jsonb` with success/error + IDs |
| Exception handling | Let rollback happen, return error info |

---

## Security Checklist

- [ ] Use `SECURITY INVOKER` by default for business logic RPCs
- [ ] Use `SECURITY DEFINER` only for `_auth_*`, `_internal_*`, or justified exceptions
- [ ] Add `-- SECURITY DEFINER: required because ...` comment when using DEFINER
- [ ] Always set `search_path = ''`
- [ ] Use fully qualified table names (`public.tablename`)
- [ ] Don't manually filter by `auth.uid()` in INVOKER functions — RLS does this
- [ ] Validate input parameters before use
- [ ] Return minimal necessary data
