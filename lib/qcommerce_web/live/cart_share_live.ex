defmodule QcommerceWeb.CartShareLive do
  @moduledoc """
  Handles the /cart/share/:token route.

  Strategy (Blinkit-style):
  - Valid share  → redirect to home with ?shared_cart=TOKEN
    HomeLive.handle_params picks this up and shows an inline modal
    so the user sees the homepage behind the modal (not a blank page).
  - Expired/not-found → stay on this page and show a minimal error card.
  """
  use QcommerceWeb, :live_view

  alias QcommerceWeb.Paths
  alias Qcommerce.Cart
  alias Qcommerce.Cart.CartShare

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Cart.get_share(token) do
      {:ok, _share} ->
        # Valid share — redirect to home; HomeLive will show the modal
        {:ok,
         socket
         |> push_navigate(to: Paths.home(%{shared_cart: token})), layout: false}

      {:error, :expired} ->
        {:ok,
         socket
         |> assign(:page_title, "Link expired — QCommerce")
         |> assign(:error, :expired), layout: false}

      {:error, :not_found} ->
        {:ok,
         socket
         |> assign(:page_title, "Link not found — QCommerce")
         |> assign(:error, :not_found), layout: false}
    end
  end
end
