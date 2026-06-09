defmodule QcommerceWeb.CartShareLive do
  @moduledoc """
  Handles the /cart/share/:token route.
  Shows the shared items and lets the visitor add them all to their own cart.
  """
  use QcommerceWeb, :live_view

  alias QcommerceWeb.Paths
  alias Qcommerce.Cart
  alias Qcommerce.Cart.CartShare

  @tick_ms 1_000

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@tick_ms, self(), :tick)

    case Cart.get_share(token) do
      {:ok, share} ->
        items = Cart.deserialize_items(share)

        {:ok,
         socket
         |> assign(:page_title, "Cart shared with you — QCommerce")
         |> assign(:share, share)
         |> assign(:items, items)
         |> assign(:seconds_left, CartShare.seconds_remaining(share))
         |> assign(:added, false)
         |> assign(:error, nil), layout: false}

      {:error, :expired} ->
        {:ok,
         socket
         |> assign(:page_title, "Link expired")
         |> assign(:share, nil)
         |> assign(:items, %{})
         |> assign(:seconds_left, 0)
         |> assign(:added, false)
         |> assign(:error, :expired), layout: false}

      {:error, :not_found} ->
        {:ok,
         socket
         |> assign(:page_title, "Link not found")
         |> assign(:share, nil)
         |> assign(:items, %{})
         |> assign(:seconds_left, 0)
         |> assign(:added, false)
         |> assign(:error, :not_found), layout: false}
    end
  end

  @impl true
  def handle_info(:tick, %{assigns: %{seconds_left: s}} = socket) when s <= 0 do
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :seconds_left, socket.assigns.seconds_left - 1)}
  end

  @impl true
  def handle_event("add_all_to_cart", _, %{assigns: %{items: items}} = socket) do
    # Merge into the session cart via JS localStorage or redirect home with items
    # For now: redirect to home with a query param that home_live picks up
    _item_ids = items |> Map.keys() |> Enum.join(",")

    query_params = %{shared_cart: socket.assigns.share.token}

    {:noreply,
     socket
     |> assign(:added, true)
     |> push_navigate(to: Paths.home(query_params))}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def format_countdown(secs) when secs <= 0, do: "Expired"

  def format_countdown(secs) do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    s = rem(secs, 60)
    "#{pad(h)}:#{pad(m)}:#{pad(s)}"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end
