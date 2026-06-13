# priv/repo/migrations/YYYYMMDDXXXXXX_create_provinces.exs
defmodule Qcommerce.Repo.Migrations.CreateProvinces do
  use Ecto.Migration

  def change do
    create table(:provinces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false, size: 10
      add :name, :string, null: false, size: 120
      add :name_nepali, :string, size: 120

      timestamps(updated_at: false)
    end

    create unique_index(:provinces, [:code])
    create unique_index(:provinces, [:name])
  end
end
