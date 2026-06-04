# priv/repo/migrations/20260101000002_create_branches.exs
defmodule Qcommerce.Repo.Migrations.CreateBranches do
  use Ecto.Migration

  def change do
    create table(:branches, primary_key: false) do
      add :id,                  :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :code,                :string,    null: false
      add :name,                :string,    null: false
      add :address_line,        :string,    null: false
      add :city,                :string,    null: false
      # GEOGRAPHY(POINT, 4326) — WGS84 GPS coordinates
      # geo_postgis maps this to %Geo.Point{} in Elixir
      add :location,            :geography, null: true
      add :catchment_radius_m,  :integer,   null: false, default: 3000
      add :is_active,           :boolean,   null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:branches, [:code])
    create index(:branches, [:is_active], where: "is_active = true")

    # Spatial index — used by ST_DWithin for rider proximity queries
    execute """
      CREATE INDEX branches_location_idx ON branches USING GIST (location)
    """,
    "DROP INDEX IF EXISTS branches_location_idx"

    # Ensure catchment radius is always positive
    create constraint(:branches, :catchment_radius_positive,
      check: "catchment_radius_m > 0"
    )
  end
end
