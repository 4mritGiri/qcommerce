# lib/qcommerce_web/controllers/api/v1/order_controller.ex
defmodule QcommerceWeb.Api.V1.OrderController do
  use QcommerceWeb, :controller

  alias Qcommerce.Orders
  alias QcommerceWeb.Plugs.RateLimitPlug

  action_fallback QcommerceWeb.FallbackController

  plug RateLimitPlug, limiter: :api

  @doc "POST /api/v1/orders — place a new order"
  def create(conn, params) do
    user = conn.assigns.current_user

    with {:ok, order} <- Orders.place_order(user, params) do
      conn
      |> put_status(:created)
      |> json(%{data: order})
    end
  end

  @doc "GET /api/v1/orders — list current user's orders"
  def index(conn, params) do
    user = conn.assigns.current_user

    with {:ok, {orders, meta}} <- Orders.list_user_orders(user.id, params) do
      json(conn, %{data: orders, meta: meta})
    end
  end

  @doc "GET /api/v1/orders/:id — get a single order"
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, order} <- Orders.get_user_order(id, user.id) do
      json(conn, %{data: order})
    end
  end

  @doc "DELETE /api/v1/orders/:id — cancel an order"
  def cancel(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    reason = params["reason"] || "Cancelled by customer"

    with {:ok, order} <- Orders.get_user_order(id, user.id),
         {:ok, cancelled_order} <- Orders.cancel_order(order, reason) do
      json(conn, %{data: cancelled_order})
    end
  end
end
