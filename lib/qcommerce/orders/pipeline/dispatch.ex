defmodule Qcommerce.Orders.Pipeline.Dispatch do
  alias Ecto.Multi
  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Outbox}
  alias Qcommerce.Orders.Order

  def run(%Order{status: :confirmed} = order, rider_id) do
    Multi.new()
    |> Multi.update(:order, Order.status_changeset(order, :out_for_delivery, rider_id))
    |> Outbox.append(:outbox_event, fn %{order: o} ->
      {o.id, "order", "order.dispatched",
       %{order_id: o.id, branch_id: o.branch_id, rider_id: rider_id}}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} ->
        QcommerceWeb.OrderChannel.broadcast_status_update(
          order.id,
          :out_for_delivery,
          %{rider_id: rider_id}
        )

        {:ok, order}

      {:error, _, changeset, _} ->
        {:error, Error.validation(changeset)}
    end
  end

  def run(%Order{status: status}, _rider_id) do
    {:error, Error.unprocessable("Cannot dispatch order with status: #{status}")}
  end
end
