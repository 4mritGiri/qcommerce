# lib/qcommerce_web/live/home_live.ex
defmodule QcommerceWeb.HomeLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.Catalog
  alias Qcommerce.Catalog.{Product, FlashSale}
  alias Qcommerce.Settings
  alias Qcommerce.Cart.CartSession

  alias QcommerceWeb.Live.Components.{
    CartPanel,
    CatalogComponents,
    NavComponents,
    ModalComponents,
    LayoutComponents
  }

  @tick_interval 1_000

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: :timer.send_interval(@tick_interval, self(), :tick)

    user_id = session["user_id"]

    current_user =
      if user_id do
        case Qcommerce.Accounts.get_user(user_id) do
          {:ok, user} -> user
          _ -> nil
        end
      end

    # ── Restore / merge guest cart ──────────────────────────────────────────
    # After login, SessionController puts the guest cart in :merged_guest_cart.
    # We load it here and merge into an empty map (since the user just landed).
    merged_guest_cart =
      session
      |> Map.get("merged_guest_cart")
      |> CartSession.decode_cart()

    slides = safe_slides()
    categories = safe_categories()
    popular = safe_products(nil, 8)
    fresh = safe_products("vegetables", 7)
    dairy = safe_products("dairy-eggs", 7)
    flash_sale = safe_flash_sale()
    auth = Settings.auth_methods()

    default_tab =
      cond do
        auth.qr -> :qr
        auth.phone -> :phone
        auth.email -> :email
        auth.passkey -> :passkey
        true -> :email
      end

    {cart_count, cart_total} = CartSession.cart_totals(merged_guest_cart)

    socket =
      socket
      |> assign(:page_title, "QCommerce — 10 min delivery")
      |> assign(:current_user, current_user)
      # Location
      |> assign(:show_location_modal, false)
      |> assign(:location_search, "")
      |> assign(:location_results, [])
      |> assign(:selected_location, "Thamel, Kathmandu")
      |> assign(:detecting_location, false)
      # Auth modals
      |> assign(:show_login_modal, false)
      |> assign(:show_signup_modal, false)
      |> assign(:auth_methods, auth)
      |> assign(:login_tab, default_tab)
      |> assign(:qr_countdown, 60)
      |> assign(:login_phone_step, 1)
      |> assign(:phone_input, "")
      |> assign(:otp_error, nil)
      # Passkey WebAuthn state
      # :idle | :waiting | :error | :success
      |> assign(:passkey_state, :idle)
      |> assign(:passkey_error, nil)
      # Catalog
      |> assign(:slides, slides)
      |> assign(:current_slide, 0)
      |> assign(:categories, categories)
      |> assign(:popular_products, popular)
      |> assign(:fresh_products, fresh)
      |> assign(:dairy_products, dairy)
      |> assign(:flash_sale, flash_sale)
      |> assign(:flash_countdown, countdown_label(flash_sale))
      # Search
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:show_search_dropdown, false)
      # Cart (pre-loaded with merged guest cart if returning from login)
      |> assign(:show_cart, false)
      |> assign(:cart_count, cart_count)
      |> assign(:cart_total, cart_total)
      |> assign(:cart_items, merged_guest_cart)
      # Product modal
      |> assign(:selected_product, nil)
      |> assign(:show_modal, false)
      # Coupon
      |> assign(:coupon_code, "")
      |> assign(:coupon_error, nil)
      |> assign(:coupon_discount, nil)
      # Share cart
      |> assign(:show_share_panel, false)
      |> assign(:share_token, nil)
      |> assign(:share_url, nil)
      |> assign(:share_seconds_left, 0)
      |> assign(:show_share_qr, false)
      # Incoming shared-cart modal (Blinkit-style)
      |> assign(:show_shared_cart_modal, false)
      |> assign(:shared_cart_share, nil)
      |> assign(:shared_cart_items, %{})

    {:ok, socket, layout: false}
  end

  # ---------------------------------------------------------------------------
  # Params — show Blinkit-style modal when redirected from CartShareLive
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(%{"shared_cart" => token}, _uri, socket) do
    socket =
      case Qcommerce.Cart.get_share(token) do
        {:ok, share} ->
          shared_items = Qcommerce.Cart.deserialize_items(share)

          socket
          |> assign(:show_shared_cart_modal, true)
          |> assign(:shared_cart_share, share)
          |> assign(:shared_cart_items, shared_items)

        {:error, :expired} ->
          put_flash(socket, :error, "This cart share link has expired.")

        _ ->
          put_flash(socket, :error, "Cart share link not found.")
      end

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Tick
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info(:tick, socket) do
    countdown = countdown_label(socket.assigns.flash_sale)

    qr_count =
      if socket.assigns.show_login_modal and socket.assigns.login_tab == :qr do
        if socket.assigns.qr_countdown <= 1, do: 60, else: socket.assigns.qr_countdown - 1
      else
        socket.assigns.qr_countdown
      end

    share_left =
      if socket.assigns.show_share_panel and socket.assigns.share_seconds_left > 0 do
        socket.assigns.share_seconds_left - 1
      else
        socket.assigns.share_seconds_left
      end

    {:noreply,
     socket
     |> assign(:flash_countdown, countdown)
     |> assign(:qr_countdown, qr_count)
     |> assign(:share_seconds_left, share_left)}
  end

  # ---------------------------------------------------------------------------
  # Shared-cart modal events
  # ---------------------------------------------------------------------------

  def handle_event("confirm_add_shared_cart", _, socket) do
    shared_items = socket.assigns.shared_cart_items
    merged = CartSession.merge(socket.assigns.cart_items, shared_items)
    {count, total} = CartSession.cart_totals(merged)
    n = map_size(shared_items)

    {:noreply,
     socket
     |> assign(:cart_items, merged)
     |> assign(:cart_count, count)
     |> assign(:cart_total, total)
     |> assign(:show_cart, true)
     |> assign(:show_shared_cart_modal, false)
     |> assign(:shared_cart_share, nil)
     |> assign(:shared_cart_items, %{})
     |> put_flash(:info, "#{n} #{if n == 1, do: "item", else: "items"} added to your cart!")}
  end

  def handle_event("dismiss_shared_cart", _, socket) do
    {:noreply,
     socket
     |> assign(:show_shared_cart_modal, false)
     |> assign(:shared_cart_share, nil)
     |> assign(:shared_cart_items, %{})}
  end


  # ---------------------------------------------------------------------------
  # Location events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("show_location_modal", _, socket) do
    {:noreply,
     assign(socket, show_location_modal: true, location_search: "", location_results: [])}
  end

  def handle_event("close_location_modal", _, socket) do
    {:noreply, assign(socket, show_location_modal: false)}
  end

  def handle_event("location_search", %{"query" => q}, socket) when byte_size(q) > 1 do
    all_locations = [
      "Thamel, Kathmandu",
      "Baneshwor, Kathmandu",
      "Lazimpat, Kathmandu",
      "Patan, Lalitpur",
      "Bhaktapur",
      "Balaju, Kathmandu",
      "Koteshwor, Kathmandu",
      "Chabahil, Kathmandu",
      "Boudha, Kathmandu",
      "Kirtipur, Kathmandu",
      "Kalanki, Kathmandu",
      "Suryabinayak, Bhaktapur",
      "Imadol, Lalitpur",
      "Gwarko, Lalitpur",
      "Kupondol, Lalitpur",
      "Jawalakhel, Lalitpur",
      "Pulchowk, Lalitpur",
      "Ekantakuna, Lalitpur",
      "New Baneshwor, Kathmandu",
      "Old Baneshwor, Kathmandu",
      "Maharajgunj, Kathmandu",
      "Samakhusi, Kathmandu",
      "Baluwatar, Kathmandu"
    ]

    results =
      all_locations
      |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(q)))
      |> Enum.take(6)

    {:noreply, assign(socket, location_search: q, location_results: results)}
  end

  def handle_event("location_search", %{"query" => q}, socket) do
    {:noreply, assign(socket, location_search: q, location_results: [])}
  end

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
    {:noreply,
     socket
     |> assign(:detecting_location, true)
     |> push_event("detect_gps", %{})}
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

  def handle_event("gps_denied", _, socket) do
    {:noreply, assign(socket, detecting_location: false)}
  end

  # ---------------------------------------------------------------------------
  # Carousel
  # ---------------------------------------------------------------------------

  def handle_event("prev_slide", _, socket) do
    total = length(carousel_slides(socket.assigns.slides))
    idx = rem(socket.assigns.current_slide - 1 + total, max(total, 1))
    {:noreply, assign(socket, :current_slide, idx)}
  end

  def handle_event("next_slide", _, socket) do
    total = length(carousel_slides(socket.assigns.slides))
    idx = rem(socket.assigns.current_slide + 1, max(total, 1))
    {:noreply, assign(socket, :current_slide, idx)}
  end

  def handle_event("go_slide", %{"index" => idx}, socket) do
    {:noreply, assign(socket, :current_slide, String.to_integer(idx))}
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  def handle_event("search", %{"query" => q}, socket) when byte_size(q) > 1 do
    {:ok, {results, _}} = Catalog.list_products(q: q, is_active: true, per_page: 8)

    {:noreply,
     assign(socket, search_query: q, search_results: results, show_search_dropdown: true)}
  end

  def handle_event("search", %{"query" => q}, socket) do
    {:noreply, assign(socket, search_query: q, search_results: [], show_search_dropdown: false)}
  end

  def handle_event("clear_search", _, socket) do
    {:noreply, assign(socket, search_query: "", search_results: [], show_search_dropdown: false)}
  end

  def handle_event("close_search_dropdown", _, socket) do
    {:noreply, assign(socket, show_search_dropdown: false)}
  end

  # ---------------------------------------------------------------------------
  # Cart
  # ---------------------------------------------------------------------------

  def handle_event("toggle_cart", _, socket) do
    {:noreply, assign(socket, show_cart: !socket.assigns.show_cart)}
  end

  def handle_event("close_cart", _, socket) do
    {:noreply, assign(socket, show_cart: false)}
  end

  def handle_event("add_to_cart", %{"product_id" => pid, "price" => price}, socket) do
    price_d = parse_price(price)
    product = find_product(pid, socket.assigns)
    name = if product, do: product.name, else: "Product"
    emoji = if product, do: Map.get(product, :emoji, "🛒"), else: "🛒"

    # Compute per-unit savings so CartPanel can show the savings banner
    savings_per_unit =
      case product do
        %{old_price: old} when not is_nil(old) ->
          old_d = parse_price(old)
          diff = Decimal.sub(old_d, price_d)

          if Decimal.gt?(diff, Decimal.new(0)),
            do: Decimal.to_integer(Decimal.round(diff, 0)),
            else: 0

        _ ->
          0
      end

    new_entry = %{
      qty: 1,
      price: price_d,
      name: name,
      emoji: emoji,
      savings_per_unit: savings_per_unit
    }

    items =
      Map.update(
        socket.assigns.cart_items,
        pid,
        new_entry,
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

  # ---------------------------------------------------------------------------
  # Share cart
  # ---------------------------------------------------------------------------

  def handle_event("share_cart", _, socket) do
    creator_id = socket.assigns.current_user && socket.assigns.current_user.id

    case Qcommerce.Cart.create_share(socket.assigns.cart_items, creator_id) do
      {:ok, share} ->
        # Build the share URL from the current request's host so it works on
        # localhost, staging, and production without hardcoding a domain.
        url = build_share_url(socket, share.token)

        {:noreply,
         socket
         |> assign(:show_share_panel, true)
         |> assign(:share_token, share.token)
         |> assign(:share_url, url)
         |> assign(:share_seconds_left, Qcommerce.Cart.CartShare.seconds_remaining(share))
         |> assign(:show_share_qr, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create share link. Please try again.")}
    end
  end

  def handle_event("hide_share_panel", _, socket) do
    {:noreply, assign(socket, show_share_panel: false)}
  end

  def handle_event("show_share_qr", _, socket) do
    {:noreply, assign(socket, show_share_qr: !socket.assigns.show_share_qr)}
  end

  def handle_event("copy_share_url", _, socket) do
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: socket.assigns.share_url})}
  end

  # ---------------------------------------------------------------------------
  # Product modal
  # ---------------------------------------------------------------------------

  def handle_event("show_product", %{"product_id" => pid}, socket) do
    product = find_product(pid, socket.assigns)

    {:noreply,
     assign(socket, selected_product: normalize_product(product), show_modal: !!product)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_product: nil)}
  end

  # ---------------------------------------------------------------------------
  # Coupon
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Auth events
  # ---------------------------------------------------------------------------

  def handle_event("show_login", _, socket) do
    auth = Settings.auth_methods()

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
       phone_input: "",
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
      {:noreply, put_flash(socket, :error, "Invalid phone number format.")}
    end
  end

  def handle_event("submit_otp", %{"otp" => otp}, socket) do
    if String.trim(otp) == "123456" do
      # Save guest cart before redirect
      cart_json = CartSession.encode_cart(socket.assigns.cart_items)

      {:noreply,
       socket
       |> push_event("save_guest_cart", %{
         cart: cart_json,
         redirect: "/session/login_phone?phone=#{socket.assigns.phone_input}"
       })}
    else
      {:noreply, assign(socket, otp_error: "Incorrect OTP. Try: 123456")}
    end
  end

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

  # ── WebAuthn passkey (real browser API) ────────────────────────────────────

  def handle_event("start_passkey_login", _, socket) do
    # Tell the browser to start the WebAuthn get() flow
    {:noreply,
     socket
     |> assign(:passkey_state, :waiting)
     |> assign(:passkey_error, nil)
     |> push_event("webauthn_authenticate", %{
       options_url: "/session/passkey/authentication_options"
     })}
  end

  def handle_event("passkey_credential", %{"credential" => credential}, socket) do
    # The browser sends back the assertion — we POST it server-side via a form redirect
    # to avoid a second LiveView round-trip that can't set cookies.
    cart_json = CartSession.encode_cart(socket.assigns.cart_items)

    {:noreply,
     push_event(socket, "passkey_submit_credential", %{
       credential: Jason.encode!(credential),
       cart: cart_json
     })}
  end

  def handle_event("passkey_error", %{"message" => msg}, socket) do
    {:noreply, assign(socket, passkey_state: :error, passkey_error: msg)}
  end

  def handle_event("start_passkey_register", _, socket) do
    if socket.assigns.current_user do
      {:noreply,
       socket
       |> assign(:passkey_state, :waiting)
       |> push_event("webauthn_register", %{
         options_url: "/session/passkey/registration_options"
       })}
    else
      {:noreply, assign(socket, passkey_error: "Login first to register a passkey")}
    end
  end

  # ---------------------------------------------------------------------------
  # Public helpers — called from .heex template
  # ---------------------------------------------------------------------------

  def carousel_slides([]), do: static_slides()

  def carousel_slides(db_slides) do
    Enum.map(db_slides, fn s ->
      %{
        theme: s.theme,
        tag: s.tag,
        h2: s.heading,
        p: s.sub,
        cta: s.cta_label,
        emoji: s.emojis,
        products: Enum.map(s.products, &db_product_to_chip/1)
      }
    end)
  end

  def category_list([]) do
    [
      %{emoji: "🥬", name: "Vegetables"},
      %{emoji: "🍎", name: "Fruits"},
      %{emoji: "🥛", name: "Dairy & Eggs"},
      %{emoji: "🍞", name: "Bakery"},
      %{emoji: "🥩", name: "Meat & Fish"},
      %{emoji: "🧃", name: "Beverages"},
      %{emoji: "🍫", name: "Snacks"},
      %{emoji: "🧴", name: "Beauty"},
      %{emoji: "🧹", name: "Cleaning"},
      %{emoji: "👶", name: "Baby"},
      %{emoji: "🐾", name: "Pet Care"},
      %{emoji: "❄️", name: "Frozen"},
      %{emoji: "🍳", name: "Breakfast"},
      %{emoji: "🌿", name: "Organic"},
      %{emoji: "💊", name: "Health"}
    ]
  end

  def category_list(cats) do
    Enum.map(cats, fn c -> %{emoji: get_category_emoji(c.slug), name: c.name} end)
  end

  def product_display_list([], fallback), do: fallback

  def product_display_list(db_products, _) do
    Enum.map(db_products, fn p ->
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
    end)
  end

  def cart_qty(cart_items, product_id) do
    case Map.get(cart_items, product_id) do
      nil -> 0
      item -> item.qty
    end
  end

  def popular_fallback,
    do: [
      %{
        id: "pop-1",
        emoji: "🥛",
        name: "Farm Fresh Milk 500ml",
        badge: "badge-new",
        badge_label: "NEW",
        price: "Rs. 32",
        price_raw: "32",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "500ml"
      },
      %{
        id: "pop-2",
        emoji: "🍞",
        name: "Whole Wheat Bread 400g",
        badge: "badge-popular",
        badge_label: "POPULAR",
        price: "Rs. 45",
        price_raw: "45",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "400g"
      },
      %{
        id: "pop-3",
        emoji: "🥚",
        name: "Free Range Eggs 12pcs",
        badge: "badge-sale",
        badge_label: "SALE",
        price: "Rs. 95",
        price_raw: "95",
        old_price: "Rs. 110",
        discount_pct: 14,
        time: "10 mins",
        weight: "12pcs"
      },
      %{
        id: "pop-4",
        emoji: "🍌",
        name: "Bananas 6pcs Robusta",
        badge: nil,
        badge_label: nil,
        price: "Rs. 39",
        price_raw: "39",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "6pcs"
      },
      %{
        id: "pop-5",
        emoji: "🍅",
        name: "Cherry Tomatoes 250g",
        badge: "badge-hot",
        badge_label: "HOT",
        price: "Rs. 79",
        price_raw: "79",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "250g"
      },
      %{
        id: "pop-6",
        emoji: "🥑",
        name: "Ripe Avocados 2pcs",
        badge: "badge-new",
        badge_label: "NEW",
        price: "Rs. 89",
        price_raw: "89",
        old_price: "Rs. 120",
        discount_pct: 26,
        time: "10 mins",
        weight: "2pcs"
      },
      %{
        id: "pop-7",
        emoji: "🧅",
        name: "Red Onions 1kg",
        badge: nil,
        badge_label: nil,
        price: "Rs. 29",
        price_raw: "29",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "1kg"
      }
    ]

  def fresh_fallback,
    do: [
      %{
        id: "fr-1",
        emoji: "🥦",
        name: "Broccoli Fresh 350g",
        badge: "badge-new",
        badge_label: "NEW",
        price: "Rs. 69",
        price_raw: "69",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "350g"
      },
      %{
        id: "fr-2",
        emoji: "🥕",
        name: "Carrots Organic 500g",
        badge: nil,
        badge_label: nil,
        price: "Rs. 45",
        price_raw: "45",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "500g"
      },
      %{
        id: "fr-3",
        emoji: "🌽",
        name: "Sweet Corn 2pcs",
        badge: "badge-hot",
        badge_label: "HOT",
        price: "Rs. 35",
        price_raw: "35",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "2pcs"
      },
      %{
        id: "fr-4",
        emoji: "🫑",
        name: "Bell Peppers Mixed 3pcs",
        badge: nil,
        badge_label: nil,
        price: "Rs. 89",
        price_raw: "89",
        old_price: "Rs. 110",
        discount_pct: 19,
        time: "10 mins",
        weight: "3pcs"
      },
      %{
        id: "fr-5",
        emoji: "🍋",
        name: "Lemon 6pcs",
        badge: nil,
        badge_label: nil,
        price: "Rs. 29",
        price_raw: "29",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "6pcs"
      },
      %{
        id: "fr-6",
        emoji: "🫐",
        name: "Blueberries 125g",
        badge: "badge-sale",
        badge_label: "SALE",
        price: "Rs. 149",
        price_raw: "149",
        old_price: "Rs. 189",
        discount_pct: 21,
        time: "10 mins",
        weight: "125g"
      },
      %{
        id: "fr-7",
        emoji: "🍇",
        name: "Black Grapes 500g",
        badge: nil,
        badge_label: nil,
        price: "Rs. 99",
        price_raw: "99",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "500g"
      }
    ]

  def dairy_fallback,
    do: [
      %{
        id: "da-1",
        emoji: "🧀",
        name: "Amul Cheddar Cheese 200g",
        badge: "badge-popular",
        badge_label: "POPULAR",
        price: "Rs. 89",
        price_raw: "89",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "200g"
      },
      %{
        id: "da-2",
        emoji: "🍦",
        name: "Amul Greek Yogurt 400g",
        badge: nil,
        badge_label: nil,
        price: "Rs. 79",
        price_raw: "79",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "400g"
      },
      %{
        id: "da-3",
        emoji: "🧈",
        name: "Amul Butter Unsalted 500g",
        badge: nil,
        badge_label: nil,
        price: "Rs. 239",
        price_raw: "239",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "500g"
      },
      %{
        id: "da-4",
        emoji: "🥛",
        name: "Oat Milk Unsweetened 1L",
        badge: "badge-new",
        badge_label: "NEW",
        price: "Rs. 139",
        price_raw: "139",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "1L"
      },
      %{
        id: "da-5",
        emoji: "🧆",
        name: "Paneer Fresh 200g",
        badge: "badge-hot",
        badge_label: "HOT",
        price: "Rs. 69",
        price_raw: "69",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "200g"
      },
      %{
        id: "da-6",
        emoji: "🫙",
        name: "Mishti Doi 400g",
        badge: nil,
        badge_label: nil,
        price: "Rs. 89",
        price_raw: "89",
        old_price: nil,
        discount_pct: nil,
        time: "10 mins",
        weight: "400g"
      },
      %{
        id: "da-7",
        emoji: "🥚",
        name: "Quail Eggs 20pcs",
        badge: "badge-sale",
        badge_label: "SALE",
        price: "Rs. 89",
        price_raw: "89",
        old_price: "Rs. 109",
        discount_pct: 18,
        time: "10 mins",
        weight: "20pcs"
      }
    ]

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_product(nil), do: nil

  defp normalize_product(%Qcommerce.Catalog.Product{} = p) do
    disc = Product.discount_pct(p)

    %{
      id: p.id,
      emoji: p.emoji,
      name: p.name,
      description: p.description,
      unit: p.unit,
      base_price: p.base_price,
      old_price: p.old_price,
      price: Product.format_price(p.base_price),
      price_raw: p.base_price,
      badge: badge_class(disc),
      badge_label: badge_label(disc),
      discount_pct: disc,
      time: "10 mins",
      weight: p.unit
    }
  end

  defp normalize_product(p), do: p

  defp find_product(pid, assigns) do
    all =
      assigns.popular_products ++
        assigns.fresh_products ++
        assigns.dairy_products ++
        Enum.flat_map(assigns.slides, fn s ->
          case s do
            %{products: prods} -> prods
            _ -> []
          end
        end)

    case Enum.find(all, &(to_string(Map.get(&1, :id, "")) == pid)) do
      nil -> nil
      product -> normalize_product(product)
    end
  end

  defp safe_slides do
    case Catalog.list_active_slides() do
      {:ok, slides} -> slides
      _ -> []
    end
  end

  defp safe_categories do
    case Catalog.list_categories(is_active: true) do
      {:ok, cats} -> cats
      _ -> []
    end
  end

  defp safe_products(slug, per_page) do
    params =
      if slug do
        # Resolve slug → category_id so the DB query can filter properly
        case Qcommerce.Catalog.get_category_by_slug(slug) do
          {:ok, cat} -> [is_active: true, per_page: per_page, category_id: cat.id]
          _ -> [is_active: true, per_page: per_page]
        end
      else
        [is_active: true, per_page: per_page]
      end

    case Catalog.list_products(params) do
      {:ok, {prods, _}} -> prods
      _ -> []
    end
  end

  defp safe_flash_sale do
    case Catalog.active_flash_sale() do
      {:ok, sale} -> sale
      _ -> nil
    end
  end

  defp db_product_to_chip(p) do
    %{
      id: p.id,
      emoji: p.emoji,
      name: p.name,
      badge: if(Product.discount_pct(p), do: "SALE"),
      time: "10 mins",
      price: Product.format_price(p.base_price),
      price_raw: p.base_price
    }
  end

  defp badge_class(nil), do: nil
  defp badge_class(_), do: "badge-sale"
  defp badge_label(nil), do: nil
  defp badge_label(pct), do: "#{pct}% off"

  # ---------------------------------------------------------------------------
  # Share URL — built from the socket's endpoint so it works on localhost,
  # staging, and production without hardcoding "qcom.app".
  # ---------------------------------------------------------------------------

  defp build_share_url(_socket, token) do
    # Phoenix.Endpoint.url/0 returns the configured URL for the current env,
    # e.g. "http://localhost:4000" in dev or "https://qcom.app" in prod.
    base = QcommerceWeb.Endpoint.url()
    "#{base}/cart/share/#{token}"
  end

  defp parse_price(p) when is_binary(p) do
    case Decimal.parse(p) do
      {d, _} -> d
      :error -> Decimal.new("0")
    end
  end

  defp parse_price(%Decimal{} = d), do: d
  defp parse_price(p), do: Decimal.new("#{p}")

  defp countdown_label(nil), do: nil
  defp countdown_label(fs), do: FlashSale.format_countdown(FlashSale.seconds_remaining(fs))

  defp get_category_emoji(slug) do
    case String.downcase(slug || "") do
      "vegetables" -> "🥬"
      "fruits" -> "🍎"
      "dairy-eggs" -> "🥛"
      "dairy" -> "🥛"
      "bakery" -> "🍞"
      "meat-fish" -> "🥩"
      "meat" -> "🥩"
      "beverages" -> "🧃"
      "snacks" -> "🍫"
      "beauty" -> "🧴"
      "cleaning" -> "🧹"
      "baby" -> "👶"
      "pet-care" -> "🐾"
      "frozen" -> "❄️"
      "breakfast" -> "🍳"
      "organic" -> "🌿"
      "health" -> "💊"
      _ -> "🛍️"
    end
  end

  defp static_slides do
    [
      %{
        theme: "slide-0",
        tag: "⚡ 10 Min Delivery",
        h2: "Freshness at <em>lightning speed</em>",
        p: "5,000+ products · zero waiting",
        cta: "Shop now",
        emoji: ["🛒", "🥦", "🍎"],
        products: [
          %{
            id: "s0-1",
            emoji: "🥑",
            name: "Organic Avocado Pack of 3",
            badge: "NEW",
            time: "10 mins",
            price: "Rs. 89",
            price_raw: "89"
          },
          %{
            id: "s0-2",
            emoji: "🫐",
            name: "Fresh Blueberries 125g",
            badge: "FRESH",
            time: "10 mins",
            price: "Rs. 149",
            price_raw: "149"
          },
          %{
            id: "s0-3",
            emoji: "🥝",
            name: "Kiwi Fruit 4pcs",
            badge: "SALE",
            time: "10 mins",
            price: "Rs. 79",
            price_raw: "79"
          },
          %{
            id: "s0-4",
            emoji: "🍓",
            name: "Strawberries 250g",
            badge: nil,
            time: "10 mins",
            price: "Rs. 119",
            price_raw: "119"
          },
          %{
            id: "s0-5",
            emoji: "🥭",
            name: "Alphonso Mango 500g",
            badge: "HOT",
            time: "10 mins",
            price: "Rs. 189",
            price_raw: "189"
          }
        ]
      },
      %{
        theme: "slide-1",
        tag: "🥛 Dairy Fresh",
        h2: "Farm fresh <em>dairy</em> every morning",
        p: "Delivered cold · certified organic",
        cta: "Explore dairy",
        emoji: ["🥛", "🧀", "🥚"],
        products: [
          %{
            id: "s1-1",
            emoji: "🥛",
            name: "Farm Fresh Milk 500ml",
            badge: nil,
            time: "10 mins",
            price: "Rs. 32",
            price_raw: "32"
          },
          %{
            id: "s1-2",
            emoji: "🧀",
            name: "Amul Processed Cheese 200g",
            badge: nil,
            time: "10 mins",
            price: "Rs. 89",
            price_raw: "89"
          },
          %{
            id: "s1-3",
            emoji: "🥚",
            name: "Free Range Eggs Tray of 12",
            badge: "SALE",
            time: "10 mins",
            price: "Rs. 95",
            price_raw: "95"
          },
          %{
            id: "s1-4",
            emoji: "🧈",
            name: "Amul Butter 100g",
            badge: nil,
            time: "10 mins",
            price: "Rs. 55",
            price_raw: "55"
          },
          %{
            id: "s1-5",
            emoji: "🍦",
            name: "Greek Yogurt 400g",
            badge: "NEW",
            time: "10 mins",
            price: "Rs. 79",
            price_raw: "79"
          }
        ]
      },
      %{
        theme: "slide-2",
        tag: "🍫 Snacks & Munchies",
        h2: "Late night <em>cravings</em> sorted",
        p: "Chocolates, chips & more",
        cta: "Shop snacks",
        emoji: ["🍫", "🍿", "🧃"],
        products: [
          %{
            id: "s2-1",
            emoji: "🍫",
            name: "Dairy Milk Silk 160g",
            badge: nil,
            time: "10 mins",
            price: "Rs. 139",
            price_raw: "139"
          },
          %{
            id: "s2-2",
            emoji: "🍿",
            name: "Act II Popcorn Butter 30g",
            badge: "HOT",
            time: "10 mins",
            price: "Rs. 25",
            price_raw: "25"
          },
          %{
            id: "s2-3",
            emoji: "🥨",
            name: "Pringles Original 107g",
            badge: nil,
            time: "10 mins",
            price: "Rs. 179",
            price_raw: "179"
          },
          %{
            id: "s2-4",
            emoji: "🧃",
            name: "Real Fruit Mango 1L",
            badge: "SALE",
            time: "10 mins",
            price: "Rs. 75",
            price_raw: "75"
          },
          %{
            id: "s2-5",
            emoji: "🍬",
            name: "Haribo Goldbears 200g",
            badge: "NEW",
            time: "10 mins",
            price: "Rs. 149",
            price_raw: "149"
          }
        ]
      }
    ]
  end
end
