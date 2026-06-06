# lib/qcommerce_web/live/home_live.ex
defmodule QcommerceWeb.HomeLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.Catalog
  alias Qcommerce.Catalog.{Product, FlashSale}
  alias Qcommerce.Settings

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
    dairy      = safe_products("dairy", 7)
    flash_sale = safe_flash_sale()
    auth       = Qcommerce.Settings.auth_methods()

    # Default to first enabled tab
    default_tab =
      cond do
        auth.qr      -> :qr
        auth.phone   -> :phone
        auth.email   -> :email
        auth.passkey -> :passkey
        true         -> :email
      end

    socket =
      socket
      |> assign(:page_title, "QCommerce — 10 min delivery")
      |> assign(:current_user, current_user)
      |> assign(:show_login_modal, false)
      |> assign(:show_signup_modal, false)
      |> assign(:auth_methods, auth)
      |> assign(:login_tab, default_tab)
      |> assign(:qr_countdown, 60)
      |> assign(:login_phone_step, 1)
      |> assign(:phone_input, "")
      |> assign(:otp_error, nil)
      |> assign(:slides, slides)
      |> assign(:current_slide, 0)
      |> assign(:categories, categories)
      |> assign(:popular_products, popular)
      |> assign(:fresh_products, fresh)
      |> assign(:dairy_products, dairy)
      |> assign(:flash_sale, flash_sale)
      |> assign(:flash_countdown, countdown_label(flash_sale))
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:cart_count, 0)
      |> assign(:cart_total, Decimal.new("0"))
      |> assign(:cart_items, %{})
      |> assign(:selected_product, nil)
      |> assign(:show_modal, false)
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

    {:noreply,
     socket
     |> assign(:flash_countdown, countdown)
     |> assign(:qr_countdown, qr_count)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
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

  def handle_event("search", %{"query" => q}, socket) when byte_size(q) > 2 do
    {:ok, {results, _}} = Catalog.list_products(q: q, is_active: true, per_page: 6)
    {:noreply, assign(socket, search_query: q, search_results: results)}
  end

  def handle_event("search", %{"query" => q}, socket) do
    {:noreply, assign(socket, search_query: q, search_results: [])}
  end

  def handle_event("clear_search", _, socket) do
    {:noreply, assign(socket, search_query: "", search_results: [])}
  end

  def handle_event("add_to_cart", %{"product_id" => pid, "price" => price}, socket) do
    price_d = parse_price(price)

    items =
      Map.update(socket.assigns.cart_items, pid, %{qty: 1, price: price_d}, fn i ->
        %{i | qty: i.qty + 1}
      end)

    {count, total} = cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("decrement_cart", %{"product_id" => pid}, socket) do
    items =
      case socket.assigns.cart_items[pid] do
        %{qty: 1} -> Map.delete(socket.assigns.cart_items, pid)
        %{qty: q} = item -> Map.put(socket.assigns.cart_items, pid, %{item | qty: q - 1})
        nil -> socket.assigns.cart_items
      end

    {count, total} = cart_totals(items)
    {:noreply, assign(socket, cart_items: items, cart_count: count, cart_total: total)}
  end

  def handle_event("show_product", %{"product_id" => pid}, socket) do
    product =
      Enum.find(socket.assigns.popular_products, &(&1.id == pid)) ||
        Enum.find(socket.assigns.fresh_products, &(&1.id == pid)) ||
        Enum.find(socket.assigns.dairy_products, &(&1.id == pid))

    {:noreply, assign(socket, selected_product: product, show_modal: !!product)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_product: nil)}
  end

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

  def handle_event("show_login", _, socket) do
    # Always read fresh from ETS so admin toggles are reflected instantly
    auth = Settings.auth_methods()
    default_tab =
      cond do
        auth.qr      -> :qr
        auth.phone   -> :phone
        auth.email   -> :email
        auth.passkey -> :passkey
        true         -> :email
      end

    {:noreply, assign(socket,
      show_login_modal: true,
      show_signup_modal: false,
      auth_methods: auth,
      login_tab: default_tab,
      qr_countdown: 60,
      login_phone_step: 1,
      phone_input: "",
      otp_error: nil
    )}
  end

  def handle_event("close_login", _, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  def handle_event("show_signup", _, socket) do
    {:noreply, assign(socket, show_signup_modal: true, show_login_modal: false)}
  end

  def handle_event("close_signup", _, socket) do
    {:noreply, assign(socket, show_signup_modal: false)}
  end

  def handle_event("select_login_tab", %{"tab" => tab}, socket) do
    auth = socket.assigns.auth_methods
    tab_atom =
      case tab do
        "qr"      when auth.qr      -> :qr
        "phone"   when auth.phone   -> :phone
        "email"   when auth.email   -> :email
        "passkey" when auth.passkey -> :passkey
        # fallback: keep current tab if requested tab is disabled
        _         -> socket.assigns.login_tab
      end
    {:noreply, assign(socket, login_tab: tab_atom, login_phone_step: 1, otp_error: nil)}
  end

  def handle_event("submit_phone", %{"phone" => phone}, socket) do
    if Regex.match?(~r/^\+?[0-9]{8,15}$/, String.trim(phone)) do
      {:noreply, assign(socket, login_phone_step: 2, phone_input: String.trim(phone), otp_error: nil)}
    else
      {:noreply, put_flash(socket, :error, "Invalid phone number format.")}
    end
  end

  def handle_event("submit_otp", %{"otp" => otp}, socket) do
    if String.trim(otp) == "123456" do
      phone = socket.assigns.phone_input
      {:noreply, redirect(socket, to: ~p"/session/login_phone?phone=#{phone}")}
    else
      {:noreply, assign(socket, otp_error: "Invalid OTP. Please enter 123456.")}
    end
  end

  def handle_event("simulate_qr_login", _, socket) do
    {:noreply, redirect(socket, to: ~p"/session/login_qr")}
  end

  def handle_event("simulate_passkey_login", _, socket) do
    ext_id = Base.url_encode64("demo_passkey_id", padding: false)
    {:noreply, redirect(socket, to: ~p"/session/login_passkey?external_id=#{ext_id}")}
  end
  # ---------------------------------------------------------------------------
  # Public helpers (called from .heex template)
  # ---------------------------------------------------------------------------

  def carousel_slides([]), do: static_slides()
  def carousel_slides(db_slides) do
    Enum.map(db_slides, fn s ->
      %{
        theme:    s.theme,
        tag:      s.tag,
        h2:       s.heading,
        p:        s.sub,
        cta:      s.cta_label,
        emoji:    s.emojis,
        products: Enum.map(s.products, &db_product_to_chip/1)
      }
    end)
  end

  def category_list([]) do
    [
      %{emoji: "🥬", name: "Vegetables"}, %{emoji: "🍎", name: "Fruits"},
      %{emoji: "🥛", name: "Dairy"},     %{emoji: "🍞", name: "Bakery"},
      %{emoji: "🥩", name: "Meat"},      %{emoji: "🧃", name: "Beverages"},
      %{emoji: "🍫", name: "Snacks"},    %{emoji: "🧴", name: "Beauty"},
      %{emoji: "🧹", name: "Cleaning"},  %{emoji: "👶", name: "Baby"},
      %{emoji: "🐾", name: "Pet Care"},  %{emoji: "❄️", name: "Frozen"},
      %{emoji: "🍳", name: "Breakfast"}, %{emoji: "🌿", name: "Organic"},
      %{emoji: "💊", name: "Health"}
    ]
  end
  def category_list(cats) do
    Enum.map(cats, fn c -> %{emoji: get_category_emoji(c), name: c.name} end)
  end

  defp get_category_emoji(c) do
    cond do
      c.image_url && String.length(String.trim(c.image_url)) == 1 ->
        c.image_url
      true ->
        case String.downcase(c.slug || "") do
          "vegetables" -> "🥬"
          "fruits" -> "🍎"
          "dairy" -> "🥛"
          "bakery" -> "🍞"
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
  end

  def product_display_list([], fallback), do: fallback
  def product_display_list(db_products, _fallback) do
    Enum.map(db_products, fn p ->
      disc = Product.discount_pct(p)
      %{
        id:           p.id,
        emoji:        p.emoji,
        name:         p.name,
        badge:        badge_class(disc, p),
        badge_label:  badge_label(disc, p),
        price:        Product.format_price(p.base_price),
        price_raw:    p.base_price,
        old_price:    if(p.old_price, do: Product.format_price(p.old_price)),
        discount_pct: disc,
        time:         "10 mins",
        weight:       p.unit
      }
    end)
  end

  def popular_fallback do
    [
      %{id: "pop-1", emoji: "🥛", name: "Farm Fresh Milk 500ml",   badge: "badge-new",  badge_label: "NEW",     price: "Rs. 32",  price_raw: "32",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500ml"},
      %{id: "pop-2", emoji: "🍞", name: "Whole Wheat Bread 400g",  badge: "badge-popular", badge_label: "POPULAR",price: "Rs. 45",  price_raw: "45",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "400g"},
      %{id: "pop-3", emoji: "🥚", name: "Free Range Eggs 12pcs",   badge: "badge-sale", badge_label: "SALE",    price: "Rs. 95",  price_raw: "95",  old_price: "Rs. 110", discount_pct: 14,  time: "10 mins", weight: "12pcs"},
      %{id: "pop-4", emoji: "🍌", name: "Bananas 6pcs Robusta",    badge: nil,          badge_label: nil,       price: "Rs. 39",  price_raw: "39",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "6pcs"},
      %{id: "pop-5", emoji: "🍅", name: "Cherry Tomatoes 250g",    badge: "badge-hot",  badge_label: "HOT",     price: "Rs. 79",  price_raw: "79",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "250g"},
      %{id: "pop-6", emoji: "🥑", name: "Ripe Avocados 2pcs",      badge: "badge-new",  badge_label: "NEW",     price: "Rs. 89",  price_raw: "89",  old_price: "Rs. 120", discount_pct: 26,  time: "10 mins", weight: "2pcs"},
      %{id: "pop-7", emoji: "🧅", name: "Red Onions 1kg",          badge: nil,          badge_label: nil,       price: "Rs. 29",  price_raw: "29",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "1kg"}
    ]
  end

  def fresh_fallback do
    [
      %{id: "fr-1", emoji: "🥦", name: "Broccoli Fresh 350g",        badge: "badge-new",  badge_label: "NEW",  price: "Rs. 69",  price_raw: "69",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "350g"},
      %{id: "fr-2", emoji: "🥕", name: "Carrots Organic 500g",       badge: nil,          badge_label: nil,    price: "Rs. 45",  price_raw: "45",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500g"},
      %{id: "fr-3", emoji: "🌽", name: "Sweet Corn 2pcs",            badge: "badge-hot",  badge_label: "HOT",  price: "Rs. 35",  price_raw: "35",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "2pcs"},
      %{id: "fr-4", emoji: "🫑", name: "Bell Peppers Mixed 3pcs",    badge: nil,          badge_label: nil,    price: "Rs. 89",  price_raw: "89",  old_price: "Rs. 110", discount_pct: 19,  time: "10 mins", weight: "3pcs"},
      %{id: "fr-5", emoji: "🍋", name: "Lemon 6pcs",                 badge: nil,          badge_label: nil,    price: "Rs. 29",  price_raw: "29",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "6pcs"},
      %{id: "fr-6", emoji: "🫐", name: "Blueberries 125g",           badge: "badge-sale", badge_label: "SALE", price: "Rs. 149", price_raw: "149", old_price: "Rs. 189", discount_pct: 21,  time: "10 mins", weight: "125g"},
      %{id: "fr-7", emoji: "🍇", name: "Black Grapes Seedless 500g", badge: nil,          badge_label: nil,    price: "Rs. 99",  price_raw: "99",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500g"}
    ]
  end

  def dairy_fallback do
    [
      %{id: "da-1", emoji: "🧀", name: "Amul Cheddar Cheese 200g",  badge: "badge-popular", badge_label: "POPULAR", price: "Rs. 89",  price_raw: "89",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "200g"},
      %{id: "da-2", emoji: "🍦", name: "Amul Greek Yogurt 400g",    badge: nil,             badge_label: nil,       price: "Rs. 79",  price_raw: "79",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "400g"},
      %{id: "da-3", emoji: "🧈", name: "Amul Butter Unsalted 500g", badge: nil,             badge_label: nil,       price: "Rs. 239", price_raw: "239", old_price: nil,       discount_pct: nil, time: "10 mins", weight: "500g"},
      %{id: "da-4", emoji: "🥛", name: "Oat Milk Unsweetened 1L",   badge: "badge-new",     badge_label: "NEW",     price: "Rs. 139", price_raw: "139", old_price: nil,       discount_pct: nil, time: "10 mins", weight: "1L"},
      %{id: "da-5", emoji: "🧆", name: "Paneer Fresh 200g",         badge: "badge-hot",     badge_label: "HOT",     price: "Rs. 69",  price_raw: "69",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "200g"},
      %{id: "da-6", emoji: "🫙", name: "Mishti Doi 400g",           badge: nil,             badge_label: nil,       price: "Rs. 89",  price_raw: "89",  old_price: nil,       discount_pct: nil, time: "10 mins", weight: "400g"},
      %{id: "da-7", emoji: "🥚", name: "Quail Eggs 20pcs",          badge: "badge-sale",    badge_label: "SALE",    price: "Rs. 89",  price_raw: "89",  old_price: "Rs. 109", discount_pct: 18,  time: "10 mins", weight: "20pcs"}
    ]
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

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

  defp safe_products(category_slug, per_page) do
    opts = [is_active: true, per_page: per_page]
    opts = if category_slug, do: [{:category_slug, category_slug} | opts], else: opts

    case Catalog.list_products(opts) do
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
    disc = Product.discount_pct(p)
    %{
      id:    p.id,
      emoji: p.emoji,
      name:  p.name,
      badge: if(disc, do: "SALE"),
      time:  "10 mins",
      price: Product.format_price(p.base_price),
      price_raw: p.base_price
    }
  end

  defp badge_class(nil, _p), do: nil
  defp badge_class(_disc, _p), do: "badge-sale"

  defp badge_label(nil, _p), do: nil
  defp badge_label(pct, _p), do: "#{pct}% off"

  defp cart_totals(items) do
    count = Enum.reduce(items, 0, fn {_, i}, acc -> acc + i.qty end)

    total =
      Enum.reduce(items, Decimal.new("0"), fn {_, i}, acc ->
        Decimal.add(acc, Decimal.mult(i.price, Decimal.new(i.qty)))
      end)

    {count, total}
  end

  defp parse_price(price) when is_binary(price) do
    case Decimal.parse(price) do
      {d, _} -> d
      :error -> Decimal.new("0")
    end
  end
  defp parse_price(%Decimal{} = d), do: d
  defp parse_price(price), do: Decimal.new("#{price}")

  defp countdown_label(nil), do: nil
  defp countdown_label(flash_sale),
    do: FlashSale.format_countdown(FlashSale.seconds_remaining(flash_sale))

  defp static_slides do
    [
      %{
        theme: "slide-0", tag: "⚡ 10 Min Delivery",
        h2: "Freshness at <em>lightning speed</em>",
        p: "5,000+ products · zero waiting", cta: "Shop now",
        emoji: ["🛒", "🥦", "🍎"],
        products: [
          %{id: "s0-1", emoji: "🥑", name: "Organic Avocado Pack of 3", badge: "NEW",  time: "10 mins", price: "Rs. 89",  price_raw: "89"},
          %{id: "s0-2", emoji: "🫐", name: "Fresh Blueberries 125g",    badge: "FRESH",time: "10 mins", price: "Rs. 149", price_raw: "149"},
          %{id: "s0-3", emoji: "🥝", name: "Kiwi Fruit 4pcs",           badge: "SALE", time: "10 mins", price: "Rs. 79",  price_raw: "79"},
          %{id: "s0-4", emoji: "🍓", name: "Strawberries 250g",         badge: nil,    time: "10 mins", price: "Rs. 119", price_raw: "119"},
          %{id: "s0-5", emoji: "🥭", name: "Alphonso Mango 500g",       badge: "HOT",  time: "10 mins", price: "Rs. 189", price_raw: "189"}
        ]
      },
      %{
        theme: "slide-1", tag: "🥛 Dairy Fresh",
        h2: "Farm fresh <em>dairy</em> every morning",
        p: "Delivered cold · certified organic", cta: "Explore dairy",
        emoji: ["🥛", "🧀", "🥚"],
        products: [
          %{id: "s1-1", emoji: "🥛", name: "Farm Fresh Full Cream Milk 500ml", badge: nil,    time: "10 mins", price: "Rs. 32", price_raw: "32"},
          %{id: "s1-2", emoji: "🧀", name: "Amul Processed Cheese 200g",       badge: nil,    time: "10 mins", price: "Rs. 89", price_raw: "89"},
          %{id: "s1-3", emoji: "🥚", name: "Free Range Eggs Tray of 12",       badge: "SALE", time: "10 mins", price: "Rs. 95", price_raw: "95"},
          %{id: "s1-4", emoji: "🧈", name: "Amul Butter 100g",                 badge: nil,    time: "10 mins", price: "Rs. 55", price_raw: "55"},
          %{id: "s1-5", emoji: "🍦", name: "Greek Yogurt 400g",                badge: "NEW",  time: "10 mins", price: "Rs. 79", price_raw: "79"}
        ]
      },
      %{
        theme: "slide-2", tag: "🍫 Snacks & Munchies",
        h2: "Late night <em>cravings</em> sorted",
        p: "Chocolates, chips & more · 1000+ options", cta: "Shop snacks",
        emoji: ["🍫", "🍿", "🧃"],
        products: [
          %{id: "s2-1", emoji: "🍫", name: "Dairy Milk Silk 160g",      badge: nil,    time: "10 mins", price: "Rs. 139", price_raw: "139"},
          %{id: "s2-2", emoji: "🍿", name: "Act II Popcorn Butter 30g", badge: "HOT",  time: "10 mins", price: "Rs. 25",  price_raw: "25"},
          %{id: "s2-3", emoji: "🥨", name: "Pringles Original 107g",    badge: nil,    time: "10 mins", price: "Rs. 179", price_raw: "179"},
          %{id: "s2-4", emoji: "🧃", name: "Real Fruit Mango 1L",       badge: "SALE", time: "10 mins", price: "Rs. 75",  price_raw: "75"},
          %{id: "s2-5", emoji: "🍬", name: "Haribo Goldbears 200g",     badge: "NEW",  time: "10 mins", price: "Rs. 149", price_raw: "149"}
        ]
      },
      %{
        theme: "slide-3", tag: "🥩 Meat & Seafood",
        h2: "Premium <em>proteins</em> delivered fresh",
        p: "Sourced daily · hygiene certified", cta: "Shop meat",
        emoji: ["🥩", "🐟", "🍗"],
        products: [
          %{id: "s3-1", emoji: "🍗", name: "Chicken Breast 500g boneless", badge: "FRESH", time: "10 mins", price: "Rs. 259", price_raw: "259"},
          %{id: "s3-2", emoji: "🥩", name: "Mutton Boneless 250g",         badge: nil,     time: "10 mins", price: "Rs. 349", price_raw: "349"},
          %{id: "s3-3", emoji: "🐟", name: "Salmon Fillet 200g",           badge: "HOT",   time: "10 mins", price: "Rs. 449", price_raw: "449"},
          %{id: "s3-4", emoji: "🦐", name: "Tiger Prawns 250g cleaned",    badge: nil,     time: "10 mins", price: "Rs. 299", price_raw: "299"},
          %{id: "s3-5", emoji: "🥚", name: "Quail Eggs pack of 20",        badge: "NEW",   time: "10 mins", price: "Rs. 89",  price_raw: "89"}
        ]
      },
      %{
        theme: "slide-4", tag: "🧹 Home Essentials",
        h2: "Clean home, <em>happy life</em>",
        p: "Cleaning, personal care & baby products", cta: "Explore now",
        emoji: ["🧴", "🧹", "🪥"],
        products: [
          %{id: "s4-1", emoji: "🧴", name: "Dettol Hand Sanitizer 500ml",    badge: nil,    time: "10 mins", price: "Rs. 185", price_raw: "185"},
          %{id: "s4-2", emoji: "🧹", name: "Scotch Brite Scrub Pad 3pcs",    badge: "HOT",  time: "10 mins", price: "Rs. 49",  price_raw: "49"},
          %{id: "s4-3", emoji: "🪥", name: "Colgate MaxFresh 150g",          badge: "SALE", time: "10 mins", price: "Rs. 79",  price_raw: "79"},
          %{id: "s4-4", emoji: "🧼", name: "Dove Beauty Bar Soap 100g",      badge: nil,    time: "10 mins", price: "Rs. 55",  price_raw: "55"},
          %{id: "s4-5", emoji: "🪒", name: "Gillette Fusion 5 Razor 1pc",    badge: "NEW",  time: "10 mins", price: "Rs. 299", price_raw: "299"}
        ]
      }
    ]
  end
end
