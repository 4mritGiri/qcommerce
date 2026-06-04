# lib/qcommerce/inventory/branch_inventory.ex

defmodule Qcommerce.Inventory.BranchInventory do
  use Qcommerce.Core.Schema

  @moduledoc """
  Per-branch stock record for a product.
  selling_price allows per-branch price overrides independent of catalog base_price.
  quantity_on_hand is decremented by picker actions and replenished by stock receipts.
  """

  alias Qcommerce.Platform.Branch
  alias Qcommerce.Catalog.Product

  schema "branch_inventory" do
    belongs_to :branch, Branch
    belongs_to :product, Product

    field :quantity_on_hand, :integer, default: 0
    field :reorder_threshold, :integer, default: 10
    field :selling_price, :decimal
    field :is_available, :boolean, default: true

    timestamps(inserted_at: false, updated_at: :updated_at)
  end

  @required [:branch_id, :product_id, :selling_price]
  @optional [:quantity_on_hand, :reorder_threshold, :is_available]

  def changeset(inv, attrs) do
    inv
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:selling_price, greater_than_or_equal_to: 0)
    |> validate_number(:quantity_on_hand, greater_than_or_equal_to: 0)
    |> validate_number(:reorder_threshold, greater_than: 0)
    |> unique_constraint([:branch_id, :product_id])
    |> assoc_constraint(:branch)
    |> assoc_constraint(:product)
  end

  @doc "Decrement stock when an item is picked. Caller must check result."
  def decrement_changeset(inv, qty) when qty > 0 do
    new_qty = inv.quantity_on_hand - qty

    inv
    |> change(quantity_on_hand: new_qty)
    |> validate_number(:quantity_on_hand,
      greater_than_or_equal_to: 0,
      message: "insufficient stock"
    )
    |> maybe_mark_unavailable(new_qty)
  end

  defp maybe_mark_unavailable(changeset, qty) when qty <= 0,
    do: put_change(changeset, :is_available, false)

  defp maybe_mark_unavailable(changeset, _qty), do: changeset
end
