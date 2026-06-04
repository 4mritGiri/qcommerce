# priv/repo/migrations/20260101000006_create_categories.exs
defmodule Qcommerce.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id,         :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      # Self-referential — NULL means root category
      add :parent_id,  references(:categories, type: :binary_id, on_delete: :nilify_all)
      add :name,       :string,  null: false
      add :slug,       :string,  null: false
      add :image_url,  :string
      add :sort_order, :integer, null: false, default: 0
      add :is_active,  :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:categories, [:slug])
    create index(:categories, [:parent_id])
  end
end
