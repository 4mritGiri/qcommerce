# lib/qcommerce_web/live/admin/dashboard_live.ex
defmodule QcommerceWeb.Admin.DashboardLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.{Repo, Admin.Registry}
  alias Qcommerce.Accounts.User
  alias Qcommerce.Orders.Order
  alias Qcommerce.Catalog.Product
  alias Qcommerce.Platform.Branch

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    user    = user_id && Repo.get(User, user_id)

    allowed_roles = [:super_admin, :manager, :staff]

    if is_nil(user) or user.role not in allowed_roles do
      {:ok, push_navigate(socket, to: "/")}
    else
      stats   = load_stats(user.role)
      charts  = load_chart_data(user.role)
      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> assign(:current_user, user)
       |> assign(:admin_section, :dashboard)
       |> assign(:breadcrumb, [{"Admin", "/admin"}])
       |> assign(:stats, stats)
       |> assign(:charts, charts)
       |> assign(:registry, Registry.all_for(user))}
    end
  end

  defp load_stats(:super_admin) do
    import Ecto.Query
    %{
      users:           Repo.aggregate(User, :count),
      products:        Repo.aggregate(Product, :count),
      branches:        Repo.aggregate(Branch, :count),
      orders:          Repo.aggregate(Order, :count),
      pending_orders:  Repo.aggregate(from(o in Order, where: o.status == :pending), :count),
      active_products: Repo.aggregate(from(p in Product, where: p.is_active == true), :count),
      today_orders:    Repo.aggregate(from(o in Order, where: o.inserted_at >= ^beginning_of_today()), :count),
    }
  end

  defp load_stats(:manager) do
    import Ecto.Query
    %{
      orders:          Repo.aggregate(Order, :count),
      pending_orders:  Repo.aggregate(from(o in Order, where: o.status == :pending), :count),
      today_orders:    Repo.aggregate(from(o in Order, where: o.inserted_at >= ^beginning_of_today()), :count),
      products:        Repo.aggregate(Product, :count),
      active_products: Repo.aggregate(from(p in Product, where: p.is_active == true), :count),
      branches:        Repo.aggregate(Branch, :count),
    }
  end

  defp load_stats(_role) do
    import Ecto.Query
    %{
      orders:         Repo.aggregate(Order, :count),
      pending_orders: Repo.aggregate(from(o in Order, where: o.status == :pending), :count),
      today_orders:   Repo.aggregate(from(o in Order, where: o.inserted_at >= ^beginning_of_today()), :count),
    }
  end

  defp load_chart_data(_role) do
    import Ecto.Query

    # Last 7 days order counts
    today = Date.utc_today()
    days = Enum.map(6..0//-1, fn i -> Date.add(today, -i) end)

    order_counts = Enum.map(days, fn day ->
      from_dt = DateTime.new!(day, ~T[00:00:00], "Etc/UTC")
      to_dt   = DateTime.new!(Date.add(day, 1), ~T[00:00:00], "Etc/UTC")
      Repo.aggregate(from(o in Order, where: o.inserted_at >= ^from_dt and o.inserted_at < ^to_dt), :count)
    end)

    labels = Enum.map(days, fn d ->
      "#{d.day}/#{d.month}"
    end)

    # Order status distribution
    statuses = [
      :pending,
      :confirmed,
      :picking,
      :ready,
      :out_for_delivery,
      :delivered,
      :cancelled,
      :rejected
    ]
    status_counts = Enum.map(statuses, fn s ->
      Repo.aggregate(from(o in Order, where: o.status == ^s), :count)
    end)

    %{
      orders_trend: %{
        type: "line",
        data: %{
          labels: labels,
          datasets: [%{
            label: "Orders",
            data: order_counts,
            borderColor: "rgba(99, 102, 241, 1)",
            backgroundColor: "rgba(99, 102, 241, 0.1)",
            fill: true,
            tension: 0.4,
            pointBackgroundColor: "rgba(99, 102, 241, 1)",
            pointRadius: 4
          }]
        }
      },
      order_status: %{
        type: "doughnut",
        legend: true,
        data: %{
          labels: Enum.map(statuses, &to_string/1),
          datasets: [%{
            data: status_counts,
            backgroundColor: [
              "rgba(245, 158, 11, 0.8)",  # pending
              "rgba(99, 102, 241, 0.8)",  # confirmed
              "rgba(168, 85, 247, 0.8)",  # picking
              "rgba(14, 165, 233, 0.8)",  # ready
              "rgba(59, 130, 246, 0.8)",  # out_for_delivery
              "rgba(16, 185, 129, 0.8)",  # delivered
              "rgba(239, 68, 68, 0.8)",   # cancelled
              "rgba(127, 29, 29, 0.8)"    # rejected
            ],
            borderColor: "rgba(15, 20, 40, 0.5)",
            borderWidth: 2
          }]
        }
      }
    }
  end

  defp beginning_of_today do
    Date.utc_today()
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  @impl true
  def render(assigns) do
    role = assigns.current_user.role
    assigns = assign(assigns, :role, role)

    ~H"""
    <!-- Role badge -->
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:24px;">
      <div>
        <h1 style="font-size:22px;font-weight:700;color:var(--adm-text1);margin:0;">
          <%= greeting_for(@role) %>
        </h1>
        <p style="color:var(--adm-text3);font-size:13px;margin:4px 0 0;">
          <%= role_subtitle(@role) %>
        </p>
      </div>
      <span style={role_badge_style(@role)}>
        <%= @role |> to_string() |> String.replace("_", " ") |> String.upcase() %>
      </span>
    </div>

    <!-- KPI Stat Cards -->
    <div class="adm-stats" style="margin-bottom:28px;">
      <%= for {_key, value, label, icon, trend} <- stat_cards(@stats, @role) do %>
        <div class="adm-stat" style="position:relative;overflow:hidden;">
          <div class="adm-stat-icon">
            <QcommerceWeb.Layouts.sidebar_icon icon={icon} class="w-8 h-8" />
          </div>
          <div class="adm-stat-num"><%= value %></div>
          <div class="adm-stat-label"><%= label %></div>
          <%= if trend do %>
            <div class="adm-stat-trend"><%= trend %></div>
          <% end %>
          <!-- decorative background icon -->
          <div style="position:absolute;right:-8px;bottom:-8px;opacity:0.04;pointer-events:none;">
            <QcommerceWeb.Layouts.sidebar_icon icon={icon} class="w-20 h-20" />
          </div>
        </div>
      <% end %>
    </div>

    <!-- Charts Row -->
    <div style="display:grid;grid-template-columns:1fr minmax(260px,320px);gap:20px;margin-bottom:28px;">
      <!-- Orders Trend -->
      <div class="adm-card">
        <div class="adm-card-header">
          <span class="adm-card-title" style="display:inline-flex;align-items:center;gap:6px;">
            <QcommerceWeb.Layouts.sidebar_icon icon="hero-arrow-trending-up" class="w-5 h-5" />
            Orders — Last 7 Days
          </span>
        </div>
        <div class="adm-card-body" style="height:220px;padding-top:8px;">
          <canvas id="chart-orders-trend"
                  phx-hook="AdminChart"
                  data-chart={Jason.encode!(@charts.orders_trend)}
                  style="width:100%;height:100%;" />
        </div>
      </div>

      <!-- Order Status Donut -->
      <div class="adm-card">
        <div class="adm-card-header">
          <span class="adm-card-title" style="display:inline-flex;align-items:center;gap:6px;">
            <QcommerceWeb.Layouts.sidebar_icon icon="hero-chart-pie" class="w-5 h-5" />
            Order Status
          </span>
        </div>
        <div class="adm-card-body" style="height:220px;display:flex;align-items:center;justify-content:center;">
          <canvas id="chart-order-status"
                  phx-hook="AdminChart"
                  data-chart={Jason.encode!(@charts.order_status)}
                  style="max-height:200px;" />
        </div>
      </div>
    </div>

    <!-- Super Admin only: Registered Models + Quick Actions -->
    <%= if @role == :super_admin do %>
      <div class="adm-card" style="margin-bottom:24px;">
        <div class="adm-card-header">
          <span class="adm-card-title" style="display:inline-flex;align-items:center;gap:6px;">
            <QcommerceWeb.Layouts.sidebar_icon icon="hero-squares-2x2" class="w-5 h-5" />
            Registered Models
          </span>
          <span style="font-size:11px;color:var(--adm-text2);"><%= length(@registry) %> models registered</span>
        </div>
        <div class="adm-card-body">
          <div class="adm-model-grid">
            <%= for entry <- @registry do %>
              <a href={"/admin/r/#{Qcommerce.Admin.Registry.schema_to_slug(entry.schema)}"} class="adm-model-card">
                <div class="adm-model-icon">
                  <QcommerceWeb.Layouts.sidebar_icon icon={entry.icon} class="w-8 h-8" />
                </div>
                <div class="adm-model-info">
                  <div class="adm-model-name"><%= entry.label %></div>
                  <div class="adm-model-group"><%= entry.group %></div>
                </div>
                <div class="adm-model-arrow">›</div>
              </a>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Quick Actions (role-aware) -->
    <div class="adm-card">
      <div class="adm-card-header">
        <span class="adm-card-title" style="display:inline-flex;align-items:center;gap:6px;">
          <QcommerceWeb.Layouts.sidebar_icon icon="hero-bolt" class="w-5 h-5" />
          Quick Actions
        </span>
      </div>
      <div class="adm-card-body" style="display:flex;gap:10px;flex-wrap:wrap;">
        <%= if @role in [:super_admin, :manager] do %>
          <a href="/admin/r/product/new" class="adm-btn adm-btn-primary">+ Add Product</a>
          <a href="/admin/r/category/new" class="adm-btn adm-btn-primary">+ Add Category</a>
          <a href="/admin/r/branch/new" class="adm-btn adm-btn-primary">+ Add Branch</a>
        <% end %>
        <a href="/admin/r/order" class="adm-btn adm-btn-ghost">View Orders</a>
        <%= if @role == :super_admin do %>
          <a href="/admin/r/user/new" class="adm-btn adm-btn-ghost">+ Add User</a>
          <a href="/admin/settings" class="adm-btn adm-btn-ghost" style="display:inline-flex;align-items:center;gap:4px;">
            <QcommerceWeb.Layouts.sidebar_icon icon="hero-cog-6-tooth" class="w-4 h-4" />
            Settings
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp greeting_for(:super_admin), do: "Super Admin Dashboard"
  defp greeting_for(:manager),     do: "Manager Dashboard"
  defp greeting_for(:staff),       do: "Staff Dashboard"
  defp greeting_for(_),            do: "Dashboard"

  defp role_subtitle(:super_admin), do: "Full system access — all models, settings, and users."
  defp role_subtitle(:manager),     do: "Operations view — orders, inventory, and catalog."
  defp role_subtitle(:staff),       do: "Daily view — order queue and fulfilment status."
  defp role_subtitle(_),            do: ""

  defp role_badge_style(:super_admin), do: "background:rgba(99,102,241,0.15);color:#818cf8;border:1px solid rgba(99,102,241,0.3);border-radius:20px;padding:4px 14px;font-size:11px;font-weight:600;letter-spacing:0.08em;"
  defp role_badge_style(:manager),     do: "background:rgba(16,185,129,0.12);color:#34d399;border:1px solid rgba(16,185,129,0.25);border-radius:20px;padding:4px 14px;font-size:11px;font-weight:600;letter-spacing:0.08em;"
  defp role_badge_style(_),            do: "background:rgba(245,158,11,0.12);color:#fbbf24;border:1px solid rgba(245,158,11,0.25);border-radius:20px;padding:4px 14px;font-size:11px;font-weight:600;letter-spacing:0.08em;"

  defp stat_cards(stats, :super_admin) do
    [
      {:users,    Map.get(stats, :users, 0),           "Total Users",     "hero-user",                ""},
      {:products, Map.get(stats, :products, 0),        "Products",        "product",                  "#{Map.get(stats, :active_products, 0)} active"},
      {:branches, Map.get(stats, :branches, 0),        "Branches",        "hero-building-storefront", ""},
      {:orders,   Map.get(stats, :orders, 0),          "Total Orders",    "hero-shopping-cart",       "#{Map.get(stats, :today_orders, 0)} today"},
      {:pending,  Map.get(stats, :pending_orders, 0),  "Pending Orders",  "hero-clock",               ""},
    ]
  end

  defp stat_cards(stats, :manager) do
    [
      {:orders,   Map.get(stats, :orders, 0),          "Total Orders",    "hero-shopping-cart",       "#{Map.get(stats, :today_orders, 0)} today"},
      {:pending,  Map.get(stats, :pending_orders, 0),  "Pending Orders",  "hero-clock",               ""},
      {:products, Map.get(stats, :products, 0),        "Products",        "product",                  "#{Map.get(stats, :active_products, 0)} active"},
      {:branches, Map.get(stats, :branches, 0),        "Branches",        "hero-building-storefront", ""},
    ]
  end

  defp stat_cards(stats, _staff) do
    [
      {:orders,   Map.get(stats, :orders, 0),          "Total Orders",    "hero-shopping-cart",       "#{Map.get(stats, :today_orders, 0)} today"},
      {:pending,  Map.get(stats, :pending_orders, 0),  "Pending Orders",  "hero-clock",               ""},
    ]
  end
end
