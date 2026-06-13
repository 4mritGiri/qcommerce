# priv/repo/migrations/YYYYMMDDXXXXXX_create_local_bodies.exs
defmodule Qcommerce.Repo.Migrations.CreateLocalBodies do
  use Ecto.Migration

  def change do
    create table(:local_bodies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :district_id, references(:districts, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false, size: 120
      add :name_nepali, :string, size: 120
      add :type, :string, null: false, size: 30, default: "municipality"
      add :number_of_wards, :smallint
      add :is_service_available, :boolean, null: false, default: false

      timestamps(updated_at: false)
    end

    create index(:local_bodies, [:district_id])
    create index(:local_bodies, [:is_service_available])

    # Full-text search index on name for fast ilike queries
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    create index(
             :local_bodies,
             ["lower(name) gin_trgm_ops"],
             using: :gin,
             name: :local_bodies_name_trgm_idx
           )
  end
end
