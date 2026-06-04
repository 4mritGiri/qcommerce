# priv/repo/migrations/20260101000009_create_riders.exs
defmodule Qcommerce.Repo.Migrations.CreateRiders do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE rider_status   AS ENUM ('offline', 'available', 'on_delivery')"
    execute "CREATE TYPE vehicle_type   AS ENUM ('bicycle', 'motorcycle', 'ev_scooter')"

    create table(:riders, primary_key: false) do
      add :id,                  :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id,             references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :vehicle_type,        :vehicle_type,  null: false, default: "motorcycle"
      add :license_number,      :string
      add :status,              :rider_status,  null: false, default: "offline"
      add :current_location,    :geography
      add :location_updated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:riders, [:user_id])
    create index(:riders, [:status])

    execute """
      CREATE INDEX riders_location_idx ON riders USING GIST (current_location)
    """,
    "DROP INDEX IF EXISTS riders_location_idx"
  end

  def down do
    drop table(:riders)
    execute "DROP TYPE IF EXISTS rider_status"
    execute "DROP TYPE IF EXISTS vehicle_type"
  end
end
