# priv/repo/migrations/20260101000011_create_order_items.exs
defmodule Qcommerce.Repo.Migrations.CreateOrderItems do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE order_item_status AS ENUM ('pending', 'picked', 'substituted', 'rejected')"

    create table(:order_items, primary_key: false) do
      add :id,         :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :order_id,   references(:orders,   type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :restrict),   null: false
      add :quantity,   :integer, null: false
      add :unit_price, :decimal, null: false, precision: 10, scale: 2
      add :line_total, :decimal, null: false, precision: 10, scale: 2
      add :status,     :order_item_status, null: false, default: "pending"

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])

    execute """
      ALTER TABLE order_items
      ADD CONSTRAINT order_items_quantity_positive CHECK (quantity > 0)
    """

    execute """
      ALTER TABLE order_items
      ADD CONSTRAINT order_items_line_total_consistent
      CHECK (line_total = quantity * unit_price)
    """
  end

  def down do
    drop table(:order_items)
    execute "DROP TYPE IF EXISTS order_item_status"
  end
end
