# lib/qcommerce/orders/pipeline/deliver.ex

defmodule Qcommerce.Orders.Pipeline.Deliver do
  @moduledoc """
  Marks an order as delivered — transitions out_for_delivery → delivered.

  This is the most important outbox event in the ledger:
  it triggers the Broadway/Oban pipeline to debit Unearned Revenue
  and credit Recognized Revenue (accrual accounting).
  """

  alias Ecto.Multi
  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Outbox}
  alias Qcommerce.Orders.Order

  @spec run(Order.t()) :: {:ok, Order.t()} | {:error, Error.t()}
  def run(%Order{status: :out_for_delivery} = order) do
    Multi.new()
    |> Multi.update(:order, Order.status_changeset(order, :delivered))
    |> Outbox.append(:outbox_event, fn %{order: o} ->
      {o.id, "order", "order.delivered",
       %{
         order_id: o.id,
         branch_id: o.branch_id,
         total_amount: o.total_amount,
         delivered_at: o.delivered_at
       }}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} -> {:ok, order}
      {:error, _, changeset, _} -> {:error, Error.validation(changeset)}
    end
  end

  def run(%Order{status: status}) do
    {:error, Error.unprocessable("Cannot deliver order with status: #{status}")}
  end
end
