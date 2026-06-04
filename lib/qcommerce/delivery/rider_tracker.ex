# lib/qcommerce/delivery/rider_tracker.ex
defmodule Qcommerce.Delivery.RiderTracker do
  use GenServer

  # Client API
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def update_location(rider_id, coords) do
    GenServer.cast(__MODULE__, {:update, rider_id, coords})
  end

  def get_location(rider_id) do
    GenServer.call(__MODULE__, {:get, rider_id})
  end

  # Server callbacks
  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:update, rider_id, coords}, state) do
    {:noreply, Map.put(state, rider_id, Map.put(coords, :updated_at, DateTime.utc_now()))}
  end

  @impl true
  def handle_call({:get, rider_id}, _from, state) do
    {:reply, Map.get(state, rider_id), state}
  end
end
