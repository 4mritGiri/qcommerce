defmodule QcommerceWeb.ProductLive do
  @moduledoc """
  Full product detail page.
  Route: GET /products/:id  (or  /products/:slug)
  """
  use QcommerceWeb, :live_view

  alias Qcommerce.Catalog
  alias Qcommerce.Catalog.Product
  alias Qcommerce.Cart.CartSession
  # alias QcommerceWeb.Live.Components.{NavComponents, LayoutComponents, CartPanel}
  # alias QcommerceWeb.Live.Components.ModalComponents

  @tick_interval 1_000

  @impl true
  def mount(%{"id" => id}, session, socket) do
    if connected?(socket), do: :timer.send_interval(@tick_interval, self(), :tick)

    user_id = session["user_id"]

    current_user =
      if user_id do
        case Qcommerce.Accounts.get_user(user_id) do
          {:ok, u} -> u
          _ -> nil
        end
      end

    auth = Qcommerce.Settings.auth_methods()

    default_tab =
      cond do
        auth.qr -> :qr
        auth.phone -> :phone
        auth.email -> :email
        auth.passkey -> :passkey
        true -> :email
      end

    case Catalog.get_product(id) do
      {:ok, product} ->
        # Related products (same category or just popular)
        {:ok, {related, _}} =
          Catalog.list_products(is_active: true, per_page: 8)

        related_fmt =
          related
          |> Enum.reject(&(&1.id == product.id))
          |> Enum.take(7)
          |> Enum.map(&format_product/1)

        disc = Product.discount_pct(product)

        fmt_product = %{
          id: product.id,
          emoji: product.emoji,
          name: product.name,
          description: product.description,
          unit: product.unit,
          base_price: product.base_price,
          old_price: product.old_price,
          price: Product.format_price(product.base_price),
          old_price_fmt: if(product.old_price, do: Product.format_price(product.old_price)),
          discount_pct: disc,
          badge: badge_class(disc),
          badge_label: badge_label(disc),
          sku: Map.get(product, :sku, nil),
          is_active: product.is_active
        }

        socket =
          socket
          |> assign(:page_title, "#{product.name} — QCommerce")
          |> assign(:product, fmt_product)
          |> assign(:related_products, related_fmt)
          |> assign(:qty, 1)
          |> assign(:active_tab, :description)
          |> assign(:current_user, current_user)
          |> assign(:selected_location, "Thamel, Kathmandu")
          |> assign(:show_location_modal, false)
          |> assign(:detecting_location, false)
          |> assign(:location_search, "")
          |> assign(:location_results, [])
          |> assign(:show_cart, false)
          |> assign(:cart_items, %{})
          |> assign(:cart_count, 0)
          |> assign(:cart_total, Decimal.new("0"))
          |> assign(:coupon_code, "")
          |> assign(:coupon_error, nil)
          |> assign(:coupon_discount, nil)
          |> assign(:show_share_panel, false)
          |> assign(:share_token, nil)
          |> assign(:share_url, nil)
          |> assign(:share_seconds_left, 0)
          |> assign(:show_share_qr, false)
          |> assign(:show_login_modal, false)
          |> assign(:show_signup_modal, false)
          |> assign(:auth_methods, auth)
          |> assign(:login_tab, default_tab)
          |> assign(:login_phone_step, 1)
          |> assign(:phone_input, "")
          |> assign(:otp_error, nil)
          |> assign(:qr_countdown, 60)
          |> assign(:passkey_state, :idle)
          |> assign(:passkey_error, nil)
          |> assign(:flash_sale, nil)
          |> assign(:flash_countdown, nil)
          |> assign(:search_query, "")
          |> assign(:search_results, [])
          |> assign(:selected_product, nil)
          |> assign(:show_modal, false)
          |> assign(:error, false)

        {:ok, socket, layout: false}

      {:error, _} ->
        {:ok,
         socket
         |> assign(:page_title, "Product not found — QCommerce")
         |> assign(:error, true)
         |> assign(:product, nil)
         |> assign(:related_products, [])
         |> assign(:qty, 1)
         |> assign(:active_tab, :description)
         |> assign(:current_user, current_user)
         |> assign(:selected_location, "Thamel, Kathmandu")
         |> assign(:show_cart, false)
         |> assign(:cart_items, %{})
         |> assign(:cart_count, 0)
         |> assign(:cart_total, Decimal.new("0"))
         |> assign(:coupon_code, "")
         |> assign(:coupon_error, nil)
         |> assign(:coupon_discount, nil)
         |> assign(:show_share_panel, false)
         |> assign(:share_token, nil)
         |> assign(:share_url, nil)
         |> assign(:share_seconds_left, 0)
         |> assign(:show_share_qr, false)
         |> assign(:show_login_modal, false)
         |> assign(:show_signup_modal, false)
         |> assign(:auth_methods, auth)
         |> assign(:login_tab, default_tab)
         |> assign(:login_phone_step, 1)
         |> assign(:phone_input, "")
         |> assign(:otp_error, nil)
         |> assign(:qr_countdown, 60)
         |> assign(:passkey_state, :idle)
         |> assign(:passkey_error, nil)
         |> assign(:flash_sale, nil)
         |> assign(:flash_countdown, nil)
         |> assign(:search_query, "")
         |> assign(:search_results, [])
         |> assign(:show_location_modal, false)
         |> assign(:detecting_location, false)
         |> assign(:location_search, "")
         |> assign(:location_results, [])
         |> assign(:selected_product, nil)
         |> assign(:show_modal, false), layout: false}
    end
  end

  # ---------------------------------------------------------------------------
  # Tick
  # ---------------------------------------------------------------------------
  @impl true
  def handle_info(:tick, socket) do
    qr_count =
      if socket.assigns.show_login_modal and socket.assigns.login_tab == :qr do
        if socket.assigns.qr_countdown <= 1, do: 60, else: socket.assigns.qr_countdown - 1
      else
        socket.assigns.qr_countdown
      end

    {:noreply, assign(socket, :qr_countdown, qr_count)}
  end

  # ---------------------------------------------------------------------------
  # Product events
  # ---------------------------------------------------------------------------
  @impl true
  def handle_event("inc_qty", _, socket),
    do: {:noreply, assign(socket, qty: socket.assigns.qty + 1)}

  def handle_event("dec_qty", _, socket) do
    new_qty = max(1, socket.assigns.qty - 1)
    {:noreply, assign(socket, qty: new_qty)}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end

  def handle_event("add_to_cart_detail", _, socket) do
    product = socket.assigns.product
    pid = to_string(product.id)
    qty = socket.assigns.qty

    items =
      Map.update(
        socket.assigns.cart_items,
        pid,
        %{qty: qty, price: product.base_price, name: product.name, emoji: product.emoji},
        fn i -> %{i | qty: i.qty + qty} end
      )

    {count, total} = CartSession.cart_totals(items)

    {:noreply,
     socket
     |> assign(cart_items: items, cart_count: count, cart_total: total, show_cart: true)}
  end

  # Reuse common cart/auth/share/nav events
  def handle_event("toggle_cart", _, socket),
    do: {:noreply, assign(socket, show_cart: !socket.assigns.show_cart)}

  def handle_event("close_cart", _, socket),
    do: {:noreply, assign(socket, show_cart: false)}

  def handle_event("add_to_cart", %{"product_id" => pid, "price" => price}, socket) do
    product = Enum.find(socket.assigns.related_products, &(to_string(&1.id) == pid))
    name = if product, do: product.name, else: "Product"
    emoji = if product, do: product.emoji, else: "🛒"
    price_d = parse_price(price)

    items =
      Map.update(
        socket.assigns.cart_items,
        pid,
        %{qty: 1, price: price_d, name: name, emoji: emoji},
        fn i -> %{i | qty: i.qty + 1} end
      )

    {count, total} = CartSession.cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("decrement_cart", %{"product_id" => pid}, socket) do
    items =
      case socket.assigns.cart_items[pid] do
        %{qty: 1} -> Map.delete(socket.assigns.cart_items, pid)
        %{qty: q} = item -> Map.put(socket.assigns.cart_items, pid, %{item | qty: q - 1})
        nil -> socket.assigns.cart_items
      end

    {count, total} = CartSession.cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("remove_cart_item", %{"product_id" => pid}, socket) do
    items = Map.delete(socket.assigns.cart_items, pid)
    {count, total} = CartSession.cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("clear_cart", _, socket) do
    {:noreply, assign(socket, cart_items: %{}, cart_count: 0, cart_total: Decimal.new("0"))}
  end

  def handle_event("apply_coupon", %{"code" => code}, socket) do
    case String.upcase(String.trim(code)) do
      "FIRST10" ->
        {:noreply,
         assign(socket,
           coupon_error: nil,
           coupon_discount: %{type: :percent, value: 10, label: "10% off — FIRST10"}
         )}

      "FLAT50" ->
        {:noreply,
         assign(socket,
           coupon_error: nil,
           coupon_discount: %{type: :fixed, value: 50, label: "Rs. 50 off — FLAT50"}
         )}

      "DAIRY20" ->
        {:noreply,
         assign(socket,
           coupon_error: nil,
           coupon_discount: %{type: :percent, value: 20, label: "20% off — DAIRY20"}
         )}

      _ ->
        {:noreply, assign(socket, coupon_error: "Invalid coupon code", coupon_discount: nil)}
    end
  end

  def handle_event("share_cart", _, socket) do
    creator_id = socket.assigns.current_user && socket.assigns.current_user.id

    case Qcommerce.Cart.create_share(socket.assigns.cart_items, creator_id) do
      {:ok, share} ->
        url = Qcommerce.Cart.share_url(share.token)

        {:noreply,
         socket
         |> assign(:show_share_panel, true)
         |> assign(:share_token, share.token)
         |> assign(:share_url, url)
         |> assign(:share_seconds_left, Qcommerce.Cart.CartShare.seconds_remaining(share))
         |> assign(:show_share_qr, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create share link.")}
    end
  end

  def handle_event("hide_share_panel", _, socket),
    do: {:noreply, assign(socket, show_share_panel: false)}

  def handle_event("show_share_qr", _, socket),
    do: {:noreply, assign(socket, show_share_qr: !socket.assigns.show_share_qr)}

  def handle_event("copy_share_url", _, socket),
    do: {:noreply, push_event(socket, "copy_to_clipboard", %{text: socket.assigns.share_url})}

  def handle_event("show_login", _, socket) do
    auth = Qcommerce.Settings.auth_methods()

    tab =
      cond do
        auth.qr -> :qr
        auth.phone -> :phone
        auth.email -> :email
        auth.passkey -> :passkey
        true -> :email
      end

    {:noreply,
     assign(socket,
       show_login_modal: true,
       show_signup_modal: false,
       auth_methods: auth,
       login_tab: tab,
       qr_countdown: 60,
       login_phone_step: 1,
       otp_error: nil,
       passkey_state: :idle,
       passkey_error: nil
     )}
  end

  def handle_event("close_login", _, socket),
    do: {:noreply, assign(socket, show_login_modal: false)}

  def handle_event("show_signup", _, socket),
    do: {:noreply, assign(socket, show_signup_modal: true, show_login_modal: false)}

  def handle_event("close_signup", _, socket),
    do: {:noreply, assign(socket, show_signup_modal: false)}

  def handle_event("select_login_tab", %{"tab" => tab}, socket) do
    auth = socket.assigns.auth_methods

    tab_atom =
      case tab do
        "qr" when auth.qr -> :qr
        "phone" when auth.phone -> :phone
        "email" when auth.email -> :email
        "passkey" when auth.passkey -> :passkey
        _ -> socket.assigns.login_tab
      end

    {:noreply,
     assign(socket,
       login_tab: tab_atom,
       login_phone_step: 1,
       otp_error: nil,
       passkey_state: :idle,
       passkey_error: nil
     )}
  end

  def handle_event("submit_phone", %{"phone" => phone}, socket) do
    if Regex.match?(~r/^\+?[0-9]{8,15}$/, String.trim(phone)) do
      {:noreply,
       assign(socket, login_phone_step: 2, phone_input: String.trim(phone), otp_error: nil)}
    else
      {:noreply, put_flash(socket, :error, "Invalid phone number.")}
    end
  end

  def handle_event("submit_otp", %{"otp" => otp}, socket) do
    if String.trim(otp) == "123456" do
      cart_json = CartSession.encode_cart(socket.assigns.cart_items)

      {:noreply,
       push_event(socket, "save_guest_cart", %{
         cart: cart_json,
         redirect: "/session/login_phone?phone=#{socket.assigns.phone_input}"
       })}
    else
      {:noreply, assign(socket, otp_error: "Incorrect OTP. Try: 123456")}
    end
  end

  def handle_event("show_location_modal", _, socket),
    do:
      {:noreply,
       assign(socket, show_location_modal: true, location_search: "", location_results: [])}

  def handle_event("close_location_modal", _, socket),
    do: {:noreply, assign(socket, show_location_modal: false)}

  def handle_event("location_search", %{"query" => q}, socket) when byte_size(q) > 1 do
    results = filter_locations(q)
    {:noreply, assign(socket, location_search: q, location_results: results)}
  end

  def handle_event("location_search", %{"query" => q}, socket),
    do: {:noreply, assign(socket, location_search: q, location_results: [])}

  def handle_event("select_location", %{"location" => location}, socket) do
    {:noreply,
     assign(socket,
       selected_location: location,
       show_location_modal: false,
       location_search: "",
       location_results: []
     )}
  end

  def handle_event("detect_location", _, socket) do
    {:noreply, socket |> assign(:detecting_location, true) |> push_event("detect_gps", %{})}
  end

  def handle_event("gps_location", %{"lat" => lat, "lng" => lng, "address" => address}, socket) do
    location =
      if address != "", do: address, else: "#{Float.round(lat, 4)}, #{Float.round(lng, 4)}"

    {:noreply,
     assign(socket,
       selected_location: location,
       detecting_location: false,
       show_location_modal: false
     )}
  end

  def handle_event("gps_denied", _, socket),
    do: {:noreply, assign(socket, detecting_location: false)}

  def handle_event("search", %{"query" => q}, socket) when byte_size(q) > 1 do
    {:ok, {results, _}} = Catalog.list_products(q: q, is_active: true, per_page: 6)

    {:noreply,
     assign(socket, search_query: q, search_results: results, show_search_dropdown: true)}
  end

  def handle_event("search", %{"query" => q}, socket),
    do:
      {:noreply, assign(socket, search_query: q, search_results: [], show_search_dropdown: false)}

  def handle_event("close_search_dropdown", _, socket),
    do: {:noreply, assign(socket, show_search_dropdown: false)}

  def handle_event("show_product", %{"product_id" => pid}, socket) do
    product = Enum.find(socket.assigns.related_products, &(to_string(&1.id) == pid))
    {:noreply, assign(socket, selected_product: product, show_modal: !!product)}
  end

  def handle_event("close_modal", _, socket),
    do: {:noreply, assign(socket, show_modal: false, selected_product: nil)}

  def handle_event("simulate_qr_login", _, socket) do
    cart_json = CartSession.encode_cart(socket.assigns.cart_items)

    {:noreply,
     push_event(socket, "save_guest_cart", %{cart: cart_json, redirect: "/session/login_qr"})}
  end

  def handle_event("simulate_passkey_login", _, socket) do
    ext_id = Base.url_encode64("demo_passkey_id", padding: false)
    cart_json = CartSession.encode_cart(socket.assigns.cart_items)

    {:noreply,
     push_event(socket, "save_guest_cart", %{
       cart: cart_json,
       redirect: "/session/login_passkey?external_id=#{ext_id}"
     })}
  end

  def handle_event("start_passkey_login", _, socket) do
    {:noreply,
     socket
     |> assign(:passkey_state, :waiting)
     |> assign(:passkey_error, nil)
     |> push_event("webauthn_authenticate", %{
       options_url: "/session/passkey/authentication_options"
     })}
  end

  def handle_event("passkey_credential", %{"credential" => credential}, socket) do
    cart_json = CartSession.encode_cart(socket.assigns.cart_items)

    {:noreply,
     push_event(socket, "passkey_submit_credential", %{
       credential: Jason.encode!(credential),
       cart: cart_json
     })}
  end

  def handle_event("passkey_error", %{"message" => msg}, socket),
    do: {:noreply, assign(socket, passkey_state: :error, passkey_error: msg)}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_product(p) do
    disc = Product.discount_pct(p)

    %{
      id: p.id,
      emoji: p.emoji,
      name: p.name,
      badge: badge_class(disc),
      badge_label: badge_label(disc),
      price: Product.format_price(p.base_price),
      price_raw: p.base_price,
      old_price: if(p.old_price, do: Product.format_price(p.old_price)),
      discount_pct: disc,
      time: "10 mins",
      weight: p.unit
    }
  end

  defp badge_class(nil), do: nil
  defp badge_class(_), do: "badge-sale"
  defp badge_label(nil), do: nil
  defp badge_label(pct), do: "#{pct}% off"

  defp parse_price(p) when is_binary(p) do
    case Decimal.parse(p) do
      {d, _} -> d
      :error -> Decimal.new("0")
    end
  end

  defp parse_price(%Decimal{} = d), do: d
  defp parse_price(p), do: Decimal.new("#{p}")

  defp filter_locations(q) do
    [
      "Thamel, Kathmandu",
      "Baneshwor, Kathmandu",
      "Lazimpat, Kathmandu",
      "Patan, Lalitpur",
      "Bhaktapur",
      "Koteshwor, Kathmandu",
      "Maharajgunj, Kathmandu",
      "Pulchowk, Lalitpur",
      "Jawalakhel, Lalitpur"
    ]
    |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(q)))
    |> Enum.take(6)
  end

  def cart_qty(cart_items, product_id) do
    case Map.get(cart_items, to_string(product_id)) do
      nil -> 0
      item -> item.qty
    end
  end
end
