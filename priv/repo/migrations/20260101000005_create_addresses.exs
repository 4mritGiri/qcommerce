# priv/repo/migrations/20260101000005_create_addresses.exs
defmodule Qcommerce.Repo.Migrations.CreateAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses, primary_key: false) do
      add :id,         :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id,    references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :label,      :string,    null: false, default: "Home"
      add :line1,      :string,    null: false
      add :line2,      :string
      add :city,       :string,    null: false
      add :location,   :geography
      add :is_default, :boolean,   null: false, default: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:addresses, [:user_id])

    execute """
      CREATE INDEX addresses_location_idx ON addresses USING GIST (location)
    """,
    "DROP INDEX IF EXISTS addresses_location_idx"
  end
end
