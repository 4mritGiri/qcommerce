# lib/qcommerce/orders/pipeline/confirm.ex

defmodule Qcommerce.Orders.Pipeline.Confirm do
  @moduledoc """
  Branch confirms an order — transitions pending → confirmed.
  Appends outbox event so the ledger records the confirmation timestamp.
  """

  alias Ecto.Multi
  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Outbox}
  alias Qcommerce.Orders.Order

  @spec run(Order.t()) :: {:ok, Order.t()} | {:error, Error.t()}
  def run(%Order{status: :pending} = order) do
    Multi.new()
    |> Multi.update(:order, Order.status_changeset(order, :confirmed))
    |> Outbox.append(:outbox_event, fn %{order: o} ->
      {o.id, "order", "order.confirmed", %{order_id: o.id, branch_id: o.branch_id}}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} ->
        QcommerceWeb.OrderChannel.broadcast_status_update(order.id, :confirmed)
        {:ok, order}

      {:error, _, changeset, _} ->
        {:error, Error.validation(changeset)}
    end
  end

  def run(%Order{status: status}) do
    {:error, Error.unprocessable("Cannot confirm order with status: #{status}")}
  end
end
