# lib/qcommerce_web/components/catalog_components.ex
defmodule QcommerceWeb.Components.CatalogComponents do
  use QcommerceWeb, :html
  import Phoenix.HTML, only: [raw: 1]

  alias Qcommerce.Catalog.Product

  # ---------------------------------------------------------------------------
  # Data helpers  (moved here from home_live.ex so components compile cleanly)
  # ---------------------------------------------------------------------------

  def carousel_slides(db_slides) do
    Enum.map(db_slides || [], fn s ->
      %{
        theme: s.theme,
        tag: s.tag,
        h2: s.heading,
        p: s.sub,
        cta: s.cta_label,
        emoji: s.emojis || [],
        products: Enum.map(s.products || [], &db_product_to_chip/1)
      }
    end)
  end

  def category_list(cats) do
    Enum.map(cats || [], fn c -> %{emoji: c.emoji || "🛍️", name: c.name} end)
  end

  def product_display_list(db_products) do
    Enum.map(db_products || [], fn p ->
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

  # ---------------------------------------------------------------------------
  # Private data helpers
  # ---------------------------------------------------------------------------

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
  # Section Header
  # ---------------------------------------------------------------------------
  attr :title, :string, required: true
  attr :see_all_href, :string, default: "#"

  def section_head(assigns) do
    ~H"""
    <div class="section-head">
      <div class="section-title">{@title}</div>
      <a href={@see_all_href} class="section-see-all">See all →</a>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Hero Carousel
  # ---------------------------------------------------------------------------
  attr :slides, :list, required: true
  attr :current_slide, :integer, default: 0

  def carousel(assigns) do
    ~H"""
    <div class="carousel-wrap">
      <div class="carousel-dots" id="dots">
        <%= for {_s, idx} <- Enum.with_index(carousel_slides(@slides)) do %>
          <div
            class={"dot #{if idx == @current_slide, do: "active"}"}
            phx-click="go_slide"
            phx-value-index={idx}
          >
          </div>
        <% end %>
      </div>
      <div class="carousel-viewport">
        <div
          class="carousel-track"
          id="track"
          style={"transform:translateX(-#{@current_slide * 100}%)"}
        >
          <%= for slide <- carousel_slides(@slides) do %>
            <div class="carousel-slide">
              <div class={"slide-banner #{slide.theme}"}>
                <div class="slide-banner-content">
                  <div class="slide-banner-tag">
                    <span class="slide-banner-tag-dot"></span>{slide.tag}
                  </div>
                  <h2>{raw(slide.h2)}</h2>
                  <p>{slide.p}</p>
                  <button class="slide-banner-cta">{slide.cta} →</button>
                </div>
                <div class="slide-banner-visual">
                  <%= for e <- slide.emoji do %>
                    <span style="font-size:clamp(32px,6vw,72px);filter:drop-shadow(0 8px 16px rgba(0,0,0,0.3))">
                      {e}
                    </span>
                  <% end %>
                </div>
              </div>
              <div class="slide-products">
                <%= for prod <- slide.products do %>
                  <div
                    class="prod-chip"
                    phx-click="add_to_cart"
                    phx-value-product_id={prod.id}
                    phx-value-price={prod.price_raw}
                  >
                    <div class="prod-chip-img">
                      <%= if prod.badge do %>
                        <div class={"prod-chip-badge#{if prod.badge == "SALE", do: " sale"}"}>
                          {prod.badge}
                        </div>
                      <% end %>
                      {prod.emoji}
                      <button class="prod-chip-add">+</button>
                    </div>
                    <h4>{prod.name}</h4>
                    <div class="prod-chip-meta">
                      <div class="prod-chip-time">⚡ {prod.time}</div>
                      <div class="prod-chip-price">{prod.price}</div>
                    </div>
                  </div>
                <% end %>
                <div class="prod-chip-see-more"><span>→</span><span>See More</span></div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      <button class="carousel-btn carousel-btn-prev" phx-click="prev_slide">‹</button>
      <button class="carousel-btn carousel-btn-next" phx-click="next_slide">›</button>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Offers Strip
  # ---------------------------------------------------------------------------
  attr :flash_sale, :map, default: nil
  attr :flash_countdown, :string, default: nil
  attr :coupon_code, :string, default: ""
  attr :coupon_error, :string, default: nil
  attr :coupon_discount, :map, default: nil

  def offers_strip(assigns) do
    ~H"""
    <section class="section">
      <.section_head title="🎁 Offers &amp; Deals" />
      <div class="offers-strip">
        <div class="offer-card" phx-click="apply_coupon" phx-value-code="FIRST10">
          <div class="offer-icon" style="background:#e8f5e9">🆓</div>
          <div class="offer-body">
            <h4>Free delivery on first order</h4>
            <p>Use code <strong>FIRST10</strong> at checkout</p>
            <div class="offer-tag" style="background:#e8f5e9;color:var(--green)">AUTO APPLIED</div>
          </div>
        </div>
        <div class="offer-card" phx-click="apply_coupon" phx-value-code="DAIRY20">
          <div class="offer-icon" style="background:#fce4ec">💰</div>
          <div class="offer-body">
            <h4>20% off on Dairy products</h4>
            <p>Valid on orders above Rs. 200</p>
            <div class="offer-tag" style="background:#fce4ec;color:#e91e63">DAIRY20</div>
          </div>
        </div>
        <%= if @flash_sale do %>
          <div class="offer-card">
            <div class="offer-icon" style="background:#fff3e0">⚡</div>
            <div class="offer-body">
              <h4>Flash Sale — Snacks &amp; Drinks</h4>
              <p>Up to {@flash_sale.discount_pct}% off</p>
              <div class="offer-tag" style="background:#fff3e0;color:var(--accent)">
                {@flash_countdown} left
              </div>
            </div>
          </div>
        <% end %>
        <div class="offer-card">
          <div class="offer-icon" style="background:#ede7f6">🎯</div>
          <div class="offer-body">
            <h4>Buy 2 Get 1 Free — Fruits</h4>
            <p>Fresh seasonal fruits only</p>
            <div class="offer-tag" style="background:#ede7f6;color:#673ab7">B2G1</div>
          </div>
        </div>
      </div>
      <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:12px">
        <form phx-submit="apply_coupon" style="display:flex;gap:8px;align-items:center">
          <input
            type="text"
            name="code"
            placeholder="Enter coupon code"
            value={@coupon_code}
            style="height:36px;border:1.5px solid var(--border);border-radius:8px;padding:0 12px;font-size:13px;outline:none;width:200px"
          />
          <button type="submit" class="nav-btn nav-btn-primary" style="height:36px">Apply</button>
        </form>
        <%= if @coupon_error do %>
          <span style="font-size:12px;color:#e91e63;font-weight:600">✗ {@coupon_error}</span>
        <% end %>
        <%= if @coupon_discount do %>
          <span style="font-size:12px;color:var(--green);font-weight:600">
            ✓ {@coupon_discount.label} applied!
          </span>
        <% end %>
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # Category Row
  # ---------------------------------------------------------------------------
  attr :categories, :list, required: true

  def category_row(assigns) do
    ~H"""
    <section class="section">
      <.section_head title="🛍️ Shop by category" />
      <div class="cats-row">
        <%= for cat <- category_list(@categories) do %>
          <div class="cat-item">
            <div class="cat-icon">{cat.emoji}</div>
            <div class="cat-name">{cat.name}</div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # Product Card
  # ---------------------------------------------------------------------------
  attr :product, :map, required: true
  attr :cart_items, :map, default: %{}
  attr :show_badge, :boolean, default: true

  def product_card(assigns) do
    ~H"""
    <div class="prod-card" phx-click="show_product" phx-value-product_id={@product.id}>
      <div class="prod-card-img">
        <%= if @show_badge && @product.badge do %>
          <div class={"prod-card-badge #{@product.badge}"}>{@product.badge_label}</div>
        <% end %>
        {@product.emoji}
        <button
          class={"prod-card-add#{if Map.get(@cart_items, @product.id, %{qty: 0}).qty > 0, do: " added"}"}
          phx-click="add_to_cart"
          phx-value-product_id={@product.id}
          phx-value-price={@product.price_raw}
        >
          {if Map.get(@cart_items, @product.id, %{qty: 0}).qty > 0, do: "✓", else: "+"}
        </button>
      </div>
      <div class="prod-card-body">
        <div class="prod-card-name">{@product.name}</div>
        <div class="prod-card-info">
          <div class="prod-card-time">⚡ {@product.time}</div>
          <div class="prod-card-weight">{@product.weight}</div>
        </div>
        <div class="prod-card-price">
          <strong>{@product.price}</strong>
          <%= if @product.old_price do %>
            <del>{@product.old_price}</del>
            <span class="disc">{@product.discount_pct}% off</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Product Section (heading + grid)
  # ---------------------------------------------------------------------------
  attr :title, :string, required: true
  attr :products, :list, required: true
  attr :cart_items, :map, default: %{}

  def product_section(assigns) do
    ~H"""
    <section class="section">
      <.section_head title={@title} />
      <div class="products-row">
        <%= for p <- product_display_list(@products) do %>
          <.product_card product={p} cart_items={@cart_items} />
        <% end %>
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # App Download Banner
  # ---------------------------------------------------------------------------
  def app_banner(assigns) do
    ~H"""
    <div class="app-banner">
      <div class="app-banner-text">
        <h3>Get anything in <em style="color:#4ade80">10 minutes</em> 🚀</h3>
        <p>Download the app for <strong>exclusive deals</strong> and live rider tracking</p>
      </div>
      <div class="app-btns">
        <a href="#" class="app-btn">
          <span class="app-btn-icon">🍎</span>
          <div class="app-btn-text"><span>Download on the</span><span>App Store</span></div>
        </a>
        <a href="#" class="app-btn">
          <span class="app-btn-icon">▶</span>
          <div class="app-btn-text"><span>Get it on</span><span>Google Play</span></div>
        </a>
      </div>
      <div class="app-banner-emoji">📱🛵</div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # GPS JS Hook
  # ---------------------------------------------------------------------------
  def gps_js(assigns) do
    ~H"""
    <div id="gps-hook" phx-hook="GpsDetect" style="display:none"></div>
    <script>
      // Helper: push event to the LiveView that owns the element
      function pushToLV(eventName, payload) {
        // Find any live view element and push through its hook/channel
        const lvEl = document.querySelector("[data-phx-main]") ||
                     document.querySelector("[data-phx-session]");
        if (lvEl && window.liveSocket) {
          const view = window.liveSocket.getViewByEl(lvEl);
          if (view) { view.pushEvent(eventName, payload); return; }
        }
        // Fallback: dispatch a DOM event that Phoenix LiveView will pick up
        // via window phx event listeners
        window.dispatchEvent(new CustomEvent("phx:" + eventName, { detail: payload }));
      }

      window.addEventListener("phx:detect_gps", () => {
        if (!navigator.geolocation) {
          pushToLV("gps_denied", {});
          return;
        }
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            const { latitude: lat, longitude: lng } = pos.coords;
            fetch(
              `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`
            )
              .then(r => r.json())
              .then(data => {
                const a = data.address || {};
                // Build a readable Nepal-style label
                const parts = [
                  a.neighbourhood || a.suburb,
                  a.city_district,
                  a.city || a.town || a.village || a.county
                ].filter(Boolean);
                const label = parts.length ? parts.join(", ") : "";
                pushToLV("gps_location", { lat, lng, address: label });
              })
              .catch(() => pushToLV("gps_location", { lat, lng, address: "" }));
          },
          (_err) => pushToLV("gps_denied", {})
        );
      });

      // Register the hook so the element stays alive across LiveView patches
      window.GpsDetect = window.GpsDetect || {
        mounted() {},
        updated() {}
      };
    </script>
    """
  end
end
