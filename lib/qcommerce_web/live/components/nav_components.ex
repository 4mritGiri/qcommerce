defmodule QcommerceWeb.NavComponents do
  use QcommerceWeb, :html

  # ---------------------------------------------------------------------------
  # Flash Sale Banner
  # ---------------------------------------------------------------------------
  attr :flash_sale, :map, default: nil
  attr :flash_countdown, :string, default: nil

  def flash_sale_bar(assigns) do
    ~H"""
    <%= if @flash_sale && @flash_countdown != "Expired" do %>
      <div style="background:var(--accent);color:#fff;text-align:center;padding:8px 16px;font-size:13px;font-weight:600;letter-spacing:.3px">
        ⚡ Flash Sale — <%= @flash_sale.discount_pct %>% off &nbsp;·&nbsp;
        <strong>Ends in <%= @flash_countdown %></strong>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Navbar
  # ---------------------------------------------------------------------------
  attr :current_user,       :map,    default: nil
  attr :selected_location,  :string, required: true
  attr :search_query,       :string, default: ""
  attr :search_results,     :list,   default: []
  attr :cart_count,         :integer, default: 0

  def navbar(assigns) do
    ~H"""
    <nav class="nav">
      <a href="/" class="nav-logo">
        <div class="nav-logo-icon">Q</div>
        <div class="nav-logo-text">Q<span>Commerce</span></div>
      </a>

      <button class="nav-location"
        phx-click="show_location_modal"
        style="background:none;border:none;cursor:pointer;display:flex;align-items:center;gap:6px;padding:4px 8px;border-radius:8px;transition:background .15s"
        onmouseover="this.style.background='#f3f4f6'"
        onmouseout="this.style.background='none'">
        <span class="nav-location-pin">📍</span>
        <div class="nav-location-text" style="text-align:left">
          <strong style="display:block;font-size:13px;line-height:1.2">
            <%= @selected_location |> String.split(",") |> List.first() %>
          </strong>
          <span style="font-size:11px;color:#6b7280;max-width:140px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:block">
            <%= @selected_location %> ▼
          </span>
        </div>
      </button>

      <div class="nav-search">
        <form phx-change="search" phx-submit="search" style="width:100%;position:relative">
          <input type="text" name="query" value={@search_query}
            placeholder='Search for "milk", "eggs", "bread"...'
            autocomplete="off" phx-debounce="300" />
          <span class="nav-search-icon">🔍</span>
        </form>
        <%= if length(@search_results) > 0 do %>
          <div style="position:absolute;top:calc(100% + 6px);left:0;right:0;background:#fff;border:1.5px solid var(--border);border-radius:12px;box-shadow:0 8px 30px rgba(0,0,0,.1);z-index:300;overflow:hidden">
            <%= for p <- @search_results do %>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 14px;cursor:pointer;transition:background .15s"
                   phx-click="show_product" phx-value-product_id={p.id}>
                <span style="font-size:14px"><%= p.emoji %> <%= p.name %></span>
                <span style="font-size:13px;font-weight:700;color:var(--green)">
                  <%= Qcommerce.Catalog.Product.format_price(p.base_price) %>
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <div class="nav-right">
        <%= if @current_user do %>
          <span style="font-size:13px;font-weight:600;color:var(--text2);margin-right:4px">
            Hi, <%= @current_user.full_name %>
          </span>
          <form action={~p"/session/logout"} method="post" style="margin:0">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <button type="submit" class="nav-btn nav-btn-ghost">Logout</button>
          </form>
        <% else %>
          <button class="nav-btn nav-btn-ghost" phx-click="show_login">Login</button>
          <button class="nav-btn nav-btn-primary" phx-click="show_signup">Sign up</button>
        <% end %>

        <button class="nav-cart" phx-click="toggle_cart"
          style="cursor:pointer;background:none;border:none;display:flex;align-items:center;gap:6px">
          <span>🛒</span>
          <span>Cart</span>
          <span class="nav-cart-count"><%= @cart_count %></span>
        </button>

        <div class="nav-menu-btn" id="hamburgerBtn">
          <span></span><span></span><span></span>
        </div>
      </div>
    </nav>
    """
  end

  # ---------------------------------------------------------------------------
  # Mobile Nav
  # ---------------------------------------------------------------------------
  def mobile_nav(assigns) do
    ~H"""
    <div class="mobile-nav" id="mobileNav">
      <div class="mobile-nav-head">
        <div class="nav-logo">
          <div class="nav-logo-icon">Q</div>
          <div class="nav-logo-text">Q<span style="color:var(--green)">Commerce</span></div>
        </div>
        <button class="mobile-nav-close" onclick="closeMobileNav()">✕</button>
      </div>
      <a href="/" onclick="closeMobileNav()">Home</a>
      <a href="#" onclick="closeMobileNav()">Categories</a>
      <a href="#" onclick="closeMobileNav()">Orders</a>
      <a href="#" onclick="closeMobileNav()">Profile</a>
      <a href="#" onclick="closeMobileNav()">Login / Sign up</a>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Location Modal
  # ---------------------------------------------------------------------------
  attr :show_location_modal,  :boolean, default: false
  attr :detecting_location,   :boolean, default: false
  attr :location_search,      :string,  default: ""
  attr :location_results,     :list,    default: []

  def location_modal(assigns) do
    ~H"""
    <%= if @show_location_modal do %>
      <div style="position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:500;display:flex;align-items:flex-start;justify-content:center;padding-top:80px"
           phx-click="close_location_modal">
        <div style="background:#fff;border-radius:16px;width:100%;max-width:440px;box-shadow:0 8px 32px rgba(0,0,0,.15);overflow:hidden"
             phx-click="">
          <div style="display:flex;align-items:center;padding:16px 20px;border-bottom:1px solid #e5e7eb">
            <span style="font-size:15px;font-weight:700">📍 Choose delivery location</span>
            <button phx-click="close_location_modal"
              style="margin-left:auto;background:#f3f4f6;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;font-size:14px">✕</button>
          </div>

          <div style="padding:16px 20px">
            <button phx-click="detect_location"
              style="width:100%;display:flex;align-items:center;gap:12px;padding:12px 14px;border:1.5px dashed #1aad54;border-radius:10px;background:#e6f9ee;cursor:pointer;margin-bottom:14px;text-align:left">
              <span style="font-size:1.3rem"><%= if @detecting_location, do: "⏳", else: "🎯" %></span>
              <div>
                <div style="font-size:13px;font-weight:700;color:#148f44">
                  <%= if @detecting_location, do: "Detecting your location…", else: "Use current location" %>
                </div>
                <div style="font-size:11px;color:#6b7280;margin-top:2px">Using GPS · Accurate to 100m</div>
              </div>
            </button>

            <div style="text-align:center;font-size:11px;color:#9ca3af;margin:10px 0;position:relative">
              <span style="background:#fff;padding:0 10px;position:relative;z-index:1">or search manually</span>
              <div style="position:absolute;top:50%;left:0;right:0;height:1px;background:#e5e7eb"></div>
            </div>

            <div style="position:relative;margin-bottom:8px">
              <span style="position:absolute;left:10px;top:50%;transform:translateY(-50%);font-size:13px">🔍</span>
              <input type="text"
                placeholder="Search area, street, landmark…"
                value={@location_search}
                phx-input="location_search"
                phx-debounce="200"
                name="query"
                autocomplete="off"
                style="width:100%;padding:10px 12px 10px 32px;border:1.5px solid #e5e7eb;border-radius:8px;font-size:13px;outline:none" />
            </div>

            <%= for loc <- @location_results do %>
              <div phx-click="select_location" phx-value-location={loc}
                style="display:flex;align-items:center;gap:8px;padding:10px 8px;border-radius:8px;cursor:pointer;font-size:13px;color:#374151;transition:background .1s"
                onmouseover="this.style.background='#f3f4f6'"
                onmouseout="this.style.background=''">
                <span style="color:#1aad54">📍</span><%= loc %>
              </div>
            <% end %>

            <%= if @location_results == [] && byte_size(@location_search) > 1 do %>
              <div style="text-align:center;padding:16px;color:#9ca3af;font-size:13px">
                No results for "<%= @location_search %>"
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Mobile Nav JS (call once at bottom of page)
  # ---------------------------------------------------------------------------
  def mobile_nav_js(assigns) do
    ~H"""
    <script>
      function openMobileNav(){document.getElementById('mobileNav').classList.add('open');document.body.style.overflow='hidden'}
      function closeMobileNav(){document.getElementById('mobileNav').classList.remove('open');document.body.style.overflow=''}
      document.getElementById('hamburgerBtn')?.addEventListener('click', openMobileNav);
      let touchX=0;
      document.addEventListener('touchstart',e=>{touchX=e.touches[0].clientX},{passive:true});
      document.addEventListener('touchend',e=>{
        const dx=e.changedTouches[0].clientX-touchX;
        if(Math.abs(dx)>50){
          if(dx<0) document.querySelector('[phx-click="next_slide"]')?.click();
          else document.querySelector('[phx-click="prev_slide"]')?.click();
        }
      },{passive:true});
    </script>
    """
  end
end
