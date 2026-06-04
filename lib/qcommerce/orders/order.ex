# lib/qcommerce/orders/order.ex
defmodule Qcommerce.Orders.Order do
  use Qcommerce.Core.Schema

  alias Qcommerce.Accounts.{User, Address}
  alias Qcommerce.Platform.Branch
  alias Qcommerce.Delivery.Rider
  alias Qcommerce.Orders.OrderItem

  @statuses ~w(pending confirmed picking ready out_for_delivery delivered cancelled rejected)a

  schema "orders" do
    belongs_to :user, User
    belongs_to :branch, Branch
    belongs_to :address, Address
    belongs_to :rider, Rider

    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :subtotal, :decimal, default: 0
    field :delivery_fee, :decimal, default: 0
    field :tax_amount, :decimal, default: 0
    field :total_amount, :decimal, default: 0
    field :cancellation_reason, :string

    # Explicit lifecycle timestamps — nil until the event occurs.
    # We do NOT use timestamps(inserted_at: :placed_at) because Ecto
    # would conflict with this explicit field definition.
    # placed_at is set manually in create_changeset/2.
    field :placed_at, :utc_datetime_usec
    field :confirmed_at, :utc_datetime_usec
    field :picked_at, :utc_datetime_usec
    field :dispatched_at, :utc_datetime_usec
    field :delivered_at, :utc_datetime_usec
    field :cancelled_at, :utc_datetime_usec

    has_many :order_items, OrderItem

    # Standard timestamps: inserted_at + updated_at
    # inserted_at ≈ placed_at in practice but kept separate so the
    # DB audit trail is independent of business event timestamps.
    timestamps()
  end

  @required [:user_id, :branch_id, :address_id]
  @optional [:rider_id, :delivery_fee, :tax_amount, :cancellation_reason]

  def create_changeset(order, attrs) do
    order
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> put_change(:status, :pending)
    |> put_change(:placed_at, DateTime.utc_now())
    |> assoc_constraint(:user)
    |> assoc_constraint(:branch)
    |> assoc_constraint(:address)
  end

  def status_changeset(order, status, extra_attrs \\ %{}) when status in @statuses do
    order
    |> cast(extra_attrs, [:cancellation_reason, :rider_id])
    |> put_change(:status, status)
    |> then(fn cs ->
      case timestamp_for(status) do
        nil -> cs
        field -> put_change(cs, field, DateTime.utc_now())
      end
    end)
  end

  def totals_changeset(order, subtotal, delivery_fee, tax_rate) do
    tax_amount = Decimal.mult(subtotal, tax_rate)
    total_amount = Decimal.add(subtotal, Decimal.add(delivery_fee, tax_amount))

    change(order,
      subtotal: subtotal,
      delivery_fee: delivery_fee,
      tax_amount: tax_amount,
      total_amount: total_amount
    )
  end

  defp timestamp_for(:confirmed), do: :confirmed_at
  defp timestamp_for(:picking), do: :picked_at
  defp timestamp_for(:out_for_delivery), do: :dispatched_at
  defp timestamp_for(:delivered), do: :delivered_at
  defp timestamp_for(:cancelled), do: :cancelled_at
  defp timestamp_for(:rejected), do: :cancelled_at
  defp timestamp_for(_), do: nil
end
