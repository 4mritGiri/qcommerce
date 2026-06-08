defmodule QcommerceWeb.CartComponents do
  use QcommerceWeb, :html

  # ---------------------------------------------------------------------------
  # Full Cart Slide Panel
  # ---------------------------------------------------------------------------
  attr :show_cart,        :boolean, required: true
  attr :cart_items,       :map,     default: %{}
  attr :cart_count,       :integer, default: 0
  attr :cart_total,       :any,     required: true   # Decimal
  attr :selected_location, :string, required: true
  attr :coupon_discount,  :map,     default: nil
  attr :coupon_error,     :string,  default: nil
  attr :current_user,     :map,     default: nil

  def slide_panel(assigns) do
    ~H"""
    <%= if @show_cart do %>
      <div style="position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:400" phx-click="close_cart"></div>
      <aside style="position:fixed;top:0;right:0;bottom:0;width:100%;max-width:390px;background:#fff;box-shadow:-4px 0 32px rgba(0,0,0,.15);display:flex;flex-direction:column;z-index:401">

        <%!-- Header --%>
        <div style="display:flex;align-items:center;gap:10px;padding:14px 18px;border-bottom:1px solid #e5e7eb">
          <span style="font-family:var(--font-head);font-size:15px;font-weight:700">🛒 Your Cart</span>
          <%= if @cart_count > 0 do %>
            <span style="background:#e6f9ee;color:#148f44;border-radius:100px;padding:2px 8px;font-size:11px;font-weight:700">
              <%= @cart_count %> items
            </span>
          <% end %>
          <button phx-click="close_cart"
            style="margin-left:auto;background:#f3f4f6;border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;font-size:14px">✕</button>
        </div>

        <%!-- Delivery tag --%>
        <div style="display:flex;align-items:center;gap:6px;padding:8px 18px;background:#f0fdf4;border-bottom:1px solid #d1fae5;font-size:12px;color:#166534">
          ⚡ <strong>10 min delivery</strong> &nbsp;·&nbsp; <%= @selected_location %>
        </div>

        <%!-- Body --%>
        <div style="flex:1;overflow-y:auto;padding:10px 18px">
          <%= if @cart_items == %{} do %>
            <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;gap:10px;color:#9ca3af;padding:40px 0">
              <span style="font-size:3.5rem;opacity:.4">🛒</span>
              <span style="font-size:14px;font-weight:500">Your cart is empty</span>
              <span style="font-size:12px">Add items to get started!</span>
            </div>
          <% else %>
            <%!-- Items --%>
            <%= for {pid, item} <- @cart_items do %>
              <.cart_item pid={pid} item={item} />
            <% end %>

            <%!-- Coupon --%>
            <.coupon_input coupon_error={@coupon_error} coupon_discount={@coupon_discount} />

            <%!-- Bill Summary --%>
            <.bill_summary
              cart_count={@cart_count}
              cart_total={@cart_total}
              coupon_discount={@coupon_discount} />

            <button phx-click="clear_cart"
              style="background:none;border:none;color:#9ca3af;font-size:11px;cursor:pointer;text-decoration:underline;margin-top:4px">
              Clear cart
            </button>
          <% end %>
        </div>

        <%!-- Footer checkout button --%>
        <%= if @cart_count > 0 do %>
          <.checkout_button current_user={@current_user} cart_total={@cart_total} />
        <% end %>
      </aside>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Single Cart Item Row
  # ---------------------------------------------------------------------------
  attr :pid,  :string, required: true
  attr :item, :map,    required: true

  def cart_item(assigns) do
    ~H"""
    <div style="display:flex;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid #f3f4f6">
      <span style="font-size:1.6rem;width:2.2rem;text-align:center"><%= @item.emoji %></span>
      <div style="flex:1;min-width:0">
        <div style="font-size:13px;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
          <%= @item.name %>
        </div>
        <div style="font-size:11px;color:#9ca3af;margin-top:2px">
          Rs. <%= Decimal.to_string(@item.price) %> × <%= @item.qty %>
        </div>
      </div>
      <div style="display:flex;align-items:center;gap:6px">
        <button phx-click="decrement_cart" phx-value-product_id={@pid}
          style="width:26px;height:26px;border-radius:50%;border:1.5px solid #e5e7eb;background:#f9fafb;cursor:pointer;font-size:14px;font-weight:700;display:flex;align-items:center;justify-content:center">−</button>
        <span style="font-size:13px;font-weight:700;min-width:16px;text-align:center"><%= @item.qty %></span>
        <button phx-click="add_to_cart" phx-value-product_id={@pid} phx-value-price={@item.price}
          style="width:26px;height:26px;border-radius:50%;border:1.5px solid #e5e7eb;background:#f9fafb;cursor:pointer;font-size:14px;font-weight:700;display:flex;align-items:center;justify-content:center">+</button>
      </div>
      <button phx-click="remove_cart_item" phx-value-product_id={@pid}
        style="background:none;border:none;color:#9ca3af;font-size:13px;cursor:pointer;padding:4px">🗑</button>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Coupon Input (inside cart)
  # ---------------------------------------------------------------------------
  attr :coupon_error,    :string, default: nil
  attr :coupon_discount, :map,    default: nil

  def coupon_input(assigns) do
    ~H"""
    <form phx-submit="apply_coupon" style="display:flex;gap:8px;margin:12px 0">
      <input type="text" name="code" placeholder="COUPON CODE"
        style="flex:1;padding:8px 12px;border:1.5px solid #e5e7eb;border-radius:8px;font-size:13px;text-transform:uppercase;letter-spacing:.5px;outline:none" />
      <button type="submit"
        style="padding:8px 14px;background:var(--green);color:#fff;border:none;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer">Apply</button>
    </form>
    <%= if @coupon_error do %>
      <div style="font-size:11px;color:#ef4444;background:#fee2e2;padding:6px 10px;border-radius:6px;margin-bottom:8px">
        <%= @coupon_error %>
      </div>
    <% end %>
    <%= if @coupon_discount do %>
      <div style="font-size:11px;color:#166534;background:#d1fae5;padding:6px 10px;border-radius:6px;margin-bottom:8px">
        🎉 <%= @coupon_discount.label %>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Bill Summary
  # ---------------------------------------------------------------------------
  attr :cart_count,      :integer, required: true
  attr :cart_total,      :any,     required: true  # Decimal
  attr :coupon_discount, :map,     default: nil

  def bill_summary(assigns) do
    ~H"""
    <div style="border-top:1px solid #e5e7eb;padding:10px 0">
      <div style="display:flex;justify-content:space-between;font-size:12px;color:#6b7280;padding:3px 0">
        <span>Subtotal (<%= @cart_count %> items)</span>
        <span>Rs. <%= Decimal.to_string(Decimal.round(@cart_total, 0)) %></span>
      </div>
      <div style="display:flex;justify-content:space-between;font-size:12px;color:#6b7280;padding:3px 0">
        <span>Delivery fee</span>
        <span style="color:#1aad54;font-weight:600">FREE</span>
      </div>
      <%= if @coupon_discount do %>
        <div style="display:flex;justify-content:space-between;font-size:12px;padding:3px 0">
          <span style="color:#6b7280">Discount</span>
          <span style="color:#1aad54;font-weight:600">
            −Rs. <%= case @coupon_discount do
              %{type: :percent, value: v} ->
                Decimal.to_string(Decimal.round(Decimal.mult(@cart_total, Decimal.div(Decimal.new(v), Decimal.new(100))), 0))
              %{type: :fixed, value: v} ->
                min(v, Decimal.to_integer(Decimal.round(@cart_total, 0)))
            end %>
          </span>
        </div>
      <% end %>
      <div style="display:flex;justify-content:space-between;font-size:14px;font-weight:700;color:#111827;padding:8px 0 4px;border-top:1.5px dashed #e5e7eb;margin-top:6px">
        <span>Total</span>
        <span>Rs. <%= cond do
          @coupon_discount != nil ->
            case @coupon_discount do
              %{type: :percent, value: v} ->
                Decimal.to_string(Decimal.round(Decimal.sub(@cart_total, Decimal.mult(@cart_total, Decimal.div(Decimal.new(v), Decimal.new(100)))), 0))
              %{type: :fixed, value: v} ->
                Decimal.to_string(Decimal.round(Decimal.max(Decimal.sub(@cart_total, Decimal.new(v)), Decimal.new(0)), 0))
            end
          true -> Decimal.to_string(Decimal.round(@cart_total, 0))
        end %></span>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Checkout Button
  # ---------------------------------------------------------------------------
  attr :current_user, :map, default: nil
  attr :cart_total,   :any, required: true

  defp checkout_button(assigns) do
    ~H"""
    <div style="padding:14px 18px;border-top:1px solid #e5e7eb">
      <%= if @current_user do %>
        <button phx-click="close_cart"
          style="width:100%;padding:13px;background:var(--green);color:#fff;border:none;border-radius:12px;font-size:14px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:space-between">
          <span>Proceed to Checkout →</span>
          <span style="opacity:.85;font-size:13px">Rs. <%= Decimal.to_string(Decimal.round(@cart_total, 0)) %></span>
        </button>
      <% else %>
        <button phx-click="show_login"
          style="width:100%;padding:13px;background:var(--green);color:#fff;border:none;border-radius:12px;font-size:14px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:space-between">
          <span>Login to Checkout →</span>
          <span style="opacity:.85;font-size:13px">Rs. <%= Decimal.to_string(Decimal.round(@cart_total, 0)) %></span>
        </button>
      <% end %>
    </div>
    """
  end
end
