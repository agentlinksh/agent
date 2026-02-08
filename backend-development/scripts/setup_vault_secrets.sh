#!/usr/bin/env bash
# =============================================================================
# setup_vault_secrets.sh
# =============================================================================
# Stores the required Supabase secrets in Vault using vault.create_secret().
#
# Supports both interactive prompts and CLI arguments.
# Checks for existing secrets and offers to update them (upsert).
#
# Usage:
#   Interactive:
#     ./setup_vault_secrets.sh
#
#   With arguments:
#     ./setup_vault_secrets.sh \
#       --url "https://your-project.supabase.co" \
#       --publishable-key "sb_publishable_..." \
#       --secret-key "sb_secret_..."
#
#   Target a remote database:
#     ./setup_vault_secrets.sh --db-url "postgresql://..."
#
# Prerequisites:
#   - supabase CLI installed and project linked (for local dev)
#   - OR a direct --db-url for remote databases
#   - vault extension enabled in the database
#
# IMPORTANT — Local development (supabase start):
#   Use --url "http://host.docker.internal:54321" instead of "http://127.0.0.1:54321".
#   Postgres runs inside Docker, so 127.0.0.1 refers to the container itself.
#   host.docker.internal is the standard Docker hostname that resolves to the host.
#   This only affects the Vault secret; CLI/client code still use 127.0.0.1:54321.
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SUPABASE_URL=""
SB_PUBLISHABLE_KEY=""
SB_SECRET_KEY=""
DB_URL=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      SUPABASE_URL="$2"; shift 2 ;;
    --publishable-key)
      SB_PUBLISHABLE_KEY="$2"; shift 2 ;;
    --secret-key)
      SB_SECRET_KEY="$2"; shift 2 ;;
    --db-url)
      DB_URL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./setup_vault_secrets.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --url <url>              Supabase project URL"
      echo "  --publishable-key <key>  Publishable (anon) API key"
      echo "  --secret-key <key>       Secret (service role) API key"
      echo "  --db-url <url>           Direct database connection string (skips supabase CLI)"
      echo "  -h, --help               Show this help message"
      echo ""
      echo "If options are omitted, you will be prompted interactively."
      echo ""
      echo "LOCAL DEV NOTE:"
      echo "  Use --url \"http://host.docker.internal:54321\" (not http://127.0.0.1:54321)."
      echo "  Postgres runs inside Docker — 127.0.0.1 won't reach the host."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Interactive prompts for missing values
# ---------------------------------------------------------------------------
if [ -z "$SUPABASE_URL" ]; then
  read -rp "Supabase project URL: " SUPABASE_URL
fi

if [ -z "$SB_PUBLISHABLE_KEY" ]; then
  read -rp "Publishable (anon) key: " SB_PUBLISHABLE_KEY
fi

if [ -z "$SB_SECRET_KEY" ]; then
  read -rp "Secret (service role) key: " SB_SECRET_KEY
fi

# Validate inputs
if [ -z "$SUPABASE_URL" ] || [ -z "$SB_PUBLISHABLE_KEY" ] || [ -z "$SB_SECRET_KEY" ]; then
  echo "Error: All three values are required."
  exit 1
fi

# ---------------------------------------------------------------------------
# SQL execution helper
# ---------------------------------------------------------------------------
run_sql() {
  local sql="$1"
  if [ -n "$DB_URL" ]; then
    psql "$DB_URL" -c "$sql"
  else
    supabase db execute --sql "$sql"
  fi
}

# ---------------------------------------------------------------------------
# Upsert a single secret into Vault
# ---------------------------------------------------------------------------
upsert_secret() {
  local secret_name="$1"
  local secret_value="$2"

  # Check if secret already exists
  local exists
  exists=$(run_sql "SELECT EXISTS (SELECT 1 FROM vault.secrets WHERE name = '${secret_name}');" 2>/dev/null | grep -o 't\|f' | head -1)

  if [ "$exists" = "t" ]; then
    echo "   ↻ Updating existing secret: ${secret_name}"
    run_sql "UPDATE vault.secrets SET secret = '${secret_value}' WHERE name = '${secret_name}';" > /dev/null 2>&1
  else
    echo "   + Creating secret: ${secret_name}"
    run_sql "SELECT vault.create_secret('${secret_value}', '${secret_name}');" > /dev/null 2>&1
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo ""
echo "🔐 Setting up Vault secrets..."
echo ""

# Verify vault extension is available
if ! run_sql "SELECT 1 FROM pg_extension WHERE extname = 'supabase_vault';" > /dev/null 2>&1; then
  echo "Error: vault extension is not enabled. Enable it first:"
  echo "  CREATE EXTENSION IF NOT EXISTS supabase_vault;"
  exit 1
fi

upsert_secret "SUPABASE_URL" "$SUPABASE_URL"
upsert_secret "SB_PUBLISHABLE_KEY" "$SB_PUBLISHABLE_KEY"
upsert_secret "SB_SECRET_KEY" "$SB_SECRET_KEY"

echo ""
echo "✅ All secrets stored in Vault."
echo ""
echo "Verify with:"
echo "  SELECT name FROM vault.secrets WHERE name IN ('SUPABASE_URL', 'SB_PUBLISHABLE_KEY', 'SB_SECRET_KEY');"
