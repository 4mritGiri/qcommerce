# lib/qcommerce_web/channels/rider_channel.ex

defmodule QcommerceWeb.RiderChannel do
  use QcommerceWeb, :channel

  @moduledoc """
  HOT PATH — Real-time rider location tracking.

  Rider joins "rider:{rider_id}" from their mobile app.
  Location updates arrive every few seconds via handle_in("location_update").

  Design decisions:
  - Location is stored in the Rider GenServer/ETS (fast) and
    periodically flushed to PostgreSQL (durable) — NOT on every tick.
  - Branch manager dashboard subscribes to "rider:{rider_id}" to see
    live rider positions on the map.
  """

  alias Qcommerce.Delivery

  @impl true
  def join("rider:" <> rider_id, _params, socket) do
    user = socket.assigns.current_user

    # Rider can only join their own channel
    # Branch managers join via a separate admin channel (to be added)
    with {:ok, rider} <- Delivery.get_rider_by_user(user.id),
         true <- rider.id == rider_id do
      {:ok, assign(socket, :rider_id, rider_id)}
    else
      _ -> {:error, %{reason: "Unauthorized"}}
    end
  end

  @impl true
  def handle_in("location_update", %{"lat" => lat, "lng" => lng}, socket) do
    point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}
    rider_id = socket.assigns.rider_id

    # Async update — don't block the channel waiting for DB write
    Task.start(fn ->
      with {:ok, rider} <- Delivery.get_rider(rider_id) do
        Delivery.update_location(rider, point)
      end
    end)

    # Broadcast to anyone watching this rider (branch dashboard)
    broadcast!(socket, "location_updated", %{
      rider_id: rider_id,
      lat: lat,
      lng: lng,
      timestamp: DateTime.utc_now()
    })

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("status_update", %{"status" => status}, socket) do
    rider_id = socket.assigns.rider_id

    with {:ok, rider} <- Delivery.get_rider(rider_id),
         {:ok, _updated} <- Delivery.update_status(rider, String.to_existing_atom(status)) do
      broadcast!(socket, "status_updated", %{rider_id: rider_id, status: status})
      {:reply, :ok, socket}
    else
      {:error, error} -> {:reply, {:error, %{reason: inspect(error)}}, socket}
    end
  end
end
