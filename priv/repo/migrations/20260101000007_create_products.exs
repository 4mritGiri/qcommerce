# priv/repo/migrations/20260101000007_create_products.exs
defmodule Qcommerce.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id,          :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :category_id, references(:categories, type: :binary_id, on_delete: :restrict), null: false
      add :name,        :string,         null: false
      add :sku,         :string,         null: false
      add :description, :text
      add :base_price,  :decimal,        null: false, precision: 10, scale: 2
      add :unit,        :string,         null: false, default: "piece"
      add :image_url,   :string
      add :is_active,   :boolean,        null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:products, [:sku])
    create index(:products, [:category_id])
    create index(:products, [:is_active], where: "is_active = true")

    create constraint(:products, :base_price_non_negative,
      check: "base_price >= 0"
    )
  end
end
