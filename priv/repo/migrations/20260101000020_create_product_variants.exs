# priv/repo/migrations/20260101000020_create_product_variants.exs
defmodule Qcommerce.Repo.Migrations.CreateProductVariants do
  use Ecto.Migration

  def change do
    # ── Product variants — size/weight options (the "slider") ──
    # e.g. Milk: 250ml, 500ml, 1L with different prices
    create table(:product_variants, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")

      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all),
        null: false

      # "500ml", "1kg", "Pack of 3"
      add :label, :string, null: false
      # appended to parent SKU e.g. "-500ML"
      add :sku_suffix, :string
      add :sort_order, :integer, null: false, default: 0
      add :is_default, :boolean, null: false, default: false
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:product_variants, [:product_id])

    create index(:product_variants, [:product_id, :sort_order],
             name: "product_variants_ordered_idx"
           )

    # ── Variant inventory — price/stock per variant per branch ──
    create table(:variant_inventory, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")

      add :variant_id, references(:product_variants, type: :binary_id, on_delete: :delete_all),
        null: false

      add :branch_id, references(:branches, type: :binary_id, on_delete: :delete_all), null: false
      add :selling_price, :decimal, null: false, precision: 10, scale: 2
      add :quantity_on_hand, :integer, null: false, default: 0
      add :is_available, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec, inserted_at: false)
    end

    create unique_index(:variant_inventory, [:variant_id, :branch_id])
    create index(:variant_inventory, [:branch_id])

    # ── Product images — multiple images per product ──
    create table(:product_images, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")

      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all),
        null: false

      add :url, :string, null: false
      add :alt_text, :string
      add :sort_order, :integer, null: false, default: 0
      add :is_primary, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:product_images, [:product_id])
  end
end
