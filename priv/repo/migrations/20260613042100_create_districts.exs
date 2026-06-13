# priv/repo/migrations/YYYYMMDDXXXXXX_create_districts.exs
defmodule Qcommerce.Repo.Migrations.CreateDistricts do
  use Ecto.Migration

  def change do
    create table(:districts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :province_id, references(:provinces, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false, size: 120
      add :name_nepali, :string, size: 120

      timestamps(updated_at: false)
    end

    create unique_index(:districts, [:name])
    create index(:districts, [:province_id])
  end
end
