# lib/qcommerce/orders/order_item.ex
defmodule Qcommerce.Orders.OrderItem do
  use Qcommerce.Core.Schema

  @moduledoc """
  A single line item within an order.
  status tracks picker outcome per item — enables partial doorstep rejection
  to generate line-item reversal journals rather than full-order reversals.
  """

  alias Qcommerce.Orders.Order
  alias Qcommerce.Catalog.Product

  @statuses ~w(pending picked substituted rejected)a

  schema "order_items" do
    belongs_to :order, Order
    belongs_to :product, Product

    field :quantity, :integer
    field :unit_price, :decimal
    field :line_total, :decimal
    field :status, Ecto.Enum, values: @statuses, default: :pending

    timestamps(updated_at: false)
  end

  @required [:order_id, :product_id, :quantity, :unit_price]

  def changeset(item, attrs) do
    item
    |> cast(attrs, @required ++ [:status])
    |> validate_required(@required)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> compute_line_total()
    |> assoc_constraint(:order)
    |> assoc_constraint(:product)
  end

  def status_changeset(item, status) when status in @statuses do
    change(item, status: status)
  end

  defp compute_line_total(changeset) do
    qty = get_field(changeset, :quantity)
    price = get_field(changeset, :unit_price)

    if qty && price do
      put_change(changeset, :line_total, Decimal.mult(Decimal.new(qty), price))
    else
      changeset
    end
  end
end
