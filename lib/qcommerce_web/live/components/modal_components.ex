defmodule QcommerceWeb.Live.Components.ModalComponents do
  use QcommerceWeb, :html

  # ---------------------------------------------------------------------------
  # Product Detail Modal
  # ---------------------------------------------------------------------------
  attr :show_modal,        :boolean, default: false
  attr :selected_product,  :map,     default: nil

  def product_modal(assigns) do
    ~H"""
    <%= if @show_modal && @selected_product do %>
      <div style="position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:400;display:flex;align-items:flex-end;justify-content:center"
           phx-click="close_modal">
        <div style="background:#fff;border-radius:20px 20px 0 0;width:100%;max-width:480px;padding:28px 24px 36px;position:relative">
          <button phx-click="close_modal"
            style="position:absolute;top:16px;right:16px;width:32px;height:32px;border-radius:8px;border:1.5px solid var(--border);background:none;cursor:pointer;font-size:16px;display:flex;align-items:center;justify-content:center">✕</button>

          <div style="font-size:72px;text-align:center;margin-bottom:12px"><%= @selected_product.emoji %></div>
          <h3 style="font-family:var(--font-head);font-size:20px;font-weight:800;color:var(--text);margin-bottom:8px">
            <%= @selected_product.name %>
          </h3>
          <p style="font-size:13px;color:var(--text2);line-height:1.5;margin-bottom:12px">
            <%= @selected_product.description || "Fresh and quality assured. Delivered in 10 minutes." %>
          </p>

          <div style="display:flex;gap:10px;margin-bottom:20px">
            <span style="font-size:11px;background:var(--green-light);color:var(--green);padding:4px 10px;border-radius:6px;font-weight:600">⚡ 10 min delivery</span>
            <span style="font-size:11px;background:#f0f0f8;color:var(--text2);padding:4px 10px;border-radius:6px;font-weight:600"><%= @selected_product.unit %></span>
          </div>

          <div style="display:flex;align-items:center;justify-content:space-between">
            <div>
              <%= if @selected_product.old_price do %>
                <del style="font-size:13px;color:var(--text3)">
                  <%= Qcommerce.Catalog.Product.format_price(@selected_product.old_price) %>
                </del>
              <% end %>
              <div style="font-size:22px;font-weight:800;color:var(--text)">
                <%= Qcommerce.Catalog.Product.format_price(@selected_product.base_price) %>
              </div>
            </div>
            <button class="nav-btn nav-btn-primary" style="height:44px;font-size:14px;padding:0 24px"
              phx-click="add_to_cart"
              phx-value-product_id={@selected_product.id}
              phx-value-price={@selected_product.base_price}>
              + Add to cart
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Login Modal (all tabs combined)
  # ---------------------------------------------------------------------------
  attr :show_login_modal, :boolean, default: false
  attr :auth_methods,     :map,     required: true
  attr :login_tab,        :atom,    default: :email
  attr :login_phone_step, :integer, default: 1
  attr :phone_input,      :string,  default: ""
  attr :otp_error,        :string,  default: nil
  attr :qr_countdown,     :integer, default: 30
  attr :passkey_state, :atom, default: :idle
  attr :current_user,     :map,     default: nil

  def login_modal(assigns) do
    ~H"""
    <%= if @show_login_modal do %>
      <div style="position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:400" phx-click="close_login"></div>
      <div style="position:fixed;z-index:401;top:50%;left:50%;transform:translate(-50%,-50%);width:calc(100% - 32px);max-width:400px;background:#fff;border-radius:20px;padding:28px 24px;box-shadow:0 10px 40px rgba(0,0,0,0.15)">
        <button phx-click="close_login"
          style="position:absolute;top:16px;right:16px;width:32px;height:32px;border-radius:8px;border:1.5px solid var(--border);background:none;cursor:pointer;font-size:16px;display:flex;align-items:center;justify-content:center">✕</button>

        <.auth_tab_bar auth_methods={@auth_methods} login_tab={@login_tab} />

        <%= if @login_tab == :qr,      do: qr_tab(assigns) %>
        <%= if @login_tab == :phone,   do: phone_tab(assigns) %>
        <%= if @login_tab == :email,   do: email_tab(assigns) %>
        <%= if @login_tab == :passkey, do: passkey_tab(%{assigns | passkey_state: @passkey_state}) %>

        <div style="text-align:center;margin-top:16px;font-size:13px;color:var(--text2);border-top:1.5px solid var(--border);padding-top:14px;display:flex;flex-direction:column;gap:6px">
          <span>No account? <a href="#" phx-click="show_signup" style="color:var(--green);font-weight:600;text-decoration:none">Sign up</a></span>
          <a href="#" phx-click="close_login" style="color:var(--text3);font-size:12px;text-decoration:none">Continue as Guest →</a>
        </div>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Auth Tab Bar
  # ---------------------------------------------------------------------------
  attr :auth_methods, :map,  required: true
  attr :login_tab,    :atom, default: :email

  def auth_tab_bar(assigns) do
    ~H"""
    <div style="display:flex;background:#f3f4f6;border-radius:10px;padding:3px;margin-bottom:24px;gap:2px">
      <%= if @auth_methods.qr do %>
        <.tab_btn tab={:qr} current={@login_tab} label="QR" />
      <% end %>
      <%= if @auth_methods.phone do %>
        <.tab_btn tab={:phone} current={@login_tab} label="Phone" />
      <% end %>
      <%= if @auth_methods.email do %>
        <.tab_btn tab={:email} current={@login_tab} label="Email" />
      <% end %>
      <%= if @auth_methods.passkey do %>
        <.tab_btn tab={:passkey} current={@login_tab} label="Passkey" />
      <% end %>
    </div>
    """
  end

  defp tab_btn(assigns) do
    ~H"""
    <button phx-click="select_login_tab" phx-value-tab={@tab}
      style={"flex:1;height:32px;font-size:12px;font-weight:600;border:none;border-radius:8px;cursor:pointer;transition:all .15s;background:#{if @current == @tab, do: "#fff", else: "transparent"};color:#{if @current == @tab, do: "var(--text)", else: "var(--text3)"}"}>
      <%= @label %>
    </button>
    """
  end

  defp qr_tab(assigns) do
    ~H"""
    <div style="text-align:center">
      <h3 style="font-family:var(--font-head);font-size:20px;font-weight:800;margin-bottom:4px">Welcome Back</h3>
      <p style="font-size:13px;color:var(--text3);margin-bottom:20px">Scan to login with QCommerce app</p>
      <img src={"https://api.qrserver.com/v1/create-qr-code/?size=160&color=0c831f&data=qcommerce_login_#{@qr_countdown}"}
           style="display:block;margin:0 auto 16px;border:3px solid var(--green);border-radius:12px;padding:6px" />
      <div style="font-size:13px;font-weight:700;color:var(--text2);margin-bottom:20px">
        Expires in <span style="color:var(--accent)">00:<%= String.pad_leading(to_string(@qr_countdown), 2, "0") %></span>
      </div>
      <button phx-click="simulate_qr_login" class="nav-btn nav-btn-primary" style="width:100%;height:44px;justify-content:center">
        Simulate QR Login
      </button>
    </div>
    """
  end

  defp phone_tab(assigns) do
    ~H"""
    <h3 style="font-family:var(--font-head);font-size:20px;font-weight:800;text-align:center;margin-bottom:20px">Login with Phone</h3>
    <%= if @login_phone_step == 1 do %>
      <form phx-submit="submit_phone" style="display:flex;flex-direction:column;gap:16px">
        <div>
          <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:6px">Mobile Number</label>
          <input type="tel" name="phone" required placeholder="+9779876543210" value={@phone_input}
            style="width:100%;height:44px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
        </div>
        <button type="submit" class="nav-btn nav-btn-primary" style="width:100%;height:44px;justify-content:center">Continue</button>
      </form>
    <% else %>
      <form phx-submit="submit_otp" style="display:flex;flex-direction:column;gap:16px">
        <div>
          <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:4px">OTP Code</label>
          <p style="font-size:11px;color:var(--text3);margin-bottom:8px">Code sent to <%= @phone_input %> — use <strong>123456</strong></p>
          <input type="text" name="otp" required placeholder="••••••" maxlength="6"
            style="width:100%;height:44px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:18px;text-align:center;letter-spacing:6px;outline:none" />
          <%= if @otp_error do %>
            <span style="color:var(--accent);font-size:12px;margin-top:4px;display:block"><%= @otp_error %></span>
          <% end %>
        </div>
        <button type="submit" class="nav-btn nav-btn-primary" style="width:100%;height:44px;justify-content:center">
          Verify &amp; Login
        </button>
      </form>
    <% end %>
    """
  end

  defp email_tab(assigns) do
    ~H"""
    <h3 style="font-family:var(--font-head);font-size:20px;font-weight:800;text-align:center;margin-bottom:20px">Email Sign In</h3>
    <form action={~p"/session/login"} method="post" style="display:flex;flex-direction:column;gap:16px">
      <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
      <div>
        <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:6px">Email address</label>
        <input type="email" name="email" required placeholder="name@domain.com"
          style="width:100%;height:44px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
      </div>
      <div>
        <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:6px">Password</label>
        <input type="password" name="password" required placeholder="••••••••"
          style="width:100%;height:44px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
      </div>
      <button type="submit" class="nav-btn nav-btn-primary" style="height:44px;width:100%;justify-content:center">Login</button>
    </form>
    """
  end

  defp passkey_tab(assigns) do
    ~H"""
      <%= if @login_tab == :passkey do %>
        <div style="text-align:center;padding:4px 0">
          <div style="font-size:44px;margin-bottom:8px">🔑</div>
          <h3 style="font-family:var(--font-head);font-size:18px;font-weight:800;margin-bottom:6px">Passkey Login</h3>
          <p style="font-size:12px;color:var(--text3);line-height:1.5;margin-bottom:16px">
            Use your device fingerprint, Face ID, or PIN — no password needed.
          </p>

          <%!-- State: idle — show the authenticate button --%>
          <%= if @passkey_state == :idle do %>
            <button phx-click="start_passkey_login"
              style="width:100%;height:44px;background:#111827;color:#fff;border:none;border-radius:10px;font-size:14px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:10px">
              🛡️ Login with Passkey
            </button>
          <% end %>

          <%!-- State: waiting — spinner --%>
          <%= if @passkey_state == :waiting do %>
            <div style="width:100%;height:44px;background:#f3f4f6;border-radius:10px;display:flex;align-items:center;justify-content:center;gap:10px;font-size:13px;color:var(--text2);margin-bottom:10px">
              <span style="animation:spin 1s linear infinite;display:inline-block">⏳</span>
              Waiting for your device…
            </div>
          <% end %>

          <%!-- State: error --%>
          <%= if @passkey_state == :error do %>
            <div style="padding:10px 12px;background:#fee2e2;border-radius:8px;font-size:12px;color:#991b1b;margin-bottom:10px;text-align:left">
              ⚠️ <%= @passkey_error %>
            </div>
            <button phx-click="start_passkey_login"
              style="width:100%;height:40px;background:#111827;color:#fff;border:none;border-radius:10px;font-size:13px;font-weight:700;cursor:pointer;margin-bottom:10px">
              Try again →
            </button>
          <% end %>

          <%!-- Divider --%>
          <div style="display:flex;align-items:center;gap:8px;margin:10px 0">
            <div style="flex:1;height:1px;background:#e5e7eb"></div>
            <span style="font-size:11px;color:#9ca3af">dev / demo only</span>
            <div style="flex:1;height:1px;background:#e5e7eb"></div>
          </div>

          <%!-- Simulate passkey (dev mode — shows only when real passkey not supported) --%>
          <button phx-click="simulate_passkey_login"
            style="width:100%;height:36px;background:transparent;color:#9ca3af;border:1.5px dashed #e5e7eb;border-radius:8px;font-size:12px;cursor:pointer">
            Simulate passkey login (dev)
          </button>

          <%!-- Register passkey (for already-logged-in users) --%>
          <%= if @current_user do %>
            <div style="margin-top:12px;padding:10px 12px;background:#f0fdf4;border-radius:8px;font-size:12px;color:#166534;text-align:left">
              Want to add a passkey to your account?
              <button phx-click="start_passkey_register"
                style="background:none;border:none;color:#16a34a;font-weight:700;cursor:pointer;text-decoration:underline;font-size:12px">
                Register now
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
      """
  end

  # ---------------------------------------------------------------------------
  # Signup Modal
  # ---------------------------------------------------------------------------
  attr :show_signup_modal, :boolean, default: false

  def signup_modal(assigns) do
    ~H"""
    <%= if @show_signup_modal do %>
      <div style="position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:400" phx-click="close_signup"></div>
      <div style="position:fixed;z-index:401;top:50%;left:50%;transform:translate(-50%,-50%);width:calc(100% - 32px);max-width:400px;background:#fff;border-radius:20px;padding:32px 24px;box-shadow:0 10px 40px rgba(0,0,0,0.15);max-height:90vh;overflow-y:auto">
        <button phx-click="close_signup"
          style="position:absolute;top:16px;right:16px;width:32px;height:32px;border-radius:8px;border:1.5px solid var(--border);background:none;cursor:pointer;font-size:16px;display:flex;align-items:center;justify-content:center">✕</button>

        <div style="text-align:center;margin-bottom:24px">
          <div style="width:50px;height:50px;background:var(--green);border-radius:12px;color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:24px;font-weight:800;margin-bottom:8px">Q</div>
          <h3 style="font-family:var(--font-head);font-size:22px;font-weight:800">Create Account</h3>
          <p style="font-size:13px;color:var(--text3);margin-top:2px">Get started with 10 minute delivery</p>
        </div>

        <form action={~p"/session/signup"} method="post" style="display:flex;flex-direction:column;gap:14px">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <div>
            <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:4px">Full Name</label>
            <input type="text" name="user[full_name]" required placeholder="John Doe"
              style="width:100%;height:40px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
          </div>
          <div>
            <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:4px">Email address</label>
            <input type="email" name="user[email]" required placeholder="name@domain.com"
              style="width:100%;height:40px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
          </div>
          <div>
            <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:4px">Phone Number</label>
            <input type="tel" name="user[phone]" required placeholder="+97798XXXXXXXX"
              style="width:100%;height:40px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
          </div>
          <div>
            <label style="display:block;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:4px">Password (min 8 chars)</label>
            <input type="password" name="user[password]" required placeholder="••••••••" minlength="8"
              style="width:100%;height:40px;border:1.5px solid var(--border);border-radius:10px;padding:0 14px;font-size:14px;outline:none" />
          </div>
          <button type="submit" class="nav-btn nav-btn-primary" style="height:44px;width:100%;justify-content:center;font-size:14px;margin-top:8px">
            Sign up
          </button>
        </form>

        <div style="text-align:center;margin-top:20px;font-size:13px;color:var(--text2)">
          Already have an account?
          <a href="#" phx-click="show_login" style="color:var(--green);font-weight:600;text-decoration:none;margin-left:4px">Login</a>
        </div>
      </div>
    <% end %>
    """
  end
end
