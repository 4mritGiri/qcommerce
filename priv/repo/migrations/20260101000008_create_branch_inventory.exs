# priv/repo/migrations/20260101000008_create_branch_inventory.exs
defmodule Qcommerce.Repo.Migrations.CreateBranchInventory do
  use Ecto.Migration

  def change do
    create table(:branch_inventory, primary_key: false) do
      add :id,                :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :branch_id,         references(:branches, type: :binary_id, on_delete: :delete_all),  null: false
      add :product_id,        references(:products, type: :binary_id, on_delete: :delete_all),  null: false
      add :quantity_on_hand,  :integer, null: false, default: 0
      add :reorder_threshold, :integer, null: false, default: 10
      add :selling_price,     :decimal, null: false, precision: 10, scale: 2
      add :is_available,      :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec, inserted_at: false)
    end

    create unique_index(:branch_inventory, [:branch_id, :product_id])
    create index(:branch_inventory, [:branch_id])
    create index(:branch_inventory, [:product_id])
    create index(:branch_inventory, [:branch_id, :is_available],
      where: "is_available = true",
      name:  "branch_inventory_available_idx"
    )

    create constraint(:branch_inventory, :quantity_non_negative,
      check: "quantity_on_hand >= 0"
    )
    create constraint(:branch_inventory, :selling_price_non_negative,
      check: "selling_price >= 0"
    )
    create constraint(:branch_inventory, :reorder_threshold_positive,
      check: "reorder_threshold > 0"
    )
  end
end
