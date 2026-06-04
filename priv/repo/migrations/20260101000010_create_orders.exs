# priv/repo/migrations/20260101000010_create_orders.exs
defmodule Qcommerce.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def up do
    execute """
      CREATE TYPE order_status AS ENUM (
        'pending', 'confirmed', 'picking', 'ready',
        'out_for_delivery', 'delivered', 'cancelled', 'rejected'
      )
    """

    create table(:orders, primary_key: false) do
      add :id,                  :binary_id,   primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id,             references(:users,     type: :binary_id, on_delete: :restrict), null: false
      add :branch_id,           references(:branches,  type: :binary_id, on_delete: :restrict), null: false
      add :address_id,          references(:addresses, type: :binary_id, on_delete: :restrict), null: false
      add :rider_id,            references(:riders,    type: :binary_id, on_delete: :nilify_all)
      add :status,              :order_status, null: false, default: "pending"
      add :subtotal,            :decimal,      null: false, default: 0, precision: 10, scale: 2
      add :delivery_fee,        :decimal,      null: false, default: 0, precision: 10, scale: 2
      add :tax_amount,          :decimal,      null: false, default: 0, precision: 10, scale: 2
      add :total_amount,        :decimal,      null: false, default: 0, precision: 10, scale: 2
      add :cancellation_reason, :string
      add :placed_at,           :utc_datetime_usec
      add :confirmed_at,        :utc_datetime_usec
      add :picked_at,           :utc_datetime_usec
      add :dispatched_at,       :utc_datetime_usec
      add :delivered_at,        :utc_datetime_usec
      add :cancelled_at,        :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:orders, [:user_id])
    create index(:orders, [:branch_id])
    create index(:orders, [:rider_id], where: "rider_id IS NOT NULL")
    create index(:orders, [:status])
    create index(:orders, [:branch_id, :status], name: "orders_branch_status_idx")
    create index(:orders, [:inserted_at])

    execute """
      ALTER TABLE orders
      ADD CONSTRAINT orders_amounts_non_negative
      CHECK (subtotal >= 0 AND delivery_fee >= 0 AND tax_amount >= 0 AND total_amount >= 0)
    """

    execute """
      ALTER TABLE orders
      ADD CONSTRAINT orders_total_consistent
      CHECK (total_amount = subtotal + delivery_fee + tax_amount)
    """
  end

  def down do
    drop table(:orders)
    execute "DROP TYPE IF EXISTS order_status"
  end
end
