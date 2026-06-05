# priv/repo/migrations/20260101000021_create_slides.exs
defmodule Qcommerce.Repo.Migrations.CreateSlides do
  use Ecto.Migration

  def change do
    # ── Slides — hero carousel ──
    create table(:slides, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :theme, :string, null: false
      add :tag, :string, null: false
      add :heading, :string, null: false
      add :sub, :string
      add :cta_label, :string, default: "Shop now"
      add :emojis, {:array, :string}, default: []
      add :position, :integer, null: false, default: 0
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:slides, [:is_active, :position], name: "slides_active_position_idx")

    # ── slide_products — join table (many_to_many) ──
    create table(:slide_products, primary_key: false) do
      add :slide_id, references(:slides, type: :binary_id, on_delete: :delete_all), null: false

      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all),
        null: false
    end

    create unique_index(:slide_products, [:slide_id, :product_id])
    create index(:slide_products, [:product_id])

    # ── Flash sales ──
    create table(:flash_sales, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :label, :string, null: false
      add :ends_at, :utc_datetime_usec, null: false
      add :discount_pct, :integer, null: false, default: 0
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:flash_sales, [:is_active, :ends_at], name: "flash_sales_active_idx")

    # Add emoji + old_price columns to products if not already there
    # (old_price was added to schema but the original migration didn't have it)
    alter table(:products) do
      add_if_not_exists :old_price, :decimal, precision: 10, scale: 2
      add_if_not_exists :emoji, :string, default: "🛒"
    end
  end
end
