# priv/repo/migrations/20260101000001_enable_extensions.exs
defmodule Qcommerce.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  def up do
    # UUID generation — used by DEFAULT uuid_generate_v4() on all PKs
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    # PostGIS — GEOGRAPHY column type for rider/branch/address locations
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    # btree_gist — required for EXCLUDE USING GIST on fiscal_years
    # prevents overlapping fiscal year date ranges at the DB layer
    execute "CREATE EXTENSION IF NOT EXISTS btree_gist"

    # Query performance observability
    execute "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS pg_stat_statements"
    execute "DROP EXTENSION IF EXISTS btree_gist"
    execute "DROP EXTENSION IF EXISTS postgis"
    execute "DROP EXTENSION IF EXISTS \"uuid-ossp\""
  end
end
