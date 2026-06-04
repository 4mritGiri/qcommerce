# lib/qcommerce/orders/pipeline/place.ex
defmodule Qcommerce.Orders.Pipeline.Place do
  @moduledoc """
  Handles the order placement step.

  Responsibilities:
  1. Validate all order items have sufficient branch stock
  2. Create the order + order_items in one transaction
  3. Decrement inventory for each item
  4. Append outbox event so the ledger records Cash + Unearned Revenue

  Returns {:ok, order} or {:error, reason}.
  """

  alias Ecto.Multi
  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Outbox}
  alias Qcommerce.Inventory
  alias Qcommerce.Orders.{Order, OrderItem}

  @delivery_fee Decimal.new("30.00")
  @tax_rate Decimal.new("0.18")

  @spec run(map(), map()) :: {:ok, Order.t()} | {:error, Error.t()}
  def run(user, params) do
    with {:ok, items} <- validate_items(params["branch_id"], params["items"]),
         {:ok, subtotal} <- calculate_subtotal(items) do
      Multi.new()
      |> Multi.insert(:order, build_order_changeset(user, params, subtotal))
      |> Multi.run(:order_items, fn repo, %{order: order} ->
        insert_items(repo, order, items)
      end)
      |> Multi.run(:inventory, fn repo, %{order_items: order_items} ->
        decrement_inventory(repo, params["branch_id"], order_items)
      end)
      |> Outbox.append(:outbox_event, fn %{order: order} ->
        {order.id, "order", "order.placed",
         %{
           order_id: order.id,
           branch_id: order.branch_id,
           total_amount: order.total_amount
         }}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{order: order}} -> {:ok, order}
        {:error, _, changeset, _} -> {:error, Error.validation(changeset)}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp validate_items(branch_id, items) when is_list(items) and length(items) > 0 do
    results =
      Enum.map(items, fn item ->
        product_id = item["product_id"]
        qty = item["quantity"]

        case Inventory.get_inventory(branch_id, product_id) do
          {:ok, inv} when inv.quantity_on_hand >= qty and inv.is_available ->
            {:ok, %{inventory: inv, quantity: qty, unit_price: inv.selling_price}}

          {:ok, _inv} ->
            {:error, "Insufficient stock for product #{product_id}"}

          {:error, _} ->
            {:error, "Product #{product_id} not available at this branch"}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, item} -> item end)}
    else
      {:error,
       Error.unprocessable(
         "Stock validation failed",
         %{items: Enum.map(errors, fn {:error, msg} -> msg end)}
       )}
    end
  end

  defp validate_items(_branch_id, _),
    do: {:error, Error.unprocessable("Order must have at least one item")}

  defp calculate_subtotal(items) do
    subtotal =
      Enum.reduce(items, Decimal.new("0"), fn item, acc ->
        line = Decimal.mult(Decimal.new(item.quantity), item.unit_price)
        Decimal.add(acc, line)
      end)

    {:ok, subtotal}
  end

  defp build_order_changeset(user, params, subtotal) do
    Order.create_changeset(%Order{}, %{
      user_id: user.id,
      branch_id: params["branch_id"],
      address_id: params["address_id"]
    })
    |> Order.totals_changeset(subtotal, @delivery_fee, @tax_rate)
  end

  defp insert_items(repo, order, items) do
    results =
      Enum.map(items, fn item ->
        %OrderItem{}
        |> OrderItem.changeset(%{
          order_id: order.id,
          product_id: item.inventory.product_id,
          quantity: item.quantity,
          unit_price: item.unit_price
        })
        |> repo.insert()
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors),
      do: {:ok, Enum.map(results, fn {:ok, i} -> i end)},
      else: {:error, hd(errors) |> elem(1)}
  end

  defp decrement_inventory(_repo, branch_id, order_items) do
    results =
      Enum.map(order_items, fn item ->
        Inventory.decrement_stock(branch_id, item.product_id, item.quantity)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors),
      do: {:ok, :decremented},
      else: {:error, hd(errors) |> elem(1)}
  end
end
