defmodule QcommerceWeb.SearchLive do
  @moduledoc """
  Full-page search experience with filters, sorting, and inline cart management.
  Route: GET /search?q=...
  """
  use QcommerceWeb, :live_view

  alias Qcommerce.Catalog
  alias Qcommerce.Cart.CartSession
  # alias QcommerceWeb.Components.{NavComponents, LayoutComponents, CartPanel}
  # alias QcommerceWeb.Components.CatalogComponents

  @per_page 24

  # Category filter options – slug + label
  @categories [
    %{slug: nil, label: "All"},
    %{slug: "vegetables", label: "Vegetables"},
    %{slug: "fruits", label: "Fruits"},
    %{slug: "dairy-eggs", label: "Dairy & Eggs"},
    %{slug: "bakery", label: "Bakery"},
    %{slug: "meat-fish", label: "Meat & Fish"},
    %{slug: "beverages", label: "Beverages"},
    %{slug: "snacks", label: "Snacks"},
    %{slug: "organic", label: "Organic"},
    %{slug: "health", label: "Health"},
    %{slug: "frozen", label: "Frozen"}
  ]

  @impl true
  def mount(_params, session, socket) do
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

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:selected_location, "Thamel, Kathmandu")
      |> assign(:show_location_modal, false)
      |> assign(:detecting_location, false)
      |> assign(:location_search, "")
      |> assign(:location_results, [])
      # Search state
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:search_results_count, 0)
      |> assign(:loading, false)
      |> assign(:active_category, nil)
      |> assign(:sort, "relevance")
      |> assign(:page, 1)
      |> assign(:has_more, false)
      |> assign(:filter_categories, @categories)
      # Cart
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
      # Auth
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
      # Misc
      |> assign(:selected_product, nil)
      |> assign(:show_modal, false)
      |> assign(:flash_sale, nil)
      |> assign(:flash_countdown, nil)
      |> assign(:search_results, [])

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_params(%{"q" => q} = params, _uri, socket) when byte_size(q) > 0 do
    category_slug = Map.get(params, "category")
    sort = Map.get(params, "sort", "relevance")

    socket =
      socket
      |> assign(:search_query, q)
      |> assign(:active_category, category_slug)
      |> assign(:sort, sort)
      |> assign(:page_title, "Search #{q} — QCommerce")

    {:noreply, run_search(socket)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, page_title: "Search — QCommerce")}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search", %{"query" => q}, socket) do
    params = build_params(q, socket.assigns.active_category, socket.assigns.sort)
    {:noreply, push_patch(socket, to: ~p"/search?#{params}")}
  end

  def handle_event("clear_search", _, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_results_count, 0)
     |> push_patch(to: ~p"/search")}
  end

  def handle_event("set_category", %{"slug" => slug}, socket) do
    slug_val = if slug == "", do: nil, else: slug
    params = build_params(socket.assigns.search_query, slug_val, socket.assigns.sort)
    {:noreply, push_patch(socket, to: ~p"/search?#{params}")}
  end

  def handle_event("set_sort", %{"sort" => sort}, socket) do
    params = build_params(socket.assigns.search_query, socket.assigns.active_category, sort)
    {:noreply, push_patch(socket, to: ~p"/search?#{params}")}
  end

  def handle_event("load_more", _, socket) do
    next_page = socket.assigns.page + 1

    {:ok, {new_results, meta}} =
      Catalog.list_products(
        q: socket.assigns.search_query,
        is_active: true,
        per_page: @per_page,
        page: next_page,
        sort: sort_field(socket.assigns.sort),
        dir: sort_dir(socket.assigns.sort)
      )

    all_results = socket.assigns.search_results ++ format_results(new_results)

    {:noreply,
     socket
     |> assign(:search_results, all_results)
     |> assign(:page, next_page)
     |> assign(:has_more, meta.total > length(all_results))}
  end

  # Cart events
  def handle_event("toggle_cart", _, socket),
    do: {:noreply, assign(socket, show_cart: !socket.assigns.show_cart)}

  def handle_event("close_cart", _, socket),
    do: {:noreply, assign(socket, show_cart: false)}

  def handle_event("add_to_cart", %{"product_id" => pid, "price" => price}, socket) do
    product = Enum.find(socket.assigns.search_results, &(to_string(&1.id) == pid))
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

  # Product modal
  def handle_event("show_product", %{"product_id" => pid}, socket) do
    product = Enum.find(socket.assigns.search_results, &(to_string(&1.id) == pid))
    {:noreply, assign(socket, selected_product: product, show_modal: !!product)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_product: nil)}
  end

  # Coupon
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

  # Share cart
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

  # Auth (delegate to same handlers as HomeLive)
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

  def handle_event("gps_denied", _, socket),
    do: {:noreply, assign(socket, detecting_location: false)}

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

  defp run_search(socket) do
    q = socket.assigns.search_query
    sort = socket.assigns.sort

    {:ok, {results, meta}} =
      Catalog.list_products(
        q: q,
        is_active: true,
        per_page: @per_page,
        page: 1,
        sort: sort_field(sort),
        dir: sort_dir(sort)
      )

    formatted = format_results(results)

    socket
    |> assign(:search_results, formatted)
    |> assign(:search_results_count, meta.total)
    |> assign(:page, 1)
    |> assign(:has_more, meta.total > length(formatted))
    |> assign(:loading, false)
  end

  defp format_results(products) do
    Enum.map(products, fn p ->
      disc = Qcommerce.Catalog.Product.discount_pct(p)

      %{
        id: p.id,
        emoji: p.emoji,
        name: p.name,
        badge: badge_class(disc),
        badge_label: badge_label(disc),
        price: Qcommerce.Catalog.Product.format_price(p.base_price),
        price_raw: p.base_price,
        old_price: if(p.old_price, do: Qcommerce.Catalog.Product.format_price(p.old_price)),
        discount_pct: disc,
        time: "10 mins",
        weight: p.unit,
        description: p.description
      }
    end)
  end

  defp sort_field("price_asc"), do: :base_price
  defp sort_field("price_desc"), do: :base_price
  defp sort_field(_), do: :name

  defp sort_dir("price_desc"), do: :desc
  defp sort_dir(_), do: :asc

  defp badge_class(nil), do: nil
  defp badge_class(_), do: "badge-sale"
  defp badge_label(nil), do: nil
  defp badge_label(pct), do: "#{pct}% off"

  defp build_params(q, nil, sort), do: %{q: q, sort: sort}
  defp build_params(q, category, sort), do: %{q: q, category: category, sort: sort}

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
      "Balaju, Kathmandu",
      "Koteshwor, Kathmandu",
      "Chabahil, Kathmandu",
      "Boudha, Kathmandu",
      "Kirtipur, Kathmandu",
      "Kalanki, Kathmandu",
      "Maharajgunj, Kathmandu",
      "Samakhusi, Kathmandu",
      "Pulchowk, Lalitpur",
      "Jawalakhel, Lalitpur"
    ]
    |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(q)))
    |> Enum.take(6)
  end

  # Template helper
  def cart_qty(cart_items, product_id) do
    case Map.get(cart_items, to_string(product_id)) do
      nil -> 0
      item -> item.qty
    end
  end
end
