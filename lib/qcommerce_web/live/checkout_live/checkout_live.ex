# lib/qcommerce_web/live/checkout_live/checkout_live.ex
defmodule QcommerceWeb.CheckoutLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.Accounts
  alias Qcommerce.Orders
  alias Qcommerce.Platform
  alias Qcommerce.Cart.CartSession

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    current_user =
      if user_id do
        case Accounts.get_user(user_id) do
          {:ok, u} -> u
          _ -> nil
        end
      end

    # Redirect guests to home
    if is_nil(current_user) do
      {:ok, push_navigate(socket, to: "/"), layout: false}
    else
      # Restore cart from session (handles both post-login merge and direct logged-in checkout)
      cart_json = Map.get(session, "merged_guest_cart") || Map.get(session, "guest_cart")

      cart_items = CartSession.decode_cart(cart_json)

      # If cart is empty, redirect back home
      if map_size(cart_items) == 0 do
        {:ok, push_navigate(socket, to: "/"), layout: false}
      else
        {:ok, addresses} = Accounts.list_addresses(current_user.id)

        # Pick default branch (KTM-THAMEL-01 is the only branch for now)
        branch =
          case Platform.get_branch_by_code("KTM-THAMEL-01") do
            {:ok, b} -> b
            _ -> nil
          end

        default_address = Enum.find(addresses, &(&1.is_default)) || List.first(addresses)

        {cart_count, cart_total} = CartSession.cart_totals(cart_items)

        socket =
          socket
          |> assign(:page_title, "Checkout — QCommerce")
          |> assign(:current_user, current_user)
          |> assign(:cart_items, cart_items)
          |> assign(:cart_count, cart_count)
          |> assign(:cart_total, cart_total)
          |> assign(:addresses, addresses)
          |> assign(:selected_address_id, if(default_address, do: default_address.id))
          |> assign(:branch, branch)
          |> assign(:step, :review)
          # :review | :adding_address | :placed
          |> assign(:order_result, nil)
          |> assign(:placing, false)
          |> assign(:error, nil)
          # New address form fields
          |> assign(:new_label, "Home")
          |> assign(:new_line1, "")
          |> assign(:new_city, "Kathmandu")
          |> assign(:new_line2, "")
          |> assign(:form_errors, %{})

        {:ok, socket, layout: false}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("select_address", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_address_id, id)}
  end

  def handle_event("show_add_address", _, socket) do
    {:noreply, assign(socket, step: :adding_address, form_errors: %{})}
  end

  def handle_event("cancel_add_address", _, socket) do
    {:noreply, assign(socket, step: :review)}
  end

  def handle_event("update_new_label", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :new_label, v)}

  def handle_event("update_new_line1", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :new_line1, v)}

  def handle_event("update_new_line2", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :new_line2, v)}

  def handle_event("update_new_city", %{"value" => v}, socket),
    do: {:noreply, assign(socket, :new_city, v)}

  def handle_event("save_address", _params, socket) do
    attrs = %{
      "label" => socket.assigns.new_label,
      "line1" => socket.assigns.new_line1,
      "line2" => socket.assigns.new_line2,
      "city" => socket.assigns.new_city
    }

    case Accounts.create_address(socket.assigns.current_user, attrs) do
      {:ok, new_addr} ->
        {:ok, addresses} = Accounts.list_addresses(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:addresses, addresses)
         |> assign(:selected_address_id, new_addr.id)
         |> assign(:step, :review)
         |> assign(:new_label, "Home")
         |> assign(:new_line1, "")
         |> assign(:new_line2, "")
         |> assign(:new_city, "Kathmandu")
         |> assign(:form_errors, %{})}

      {:error, _err} ->
        errors = %{line1: "Please enter a valid address (min 5 characters)"}
        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  def handle_event("place_order", _, socket) do
    %{
      current_user: user,
      cart_items: cart_items,
      selected_address_id: address_id,
      branch: branch
    } = socket.assigns

    if is_nil(address_id) do
      {:noreply, assign(socket, :error, "Please select a delivery address.")}
    else
      socket = assign(socket, :placing, true)

      items =
        Enum.map(cart_items, fn {pid, item} ->
          %{"product_id" => pid, "quantity" => item.qty}
        end)

      params = %{
        "branch_id" => branch && branch.id,
        "address_id" => address_id,
        "items" => items
      }

      case Orders.place_order(user, params) do
        {:ok, order} ->
          {:noreply,
           socket
           |> assign(:step, :placed)
           |> assign(:order_result, order)
           |> assign(:placing, false)
           |> assign(:error, nil)
           |> push_event("cart_saved", %{cart: nil})}

        {:error, err} ->
          msg = Map.get(err, :message, "Could not place order. Please try again.")
          {:noreply, socket |> assign(:placing, false) |> assign(:error, msg)}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def handling_fee, do: Decimal.new("2")

  def grand_total(cart_total) do
    cart_total |> Decimal.add(handling_fee()) |> Decimal.round(0) |> Decimal.to_string()
  end
end
