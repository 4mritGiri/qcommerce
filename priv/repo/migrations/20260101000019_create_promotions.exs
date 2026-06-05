# priv/repo/migrations/20260101000019_create_promotions.exs
defmodule Qcommerce.Repo.Migrations.CreatePromotions do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE discount_type AS ENUM ('percent', 'fixed')"
    execute "CREATE TYPE coupon_scope  AS ENUM ('global', 'per_user', 'first_order')"

    # ── Discounts — applied automatically to products/categories ──
    create table(:discounts, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :discount_type, :discount_type, null: false
      add :value, :decimal, null: false, precision: 10, scale: 2
      add :min_order_value, :decimal, precision: 10, scale: 2
      # Scope: applies to a specific product, category, or entire branch
      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all)
      add :category_id, references(:categories, type: :binary_id, on_delete: :delete_all)
      add :branch_id, references(:branches, type: :binary_id, on_delete: :delete_all)
      add :starts_at, :utc_datetime_usec, null: false
      add :ends_at, :utc_datetime_usec, null: false
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:discounts, [:product_id])
    create index(:discounts, [:category_id])
    create index(:discounts, [:branch_id])

    create index(:discounts, [:is_active, :starts_at, :ends_at],
             name: "discounts_active_window_idx"
           )

    execute """
      ALTER TABLE discounts ADD CONSTRAINT discount_value_positive CHECK (value > 0)
    """

    execute """
      ALTER TABLE discounts ADD CONSTRAINT discount_window_valid CHECK (ends_at > starts_at)
    """

    # ── Coupons — user-entered codes ──
    create table(:coupons, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :code, :string, null: false
      add :discount_type, :discount_type, null: false
      add :value, :decimal, null: false, precision: 10, scale: 2
      add :scope, :coupon_scope, null: false, default: "global"
      add :min_order_value, :decimal, precision: 10, scale: 2
      # NULL = unlimited
      add :max_uses, :integer
      add :used_count, :integer, null: false, default: 0
      add :starts_at, :utc_datetime_usec, null: false
      add :ends_at, :utc_datetime_usec, null: false
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:coupons, [:code])
    create index(:coupons, [:is_active])

    execute """
      ALTER TABLE coupons ADD CONSTRAINT coupon_value_positive CHECK (value > 0)
    """

    execute """
      ALTER TABLE coupons ADD CONSTRAINT coupon_window_valid CHECK (ends_at > starts_at)
    """

    # ── Coupon redemptions — tracks who used which coupon ──
    create table(:coupon_redemptions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :coupon_id, references(:coupons, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:coupon_redemptions, [:coupon_id, :user_id, :order_id])
    create index(:coupon_redemptions, [:user_id])
  end

  def down do
    drop table(:coupon_redemptions)
    drop table(:coupons)
    drop table(:discounts)
    execute "DROP TYPE IF EXISTS coupon_scope"
    execute "DROP TYPE IF EXISTS discount_type"
  end
end
