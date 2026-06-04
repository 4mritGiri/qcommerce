# lib/qcommerce/orders/orders.ex
defmodule Qcommerce.Orders do
  @moduledoc """
  Public context API for order management.
  Mutations delegate to Pipeline step modules.
  Reads live here directly.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Query}
  alias Qcommerce.Orders.Order
  alias Qcommerce.Orders.Pipeline.{Place, Confirm, Deliver}

  # ---------------------------------------------------------------------------
  # Reads
  # ---------------------------------------------------------------------------

  def get_order(id) do
    case Repo.get(Order, id) do
      nil -> {:error, Error.not_found("Order", id)}
      order -> {:ok, Repo.preload(order, [:order_items, :rider, :address])}
    end
  end

  def get_user_order(order_id, user_id) do
    case Repo.get_by(Order, id: order_id, user_id: user_id) do
      nil -> {:error, Error.not_found("Order", order_id)}
      order -> {:ok, Repo.preload(order, [:order_items])}
    end
  end

  def list_user_orders(user_id, params \\ []) do
    base =
      Order
      |> Query.for_user(user_id)
      |> Query.filter_by(:status, params[:status])
      |> order_by([o], desc: o.inserted_at)

    total = Repo.aggregate(base, :count)
    {paginated, meta} = Query.paginate(base, page: params[:page], per_page: params[:per_page])

    {:ok, {Repo.all(paginated), Map.put(meta, :total, total)}}
  end

  def list_branch_orders(branch_id, params \\ []) do
    base =
      Order
      |> Query.for_branch(branch_id)
      |> Query.filter_by(:status, params[:status])
      |> Query.date_range(:inserted_at, params[:from], params[:to])
      |> order_by([o], desc: o.inserted_at)

    total = Repo.aggregate(base, :count)
    {paginated, meta} = Query.paginate(base, page: params[:page], per_page: params[:per_page])

    {:ok, {Repo.all(paginated), Map.put(meta, :total, total)}}
  end

  def list_active_orders(branch_id) do
    active = [:confirmed, :picking, :ready, :out_for_delivery]

    orders =
      Order
      |> Query.for_branch(branch_id)
      |> where([o], o.status in ^active)
      |> order_by([o], asc: o.inserted_at)
      |> Query.with_preloads([:order_items, :rider])
      |> Repo.all()

    {:ok, orders}
  end

  # ---------------------------------------------------------------------------
  # Writes — delegated to Pipeline steps
  # ---------------------------------------------------------------------------

  def place_order(user, params), do: Place.run(user, params)
  def confirm_order(%Order{} = order), do: Confirm.run(order)
  def deliver_order(%Order{} = order), do: Deliver.run(order)

  def cancel_order(%Order{status: status} = order, reason)
      when status in [:pending, :confirmed, :picking, :ready] do
    order
    |> Order.status_changeset(:cancelled, %{cancellation_reason: reason})
    |> Repo.update()
    |> handle_result()
  end

  def cancel_order(%Order{status: status}, _reason) do
    {:error, Error.unprocessable("Cannot cancel order with status: #{status}")}
  end

  def assign_rider(%Order{} = order, rider_id) do
    order
    |> Order.status_changeset(:out_for_delivery, %{rider_id: rider_id})
    |> Repo.update()
    |> handle_result()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp handle_result({:ok, record}), do: {:ok, record}
  defp handle_result({:error, %Ecto.Changeset{} = cs}), do: {:error, Error.validation(cs)}
  defp handle_result({:error, reason}), do: {:error, Error.internal(inspect(reason))}
end
