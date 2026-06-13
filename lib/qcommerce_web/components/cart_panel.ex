# lib/qcommerce_web/components/cart_panel.ex
defmodule QcommerceWeb.Components.CartPanel do
  use QcommerceWeb, :html

  # ---------------------------------------------------------------------------
  # Math helpers (public so home_live.html.heex can call them directly too)
  # ---------------------------------------------------------------------------

  @doc "Total Rs. saved across all discounted items in the cart."
  def savings_amount(cart_items) do
    Enum.reduce(cart_items, 0, fn {_pid, item}, acc ->
      saved = Map.get(item, :savings_per_unit, 0)
      acc + saved * item.qty
    end)
  end

  @doc "Formatted discount amount string (no Rs. prefix)."
  def discount_amount(cart_total, coupon_discount) do
    case coupon_discount do
      %{type: :percent, value: v} ->
        cart_total
        |> Decimal.mult(Decimal.div(Decimal.new(v), Decimal.new(100)))
        |> Decimal.round(0)
        |> Decimal.to_string()

      %{type: :fixed, value: v} ->
        min(v, Decimal.to_integer(Decimal.round(cart_total, 0)))
    end
  end

  @doc "Grand total after coupon, as formatted string (no Rs. prefix)."
  def grand_total(cart_total, nil) do
    cart_total |> Decimal.add(Decimal.new(2)) |> Decimal.round(0) |> Decimal.to_string()
  end

  def grand_total(cart_total, %{type: :percent, value: v}) do
    discount = Decimal.mult(cart_total, Decimal.div(Decimal.new(v), Decimal.new(100)))

    cart_total
    |> Decimal.sub(discount)
    |> Decimal.add(Decimal.new(2))
    |> Decimal.round(0)
    |> Decimal.to_string()
  end

  def grand_total(cart_total, %{type: :fixed, value: v}) do
    cart_total
    |> Decimal.sub(Decimal.new(v))
    |> Decimal.max(Decimal.new(0))
    |> Decimal.add(Decimal.new(2))
    |> Decimal.round(0)
    |> Decimal.to_string()
  end

  @doc "Formats share countdown seconds → \"MM:SS\" or \"HH:MM:SS\"."
  def format_share_countdown(secs) when secs <= 0, do: "Expired"

  def format_share_countdown(secs) do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    s = rem(secs, 60)

    if h > 0 do
      "#{pad2(h)}:#{pad2(m)}:#{pad2(s)}"
    else
      "#{pad2(m)}:#{pad2(s)}"
    end
  end

  defp pad2(n), do: String.pad_leading(to_string(n), 2, "0")

  # ---------------------------------------------------------------------------
  # Main component
  # ---------------------------------------------------------------------------

  attr :show_cart, :boolean, required: true
  attr :cart_items, :map, default: %{}
  attr :cart_count, :integer, default: 0
  # Decimal
  attr :cart_total, :any, required: true
  attr :coupon_code, :string, default: ""
  attr :coupon_error, :string, default: nil
  attr :coupon_discount, :map, default: nil
  attr :selected_location, :string, required: true
  attr :current_user, :map, default: nil
  attr :show_share_panel, :boolean, default: false
  attr :share_token, :string, default: nil
  attr :share_url, :string, default: nil
  attr :share_seconds_left, :integer, default: 0
  attr :show_share_qr, :boolean, default: false

  def cart_panel(assigns) do
    ~H"""
    <%= if @show_cart do %>
      <%!-- Backdrop --%>
      <div style="position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:400" phx-click="close_cart">
      </div>

      <%!-- Slide panel --%>
      <aside style="position:fixed;top:0;right:0;bottom:0;width:100%;max-width:400px;background:#fff;box-shadow:-4px 0 32px rgba(0,0,0,.15);display:flex;flex-direction:column;z-index:401;font-family:system-ui,sans-serif">
        <%!-- ── HEADER ── --%>
        <div style="display:flex;align-items:center;gap:8px;padding:14px 16px;border-bottom:1px solid #e5e7eb">
          <%= if @show_share_panel do %>
            <button
              phx-click="hide_share_panel"
              style="background:#f3f4f6;border:none;border-radius:8px;width:28px;height:28px;cursor:pointer;font-size:16px;display:flex;align-items:center;justify-content:center"
            >
              ←
            </button>
            <span style="font-size:15px;font-weight:700;color:#111827">Share cart</span>
            <span style="background:#dbeafe;color:#1e40af;border-radius:100px;padding:2px 8px;font-size:11px;font-weight:600;margin-left:4px">
              {@cart_count} items
            </span>
          <% else %>
            <span style="font-size:15px;font-weight:700;color:#111827">🛒 Your cart</span>
            <%= if @cart_count > 0 do %>
              <span style="background:#dcfce7;color:#166534;border-radius:100px;padding:2px 8px;font-size:11px;font-weight:600">
                {@cart_count} items
              </span>
            <% end %>
          <% end %>
          <button
            phx-click="close_cart"
            style="margin-left:auto;background:#f3f4f6;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;font-size:14px"
          >
            ✕
          </button>
        </div>

        <%!-- ── DELIVERY STRIP ── --%>
        <div style="display:flex;align-items:center;gap:6px;padding:7px 16px;background:#f0fdf4;border-bottom:1px solid #bbf7d0;font-size:12px;color:#166534">
          ⚡ <strong>10 min delivery</strong> &nbsp;·&nbsp; {@selected_location}
        </div>

        <%!-- ══ VIEW A — SHARE PANEL ══ --%>
        <%= if @show_share_panel do %>
          <.share_panel
            cart_items={@cart_items}
            share_url={@share_url}
            share_seconds_left={@share_seconds_left}
            show_share_qr={@show_share_qr}
            cart_count={@cart_count}
            cart_total={@cart_total}
          />

          <%!-- ══ VIEW B — CART ITEMS ══ --%>
        <% else %>
          <.cart_body
            cart_items={@cart_items}
            cart_count={@cart_count}
            cart_total={@cart_total}
            coupon_error={@coupon_error}
            coupon_discount={@coupon_discount}
            current_user={@current_user}
          />
        <% end %>
      </aside>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Share panel (View A)
  # ---------------------------------------------------------------------------

  attr :cart_items, :map, required: true
  attr :share_url, :string, default: nil
  attr :share_seconds_left, :integer, default: 0
  attr :show_share_qr, :boolean, default: false
  attr :cart_count, :integer, required: true
  attr :cart_total, :any, required: true

  defp share_panel(assigns) do
    assigns =
      assign(
        assigns,
        :share_message,
        "Hi, I have created a cart with #{assigns.cart_count} items worth Rs. #{assigns.cart_total} on `QCommerce`. Please review and make the payment to place the order. #{assigns.share_url}"
      )

    ~H"""
    <div style="flex:1;overflow-y:auto;padding:14px 16px">
      <%!-- Info notice --%>
      <div style="padding:8px 12px;background:#fef3c7;border:1px solid #fde68a;border-radius:8px;font-size:12px;color:#92400e;display:flex;gap:6px;margin-bottom:14px">
        <span>ℹ️</span>
        <span>
          Anyone with this link can view and add these items to their cart — no account needed.
        </span>
      </div>

      <%!-- Items preview --%>
      <div style="font-size:11px;font-weight:600;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px">
        Items in share
      </div>
      <%= for {_pid, item} <- @cart_items do %>
        <div style="display:flex;align-items:center;gap:10px;padding:8px 10px;background:#f9fafb;border-radius:8px;margin-bottom:6px;border:1px solid #e5e7eb">
          <div style="width:34px;height:34px;background:#fff;border-radius:6px;border:1px solid #e5e7eb;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0">
            {item.emoji}
          </div>
          <div style="flex:1;min-width:0">
            <div style="font-size:12px;font-weight:600;color:#111827;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
              {item.name}
            </div>
            <div style="font-size:11px;color:#6b7280">Rs. {Decimal.to_string(item.price)}</div>
          </div>
          <span style="background:#dcfce7;color:#166534;border-radius:100px;padding:2px 8px;font-size:11px;font-weight:600">
            ×{item.qty}
          </span>
        </div>
      <% end %>

      <%!-- Share channels --%>

      <div style="font-size:11px;font-weight:600;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin:14px 0 8px">
        Share via
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:14px">
        <a
          href={"https://wa.me/?text=#{URI.encode(@share_message)}"}
          target="_blank"
          style="padding:10px 8px;border:1.5px solid #e5e7eb;border-radius:8px;background:#f9fafb;font-size:12px;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:4px;color:#374151;text-decoration:none"
          onmouseover="this.style.borderColor='#16a34a';this.style.color='#16a34a'"
          onmouseout="this.style.borderColor='#e5e7eb';this.style.color='#374151'"
        >
          <span style="font-size:20px">💬</span>WhatsApp
        </a>
        <a
          href={"sms:?body=#{URI.encode(@share_message)}"}
          style="padding:10px 8px;border:1.5px solid #e5e7eb;border-radius:8px;background:#f9fafb;font-size:12px;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:4px;color:#374151;text-decoration:none"
          onmouseover="this.style.borderColor='#16a34a';this.style.color='#16a34a'"
          onmouseout="this.style.borderColor='#e5e7eb';this.style.color='#374151'"
        >
          <span style="font-size:20px">📱</span>SMS
        </a>
        <a
          href={"mailto:?subject=My QCommerce cart&body=#{URI.encode(@share_message)}"}
          style="padding:10px 8px;border:1.5px solid #e5e7eb;border-radius:8px;background:#f9fafb;font-size:12px;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:4px;color:#374151;text-decoration:none"
          onmouseover="this.style.borderColor='#16a34a';this.style.color='#16a34a'"
          onmouseout="this.style.borderColor='#e5e7eb';this.style.color='#374151'"
        >
          <span style="font-size:20px">📧</span>Email
        </a>
        <button
          phx-click="show_share_qr"
          style="padding:10px 8px;border:1.5px solid #e5e7eb;border-radius:8px;background:#f9fafb;font-size:12px;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:4px;color:#374151"
          onmouseover="this.style.borderColor='#16a34a';this.style.color='#16a34a'"
          onmouseout="this.style.borderColor='#e5e7eb';this.style.color='#374151'"
        >
          <span style="font-size:20px">📷</span>QR Code
        </button>
      </div>

      <%!-- Copy link --%>
      <div style="font-size:11px;font-weight:600;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px">
        Or copy link
      </div>
      <div style="display:flex;gap:6px;align-items:center;padding:8px 10px;background:#f9fafb;border-radius:8px;border:1.5px solid #e5e7eb">
        <input
          id="share-url-input"
          value={@share_url}
          readonly
          style="flex:1;border:none;background:transparent;font-size:11px;color:#6b7280;outline:none;font-family:monospace"
        />
        <button
          phx-click="copy_share_url"
          onclick={"navigator.clipboard.writeText('#{@share_url}').then(()=>{this.textContent='Copied!';setTimeout(()=>this.textContent='Copy',1500)})"}
          style="border:none;background:#16a34a;color:#fff;padding:4px 10px;border-radius:5px;font-size:11px;cursor:pointer;white-space:nowrap"
        >
          Copy
        </button>
      </div>

      <%!-- Expiry countdown --%>
      <div style="margin-top:12px;padding:10px 12px;background:#f9fafb;border-radius:8px;border:1px solid #e5e7eb">
        <div style="font-size:11px;color:#9ca3af;margin-bottom:4px">Link expires in</div>
        <div style={"font-size:20px;font-weight:800;#{if @share_seconds_left < 300, do: "color:#ef4444", else: "color:#111827"}"}>
          {format_share_countdown(@share_seconds_left)}
        </div>
        <div style="font-size:11px;color:#9ca3af;margin-top:2px">
          Recipients can add these items within this window
        </div>
      </div>

      <%!-- QR code (toggled) --%>
      <%= if @show_share_qr do %>
        <div style="margin-top:12px;text-align:center;padding:16px;background:#f9fafb;border-radius:12px;border:1px solid #e5e7eb">
          <div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:10px">
            Scan to open cart
          </div>
          <img
            src={"https://api.qrserver.com/v1/create-qr-code/?size=160&color=0c831f&data=#{URI.encode(@share_url)}"}
            style="border:3px solid #16a34a;border-radius:12px;padding:6px;display:block;margin:0 auto"
          />
          <div style="font-size:11px;color:#9ca3af;margin-top:8px">
            Works on any device — no app needed
          </div>
        </div>
      <% end %>
    </div>

    <div style="padding:14px 16px;border-top:1px solid #e5e7eb">
      <button
        phx-click="hide_share_panel"
        style="width:100%;padding:12px;background:#f9fafb;color:#374151;border:1.5px solid #e5e7eb;border-radius:12px;font-size:14px;font-weight:600;cursor:pointer"
      >
        ← Back to cart
      </button>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Cart items + bill (View B)
  # ---------------------------------------------------------------------------

  attr :cart_items, :map, required: true
  attr :cart_count, :integer, required: true
  attr :cart_total, :any, required: true
  attr :coupon_error, :string, default: nil
  attr :coupon_discount, :map, default: nil
  attr :current_user, :map, default: nil

  defp cart_body(assigns) do
    ~H"""
    <div style="flex:1;overflow-y:auto;padding:10px 16px">
      <%= if @cart_items == %{} do %>
        <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;gap:10px;color:#9ca3af;padding:40px 0">
          <span style="font-size:3.5rem;opacity:.4">🛒</span>
          <span style="font-size:14px;font-weight:500">Your cart is empty</span>
          <span style="font-size:12px">Add items to get started!</span>
        </div>
      <% else %>
        <%!-- Savings highlight --%>
        <%= if savings_amount(@cart_items) > 0 do %>
          <div style="display:flex;align-items:center;justify-content:space-between;padding:8px 12px;background:linear-gradient(90deg,#dcfce7,#fef9c3);border-radius:8px;font-size:12px;border:1px solid #bbf7d0;margin-bottom:8px">
            <span style="font-weight:600;color:#166534">
              🎉 You're saving Rs. {savings_amount(@cart_items)} on this order!
            </span>
          </div>
        <% end %>

        <%!-- Items --%>
        <%= for {pid, item} <- @cart_items do %>
          <div style="display:flex;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid #f3f4f6">
            <div style="width:40px;height:40px;background:#f9fafb;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:22px;flex-shrink:0">
              {item.emoji}
            </div>
            <div style="flex:1;min-width:0">
              <div style="font-size:13px;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#111827">
                {item.name}
              </div>
              <div style="font-size:11px;color:#9ca3af;margin-top:2px">
                Rs. {Decimal.to_string(item.price)} × {item.qty}
              </div>
            </div>
            <div style="display:flex;align-items:center;gap:5px">
              <button
                phx-click="decrement_cart"
                phx-value-product_id={pid}
                style="width:26px;height:26px;border-radius:6px;border:1.5px solid #e5e7eb;background:#f9fafb;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center"
                onmouseover="this.style.background='#16a34a';this.style.color='#fff'"
                onmouseout="this.style.background='#f9fafb';this.style.color='inherit'"
              >
                −
              </button>
              <span style="font-size:13px;font-weight:700;min-width:18px;text-align:center;color:#111827">
                {item.qty}
              </span>
              <button
                phx-click="add_to_cart"
                phx-value-product_id={pid}
                phx-value-price={item.price}
                style="width:26px;height:26px;border-radius:6px;border:1.5px solid #e5e7eb;background:#f9fafb;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center"
                onmouseover="this.style.background='#16a34a';this.style.color='#fff'"
                onmouseout="this.style.background='#f9fafb';this.style.color='inherit'"
              >
                +
              </button>
            </div>
            <button
              phx-click="remove_cart_item"
              phx-value-product_id={pid}
              style="background:none;border:none;color:#d1d5db;font-size:14px;cursor:pointer;padding:4px;border-radius:4px"
              onmouseover="this.style.color='#ef4444';this.style.background='#fee2e2'"
              onmouseout="this.style.color='#d1d5db';this.style.background='none'"
            >
              🗑
            </button>
          </div>
        <% end %>

        <%!-- Coupon --%>
        <form phx-submit="apply_coupon" style="display:flex;gap:8px;margin:12px 0">
          <input
            type="text"
            name="code"
            placeholder="Coupon code"
            style="flex:1;padding:8px 12px;border:1.5px solid #e5e7eb;border-radius:8px;font-size:13px;text-transform:uppercase;letter-spacing:.5px;outline:none"
          />
          <button
            type="submit"
            style="padding:8px 14px;background:#16a34a;color:#fff;border:none;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer"
          >
            Apply
          </button>
        </form>
        <%= if @coupon_error do %>
          <div style="font-size:11px;color:#ef4444;background:#fee2e2;padding:6px 10px;border-radius:6px;margin-bottom:8px">
            {@coupon_error}
          </div>
        <% end %>
        <%= if @coupon_discount do %>
          <div style="font-size:11px;color:#166534;background:#dcfce7;padding:6px 10px;border-radius:6px;margin-bottom:8px">
            🎉 {@coupon_discount.label}
          </div>
        <% end %>

        <%!-- Bill summary --%>
        <div style="border-top:1px solid #e5e7eb;padding:10px 0">
          <div style="display:flex;justify-content:space-between;font-size:12px;color:#6b7280;padding:3px 0">
            <span>Subtotal ({@cart_count} items)</span>
            <span>Rs. {Decimal.to_string(Decimal.round(@cart_total, 0))}</span>
          </div>
          <div style="display:flex;justify-content:space-between;font-size:12px;color:#6b7280;padding:3px 0">
            <span>Delivery fee</span>
            <span style="color:#16a34a;font-weight:600">FREE</span>
          </div>
          <div style="display:flex;justify-content:space-between;font-size:12px;color:#6b7280;padding:3px 0">
            <span>Handling</span>
            <span>Rs. 2</span>
          </div>
          <%= if @coupon_discount do %>
            <div style="display:flex;justify-content:space-between;font-size:12px;padding:3px 0">
              <span style="color:#6b7280">Discount</span>
              <span style="color:#16a34a;font-weight:600">
                −Rs. {discount_amount(@cart_total, @coupon_discount)}
              </span>
            </div>
          <% end %>
          <div style="display:flex;justify-content:space-between;font-size:14px;font-weight:700;color:#111827;padding:8px 0 4px;border-top:1.5px dashed #e5e7eb;margin-top:6px">
            <span>Grand total</span>
            <span>Rs. {grand_total(@cart_total, @coupon_discount)}</span>
          </div>
        </div>

        <button
          phx-click="clear_cart"
          style="background:none;border:none;color:#9ca3af;font-size:11px;cursor:pointer;text-decoration:underline;margin-top:4px"
        >
          Clear cart
        </button>
      <% end %>
    </div>

    <%!-- Footer --%>
    <%= if @cart_count > 0 do %>
      <div style="padding:14px 16px;border-top:1px solid #e5e7eb">
        <%= if @current_user do %>
          <button
            phx-click="proceed_checkout"
            style="width:100%;padding:13px;background:#16a34a;color:#fff;border:none;border-radius:12px;font-size:14px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:space-between;margin-bottom:8px"
          >
            <span>Proceed to checkout →</span>
            <span style="opacity:.85;font-size:13px">
              Rs. {grand_total(@cart_total, @coupon_discount)}
            </span>
          </button>
        <% else %>
          <button
            phx-click="show_login"
            style="width:100%;padding:13px;background:#16a34a;color:#fff;border:none;border-radius:12px;font-size:14px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:space-between;margin-bottom:8px"
          >
            <span>Login to checkout →</span>
            <span style="opacity:.85;font-size:13px">
              Rs. {grand_total(@cart_total, @coupon_discount)}
            </span>
          </button>
        <% end %>

        <%!-- Secondary actions --%>
        <div style="display:flex;gap:6px">
          <button
            phx-click="share_cart"
            style="flex:1;padding:9px 8px;border:1.5px solid #e5e7eb;border-radius:10px;background:#f9fafb;font-size:12px;font-weight:600;cursor:pointer;color:#374151;display:flex;align-items:center;justify-content:center;gap:5px"
            onmouseover="this.style.borderColor='#16a34a';this.style.color='#16a34a'"
            onmouseout="this.style.borderColor='#e5e7eb';this.style.color='#374151'"
          >
            🔗 Share cart
          </button>
          <button
            style="flex:1;padding:9px 8px;border:1.5px solid #e5e7eb;border-radius:10px;background:#f9fafb;font-size:12px;font-weight:600;cursor:pointer;color:#374151;display:flex;align-items:center;justify-content:center;gap:5px"
            onmouseover="this.style.borderColor='#16a34a';this.style.color='#16a34a'"
            onmouseout="this.style.borderColor='#e5e7eb';this.style.color='#374151'"
          >
            🎁 Send as gift
          </button>
        </div>
      </div>
    <% end %>
    """
  end
end
