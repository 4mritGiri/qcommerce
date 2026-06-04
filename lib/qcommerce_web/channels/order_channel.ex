# lib/qcommerce_web/channels/order_channel.ex

defmodule QcommerceWeb.OrderChannel do
  use QcommerceWeb, :channel

  @moduledoc """
  Real-time order status updates pushed to the customer's mobile app.
  Customer joins "order:{order_id}" to receive live status transitions.

  HOT PATH — this channel must never block.
  All heavy lifting (ledger writes, inventory updates) happens
  asynchronously via Oban. This channel only broadcasts status changes.
  """

  alias Qcommerce.Orders

  @impl true
  def join("order:" <> order_id, _params, socket) do
    user = socket.assigns.current_user

    case Orders.get_user_order(order_id, user.id) do
      {:ok, order} ->
        {:ok, %{status: order.status}, assign(socket, :order_id, order_id)}

      {:error, _} ->
        {:error, %{reason: "Order not found or access denied"}}
    end
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{status: "pong"}}, socket}
  end

  # Called by the Orders context after a status transition
  # to push real-time updates to the connected customer
  def broadcast_status_update(order_id, status, extra \\ %{}) do
    QcommerceWeb.Endpoint.broadcast(
      "order:#{order_id}",
      "status_updated",
      Map.merge(%{order_id: order_id, status: status}, extra)
    )
  end
end
