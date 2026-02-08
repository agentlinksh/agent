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
mkdir -p "$SCHEMAS_DIR/10_types"
mkdir -p "$SCHEMAS_DIR/20_tables"
mkdir -p "$SCHEMAS_DIR/30_constraints"
mkdir -p "$SCHEMAS_DIR/40_indexes"
mkdir -p "$SCHEMAS_DIR/50_functions/_internal"
mkdir -p "$SCHEMAS_DIR/50_functions/_auth"
mkdir -p "$SCHEMAS_DIR/60_triggers"
mkdir -p "$SCHEMAS_DIR/70_policies"
mkdir -p "$SCHEMAS_DIR/80_views"

# Create .gitkeep files to preserve empty directories
touch "$SCHEMAS_DIR/10_types/.gitkeep"
touch "$SCHEMAS_DIR/20_tables/.gitkeep"
touch "$SCHEMAS_DIR/30_constraints/.gitkeep"
touch "$SCHEMAS_DIR/40_indexes/.gitkeep"
touch "$SCHEMAS_DIR/50_functions/.gitkeep"
touch "$SCHEMAS_DIR/50_functions/_internal/.gitkeep"
touch "$SCHEMAS_DIR/50_functions/_auth/.gitkeep"
touch "$SCHEMAS_DIR/60_triggers/.gitkeep"
touch "$SCHEMAS_DIR/70_policies/.gitkeep"
touch "$SCHEMAS_DIR/80_views/.gitkeep"

echo "✅ Created directory structure:"
echo ""
echo "   supabase/schemas/"
echo "   ├── 10_types/"
echo "   ├── 20_tables/"
echo "   ├── 30_constraints/"
echo "   ├── 40_indexes/"
echo "   ├── 50_functions/"
echo "   │   ├── _internal/"
echo "   │   └── _auth/"
echo "   ├── 60_triggers/"
echo "   ├── 70_policies/"
echo "   └── 80_views/"
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

| Entity | Table | Constraints | Indexes | Functions | Auth | Triggers | Policies | Views |
|--------|-------|-------------|---------|-----------|------|----------|----------|-------|
| | | | | | | | | |

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
echo "   1. Copy setup.sql functions to 50_functions/_internal/ (from assets/setup.sql)"
echo "   2. Configure Vault secrets"
echo "   3. Add your first entity to ENTITIES.md"
echo "   4. Start creating schema files"
