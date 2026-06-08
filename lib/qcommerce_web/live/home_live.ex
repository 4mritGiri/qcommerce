# lib/qcommerce_web/live/home_live.ex
defmodule QcommerceWeb.HomeLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.Catalog
  alias Qcommerce.Catalog.{Product, FlashSale}
  alias Qcommerce.Settings
  alias QcommerceWeb.CatalogComponents
  alias QcommerceWeb.Live.Components.CartPanel

  import CartPanel, only: [
    savings_amount: 1,
    discount_amount: 2,
    grand_total: 2,
    format_share_countdown: 1
  ]

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
      else
        nil
      end

    slides     = safe_slides()
    categories = safe_categories()
    popular    = safe_products(nil, 8)
    fresh      = safe_products("vegetables", 7)
    dairy      = safe_products("dairy-eggs", 7)
    flash_sale = safe_flash_sale()
    auth       = Settings.auth_methods()

    default_tab = cond do
      auth.qr      -> :qr
      auth.phone   -> :phone
      auth.email   -> :email
      auth.passkey -> :passkey
      true         -> :email
    end

    # ── Restore guest cart from session if user just logged in ──────────────
    # SessionController encodes the cart as JSON into session["guest_cart"]
    # before redirecting to login, then clears it after restoring here.
    {cart_items, cart_count, cart_total} = restore_guest_cart(session)

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
      # Cart (restored from session or fresh)
      |> assign(:show_cart, false)
      |> assign(:cart_items, cart_items)
      |> assign(:cart_count, cart_count)
      |> assign(:cart_total, cart_total)
      # Cart share
      |> assign(:show_share_panel, false)
      |> assign(:share_token, nil)
      |> assign(:share_url, nil)
      |> assign(:share_seconds_left, 0)
      |> assign(:show_share_qr, false)
      # Product modal
      |> assign(:selected_product, nil)
      |> assign(:show_modal, false)
      # Coupon
      |> assign(:coupon_code, "")
      |> assign(:coupon_error, nil)
      |> assign(:coupon_discount, nil)

    {:ok, socket, layout: false}
  end

  # ---------------------------------------------------------------------------
  # Info
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
    {:noreply, socket |> assign(:flash_countdown, countdown) |> assign(:qr_countdown, qr_count)}
  end

  # ---------------------------------------------------------------------------
  # Location events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("show_location_modal", _, socket) do
    {:noreply, assign(socket, show_location_modal: true, location_search: "", location_results: [])}
  end

  def handle_event("close_location_modal", _, socket) do
    {:noreply, assign(socket, show_location_modal: false)}
  end

  def handle_event("location_search", %{"query" => q}, socket) when byte_size(q) > 1 do
    all_locations = [
      "Thamel, Kathmandu", "Baneshwor, Kathmandu", "Lazimpat, Kathmandu",
      "Patan, Lalitpur", "Bhaktapur", "Balaju, Kathmandu",
      "Koteshwor, Kathmandu", "Chabahil, Kathmandu", "Boudha, Kathmandu",
      "Kirtipur, Kathmandu", "Kalanki, Kathmandu", "Suryabinayak, Bhaktapur",
      "Imadol, Lalitpur", "Gwarko, Lalitpur", "Kupondol, Lalitpur",
      "Jawalakhel, Lalitpur", "Pulchowk, Lalitpur", "Ekantakuna, Lalitpur",
      "New Baneshwor, Kathmandu", "Old Baneshwor, Kathmandu",
      "Maharajgunj, Kathmandu", "Samakhusi, Kathmandu", "Baluwatar, Kathmandu"
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
    {:noreply, assign(socket,
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
    location = if address != "", do: address, else: "#{Float.round(lat, 4)}, #{Float.round(lng, 4)}"
    {:noreply, assign(socket,
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
    total = length(CatalogComponents.carousel_slides(socket.assigns.slides))
    idx   = rem(socket.assigns.current_slide - 1 + total, max(total, 1))
    {:noreply, assign(socket, :current_slide, idx)}
  end

  def handle_event("next_slide", _, socket) do
    total = length(CatalogComponents.carousel_slides(socket.assigns.slides))
    idx   = rem(socket.assigns.current_slide + 1, max(total, 1))
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
    {:noreply, assign(socket, search_query: q, search_results: results, show_search_dropdown: true)}
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
    name    = if product, do: product.name, else: "Product"
    emoji   = if product, do: (product[:emoji] || product.emoji), else: "🛒"

    items =
      Map.update(socket.assigns.cart_items, pid,
        %{qty: 1, price: price_d, name: name, emoji: emoji},
        fn i -> %{i | qty: i.qty + 1} end
      )

    # BUG FIX 1: cart_count = unique product lines, NOT sum of quantities
    {count, total} = cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("decrement_cart", %{"product_id" => pid}, socket) do
    items =
      case socket.assigns.cart_items[pid] do
        %{qty: 1}        -> Map.delete(socket.assigns.cart_items, pid)
        %{qty: q} = item -> Map.put(socket.assigns.cart_items, pid, %{item | qty: q - 1})
        nil              -> socket.assigns.cart_items
      end
    {count, total} = cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("remove_cart_item", %{"product_id" => pid}, socket) do
    items = Map.delete(socket.assigns.cart_items, pid)
    {count, total} = cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("clear_cart", _, socket) do
    {:noreply, assign(socket,
      cart_items: %{},
      cart_count: 0,
      cart_total: Decimal.new("0")
    )}
  end

  # ---------------------------------------------------------------------------
  # BUG FIX 2: Save guest cart to session BEFORE redirecting to login
  # The session_controller will read "guest_cart" and restore it after auth.
  # ---------------------------------------------------------------------------

  def handle_event("show_login", _, socket) do
    auth = Settings.auth_methods()
    tab  = cond do
      auth.qr -> :qr; auth.phone -> :phone; auth.email -> :email
      auth.passkey -> :passkey; true -> :email
    end

    socket =
      socket
      |> assign(
        show_login_modal: true,
        show_signup_modal: false,
        auth_methods: auth,
        login_tab: tab,
        qr_countdown: 60,
        login_phone_step: 1,
        phone_input: "",
        otp_error: nil
      )
      |> persist_cart_to_session()   # ← save cart before modal opens

    {:noreply, socket}
  end

  def handle_event("close_login", _, socket),
    do: {:noreply, assign(socket, show_login_modal: false)}

  def handle_event("show_signup", _, socket) do
    socket =
      socket
      |> assign(show_signup_modal: true, show_login_modal: false)
      |> persist_cart_to_session()

    {:noreply, socket}
  end

  def handle_event("close_signup", _, socket),
    do: {:noreply, assign(socket, show_signup_modal: false)}

  def handle_event("select_login_tab", %{"tab" => tab}, socket) do
    auth = socket.assigns.auth_methods
    tab_atom = case tab do
      "qr"      when auth.qr      -> :qr
      "phone"   when auth.phone   -> :phone
      "email"   when auth.email   -> :email
      "passkey" when auth.passkey -> :passkey
      _ -> socket.assigns.login_tab
    end
    {:noreply, assign(socket, login_tab: tab_atom, login_phone_step: 1, otp_error: nil)}
  end

  def handle_event("submit_phone", %{"phone" => phone}, socket) do
    if Regex.match?(~r/^\+?[0-9]{8,15}$/, String.trim(phone)) do
      {:noreply, assign(socket,
        login_phone_step: 2,
        phone_input: String.trim(phone),
        otp_error: nil
      )}
    else
      {:noreply, put_flash(socket, :error, "Invalid phone number format.")}
    end
  end

  def handle_event("submit_otp", %{"otp" => otp}, socket) do
    if String.trim(otp) == "123456" do
      {:noreply, redirect(socket, to: ~p"/session/login_phone?phone=#{socket.assigns.phone_input}")}
    else
      {:noreply, assign(socket, otp_error: "Incorrect OTP. Try: 123456")}
    end
  end

  def handle_event("simulate_qr_login", _, socket),
    do: {:noreply, redirect(socket, to: ~p"/session/login_qr")}

  def handle_event("simulate_passkey_login", _, socket) do
    ext_id = Base.url_encode64("demo_passkey_id", padding: false)
    {:noreply, redirect(socket, to: ~p"/session/login_passkey?external_id=#{ext_id}")}
  end

  # ---------------------------------------------------------------------------
  # Cart share
  # ---------------------------------------------------------------------------

  def handle_event("share_cart", _, %{assigns: %{cart_items: items}} = socket)
      when map_size(items) == 0 do
    {:noreply, put_flash(socket, :error, "Add items to cart before sharing.")}
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
        {:noreply, put_flash(socket, :error, "Could not create share link. Please try again.")}
    end
  end

  def handle_event("hide_share_panel", _, socket) do
    {:noreply, assign(socket, show_share_panel: false, show_share_qr: false)}
  end

  def handle_event("show_share_qr", _, socket) do
    {:noreply, assign(socket, show_share_qr: !socket.assigns[:show_share_qr])}
  end

  def handle_event("copy_share_url", _, socket) do
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  # ---------------------------------------------------------------------------
  # Product modal
  # ---------------------------------------------------------------------------

  def handle_event("show_product", %{"product_id" => pid}, socket) do
    product = find_product(pid, socket.assigns)
    {:noreply, assign(socket, selected_product: product, show_modal: !!product)}
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
        {:noreply, assign(socket, coupon_error: nil,
            coupon_discount: %{type: :percent, value: 10, label: "10% off — FIRST10"})}
      "FLAT50" ->
        {:noreply, assign(socket, coupon_error: nil,
            coupon_discount: %{type: :fixed, value: 50, label: "Rs. 50 off — FLAT50"})}
      "DAIRY20" ->
        {:noreply, assign(socket, coupon_error: nil,
            coupon_discount: %{type: :percent, value: 20, label: "20% off — DAIRY20"})}
      _ ->
        {:noreply, assign(socket, coupon_error: "Invalid coupon code", coupon_discount: nil)}
    end
  end

  # ---------------------------------------------------------------------------
  # Public helpers — called from .heex templates
  # ---------------------------------------------------------------------------

  def product_display_list(products, fallback),
    do: CatalogComponents.product_display_list(products, fallback)

  def cart_qty(cart_items, product_id) do
    case Map.get(cart_items, product_id) do
      nil  -> 0
      item -> item.qty
    end
  end

  def popular_fallback, do: [
    %{id: "pop-1", emoji: "🥛", name: "Farm Fresh Milk 500ml",   badge: "badge-new",     badge_label: "NEW",     price: "Rs. 32",  price_raw: "32",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500ml"},
    %{id: "pop-2", emoji: "🍞", name: "Whole Wheat Bread 400g",  badge: "badge-popular", badge_label: "POPULAR", price: "Rs. 45",  price_raw: "45",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "400g"},
    %{id: "pop-3", emoji: "🥚", name: "Free Range Eggs 12pcs",   badge: "badge-sale",    badge_label: "SALE",    price: "Rs. 95",  price_raw: "95",  old_price: "Rs. 110", discount_pct: 14,  time: "10 mins", weight: "12pcs"},
    %{id: "pop-4", emoji: "🍌", name: "Bananas 6pcs Robusta",    badge: nil,             badge_label: nil,       price: "Rs. 39",  price_raw: "39",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "6pcs"},
    %{id: "pop-5", emoji: "🍅", name: "Cherry Tomatoes 250g",    badge: "badge-hot",     badge_label: "HOT",     price: "Rs. 79",  price_raw: "79",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "250g"},
    %{id: "pop-6", emoji: "🥑", name: "Ripe Avocados 2pcs",      badge: "badge-new",     badge_label: "NEW",     price: "Rs. 89",  price_raw: "89",  old_price: "Rs. 120", discount_pct: 26,  time: "10 mins", weight: "2pcs"},
    %{id: "pop-7", emoji: "🧅", name: "Red Onions 1kg",          badge: nil,             badge_label: nil,       price: "Rs. 29",  price_raw: "29",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "1kg"}
  ]

  def fresh_fallback, do: [
    %{id: "fr-1", emoji: "🥦", name: "Broccoli Fresh 350g",      badge: "badge-new",  badge_label: "NEW",  price: "Rs. 69",  price_raw: "69",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "350g"},
    %{id: "fr-2", emoji: "🥕", name: "Carrots Organic 500g",     badge: nil,          badge_label: nil,    price: "Rs. 45",  price_raw: "45",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500g"},
    %{id: "fr-3", emoji: "🌽", name: "Sweet Corn 2pcs",          badge: "badge-hot",  badge_label: "HOT",  price: "Rs. 35",  price_raw: "35",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "2pcs"},
    %{id: "fr-4", emoji: "🫑", name: "Bell Peppers Mixed 3pcs",  badge: nil,          badge_label: nil,    price: "Rs. 89",  price_raw: "89",  old_price: "Rs. 110", discount_pct: 19,  time: "10 mins", weight: "3pcs"},
    %{id: "fr-5", emoji: "🍋", name: "Lemon 6pcs",               badge: nil,          badge_label: nil,    price: "Rs. 29",  price_raw: "29",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "6pcs"},
    %{id: "fr-6", emoji: "🫐", name: "Blueberries 125g",         badge: "badge-sale", badge_label: "SALE", price: "Rs. 149", price_raw: "149", old_price: "Rs. 189", discount_pct: 21,  time: "10 mins", weight: "125g"},
    %{id: "fr-7", emoji: "🍇", name: "Black Grapes 500g",        badge: nil,          badge_label: nil,    price: "Rs. 99",  price_raw: "99",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500g"}
  ]

  def dairy_fallback, do: [
    %{id: "da-1", emoji: "🧀", name: "Amul Cheddar Cheese 200g",  badge: "badge-popular", badge_label: "POPULAR", price: "Rs. 89",  price_raw: "89",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "200g"},
    %{id: "da-2", emoji: "🍦", name: "Amul Greek Yogurt 400g",    badge: nil,             badge_label: nil,       price: "Rs. 79",  price_raw: "79",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "400g"},
    %{id: "da-3", emoji: "🧈", name: "Amul Butter Unsalted 500g", badge: nil,             badge_label: nil,       price: "Rs. 239", price_raw: "239", old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500g"},
    %{id: "da-4", emoji: "🥛", name: "Oat Milk Unsweetened 1L",   badge: "badge-new",     badge_label: "NEW",     price: "Rs. 139", price_raw: "139", old_price: nil,       discount_pct: nil, time: "10 mins", weight: "1L"},
    %{id: "da-5", emoji: "🧆", name: "Paneer Fresh 200g",         badge: "badge-hot",     badge_label: "HOT",     price: "Rs. 69",  price_raw: "69",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "200g"},
    %{id: "da-6", emoji: "🫙", name: "Mishti Doi 400g",           badge: nil,             badge_label: nil,       price: "Rs. 89",  price_raw: "89",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "400g"},
    %{id: "da-7", emoji: "🥚", name: "Quail Eggs 20pcs",          badge: "badge-sale",    badge_label: "SALE",    price: "Rs. 89",  price_raw: "89",  old_price: "Rs. 109", discount_pct: 18,  time: "10 mins", weight: "20pcs"}
  ]

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # BUG FIX 1: count = unique product lines (map keys), NOT sum of quantities
  defp cart_totals(items) do
    count = map_size(items)   # ← was: Enum.reduce summing qty
    total = Enum.reduce(items, Decimal.new("0"), fn {_, i}, acc ->
      Decimal.add(acc, Decimal.mult(i.price, Decimal.new(i.qty)))
    end)
    {count, total}
  end

  # ---------------------------------------------------------------------------
  # BUG FIX 2a: Serialize cart to session via push_event → JS → hidden form
  # We use push_event to store JSON in a cookie-accessible JS call so the
  # Plug session can read it on the next regular HTTP request (login POST).
  # ---------------------------------------------------------------------------
  defp persist_cart_to_session(socket) do
    cart_json = serialize_cart(socket.assigns.cart_items)
    push_event(socket, "persist_guest_cart", %{cart: cart_json})
  end

  defp serialize_cart(items) when map_size(items) == 0, do: "[]"
  defp serialize_cart(items) do
    items
    |> Enum.map(fn {pid, item} ->
      %{
        id:    pid,
        name:  item.name,
        emoji: item.emoji,
        qty:   item.qty,
        price: Decimal.to_string(item.price)
      }
    end)
    |> Jason.encode!()
  end

  # BUG FIX 2b: On mount, read cart back from session (set by SessionController)
  defp restore_guest_cart(session) do
    case session["guest_cart"] do
      nil  -> {%{}, 0, Decimal.new("0")}
      json ->
        items =
          json
          |> Jason.decode!(keys: :strings)
          |> Enum.reduce(%{}, fn entry, acc ->
            pid   = entry["id"]
            price = case Decimal.parse(entry["price"]) do
              {d, _} -> d
              :error -> Decimal.new("0")
            end
            Map.put(acc, pid, %{
              qty:   entry["qty"],
              price: price,
              name:  entry["name"],
              emoji: entry["emoji"]
            })
          end)

        {count, total} = {map_size(items), Enum.reduce(items, Decimal.new("0"), fn {_, i}, acc ->
          Decimal.add(acc, Decimal.mult(i.price, Decimal.new(i.qty)))
        end)}

        {items, count, total}
    end
  end

  defp normalize_product(%Product{} = p) do
    disc = Product.discount_pct(p)
    %{
      id:           p.id,
      emoji:        p.emoji,
      name:         p.name,
      description:  p.description,
      unit:         p.unit,
      base_price:   p.base_price,
      old_price:    p.old_price,
      badge:        if(disc, do: "badge-sale"),
      badge_label:  if(disc, do: "#{disc}% off"),
      price:        Product.format_price(p.base_price),
      price_raw:    p.base_price,
      discount_pct: disc,
      time:         "10 mins",
      weight:       p.unit
    }
  end
  defp normalize_product(p), do: p

  defp find_product(pid, assigns) do
    all_products =
      assigns.popular_products ++
      assigns.fresh_products ++
      assigns.dairy_products ++
      Enum.flat_map(assigns.slides, fn
        %{products: prods} -> prods
        _ -> []
      end)

    case Enum.find(all_products, &(to_string(Map.get(&1, :id, "")) == pid)) do
      nil     -> nil
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

  defp safe_products(_slug, per_page) do
    case Catalog.list_products(is_active: true, per_page: per_page) do
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

  defp parse_price(p) when is_binary(p) do
    case Decimal.parse(p) do
      {d, _} -> d
      :error -> Decimal.new("0")
    end
  end
  defp parse_price(%Decimal{} = d), do: d
  defp parse_price(p),              do: Decimal.new("#{p}")

  defp countdown_label(nil), do: nil
  defp countdown_label(fs),  do: FlashSale.format_countdown(FlashSale.seconds_remaining(fs))
end
