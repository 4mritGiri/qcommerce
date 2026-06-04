# lib/qcommerce_web/controllers/api/v1/cart_controller.ex
defmodule QcommerceWeb.Api.V1.CartController do
  use QcommerceWeb, :controller

  @moduledoc """
  Cart is transient state — stored in client memory or a session,
  not in the database. The server validates stock availability
  when the order is placed, not during cart operations.

  This controller handles cart validation only:
    POST /api/v1/cart/validate — check all items are in stock before checkout
  """

  alias Qcommerce.Inventory

  action_fallback QcommerceWeb.FallbackController

  @doc "POST /api/v1/cart/validate"
  def validate(conn, %{"branch_id" => branch_id, "items" => items}) do
    results =
      Enum.map(items, fn %{"product_id" => pid, "quantity" => qty} ->
        case Inventory.get_inventory(branch_id, pid) do
          {:ok, inv} when inv.quantity_on_hand >= qty and inv.is_available ->
            %{product_id: pid, available: true, selling_price: inv.selling_price}

          {:ok, inv} ->
            %{
              product_id: pid,
              available: false,
              reason: "Only #{inv.quantity_on_hand} units available"
            }

          {:error, _} ->
            %{product_id: pid, available: false, reason: "Not available at this branch"}
        end
      end)

    all_available = Enum.all?(results, & &1.available)

    conn
    |> put_status(if all_available, do: :ok, else: :unprocessable_entity)
    |> json(%{data: %{valid: all_available, items: results}})
  end
end
