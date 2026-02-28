#!/usr/bin/env bash
# =============================================================================
# scaffold_schemas.sh
# =============================================================================
# Initializes the schema folder structure for a Supabase project.
#
# Usage:
#   ./scaffold_schemas.sh [base_path]
#
# Arguments:
#   base_path  Optional. Defaults to current directory.
#              The script creates supabase/schemas/ under this path.
#
# Example:
#   ./scaffold_schemas.sh /path/to/my-project
# =============================================================================

set -e

BASE_PATH="${1:-.}"
SCHEMAS_DIR="$BASE_PATH/supabase/schemas"

echo "🚀 Scaffolding Supabase schema structure..."
echo "   Location: $SCHEMAS_DIR"
echo ""

# Create main directories
mkdir -p "$SCHEMAS_DIR/public"
mkdir -p "$SCHEMAS_DIR/api"

# Create _schemas.sql for schema creation + grants
if [ ! -f "$SCHEMAS_DIR/_schemas.sql" ]; then
  cat > "$SCHEMAS_DIR/_schemas.sql" << 'SQLEOF'
-- Schema creation and role grants
CREATE SCHEMA IF NOT EXISTS api;

-- Grant usage so PostgREST can discover functions in the api schema
GRANT USAGE ON SCHEMA api TO anon, authenticated, service_role;

-- Grant execute on all existing functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO anon, authenticated, service_role;

-- Auto-grant execute on future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA api
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
SQLEOF
  echo "✅ Created _schemas.sql"
else
  echo "ℹ️  _schemas.sql already exists, skipping"
fi

# Create .gitkeep files to preserve empty directories
touch "$SCHEMAS_DIR/public/.gitkeep"
touch "$SCHEMAS_DIR/api/.gitkeep"

echo ""
echo "✅ Created directory structure:"
echo ""
echo "   supabase/schemas/"
echo "   ├── _schemas.sql        # CREATE SCHEMA api; + role grants"
echo "   ├── public/             # Entity files (table + indexes + triggers + policies)"
echo "   │   ├── _auth.sql       # Shared _auth_* helper functions"
echo "   │   └── _internal.sql   # Shared _internal_* utility functions"
echo "   └── api/                # Client-facing RPCs (api.* functions + grants)"
echo ""

# Create ENTITIES.md if it doesn't exist
if [ ! -f "$BASE_PATH/ENTITIES.md" ]; then
  cat > "$BASE_PATH/ENTITIES.md" << 'EOF'
# Entity Registry

This file tracks all database entities in the project. Keep this in sync when creating or modifying schema files.

## Entities

List all entities (singular form used for naming functions):

-

## Schema File Mapping

| Entity | Entity File | API Functions |
|--------|-------------|---------------|
| | `public/<plural>.sql` | `api/<singular>.sql` |

## Function Inventory

### Business Logic RPCs

| Entity | Function | Description |
|--------|----------|-------------|
| | | |

### Auth Functions

| Entity | Function | Used By Policy |
|--------|----------|----------------|
| | | |

### Internal Functions

| Function | Description |
|----------|-------------|
| `_internal_get_secret` | Retrieves secret from Vault by name |
| `_internal_call_edge_function` | Invokes edge function via pg_net |
EOF
  echo "✅ Created ENTITIES.md"
else
  echo "ℹ️  ENTITIES.md already exists, skipping"
fi

echo ""
echo "🎉 Done! Next steps:"
echo "   1. Copy setup.sql functions to public/_internal.sql (from assets/setup.sql)"
echo "   2. Configure Vault secrets"
echo "   3. Add your first entity to ENTITIES.md"
echo "   4. Start creating schema files"
