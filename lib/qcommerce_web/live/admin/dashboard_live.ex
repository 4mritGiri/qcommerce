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

    if is_nil(user) or user.role != :super_admin do
      {:ok, push_navigate(socket, to: "/")}
    else
      stats = load_stats()
      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> assign(:current_user, user)
       |> assign(:admin_section, :dashboard)
       |> assign(:breadcrumb, [{"Admin", "/admin"}])
       |> assign(:stats, stats)
       |> assign(:registry, Registry.all())}
    end
  end

  defp load_stats do
    import Ecto.Query

    %{
      users:    Repo.aggregate(User, :count),
      products: Repo.aggregate(Product, :count),
      branches: Repo.aggregate(Branch, :count),
      orders:   Repo.aggregate(Order, :count),
      pending_orders:   Repo.aggregate(from(o in Order, where: o.status == :pending), :count),
      active_products:  Repo.aggregate(from(p in Product, where: p.is_active == true), :count),
      today_orders: Repo.aggregate(
        from(o in Order, where: o.inserted_at >= ^beginning_of_today()),
        :count
      ),
    }
  end

  defp beginning_of_today do
    Date.utc_today()
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Stat tiles -->
    <div class="adm-stats">
      <div class="adm-stat">
        <div class="adm-stat-icon">👤</div>
        <div class="adm-stat-num"><%= @stats.users %></div>
        <div class="adm-stat-label">Total Users</div>
      </div>
      <div class="adm-stat">
        <div class="adm-stat-icon">📦</div>
        <div class="adm-stat-num"><%= @stats.products %></div>
        <div class="adm-stat-label">Products</div>
        <div class="adm-stat-trend"><%= @stats.active_products %> active</div>
      </div>
      <div class="adm-stat">
        <div class="adm-stat-icon">🏪</div>
        <div class="adm-stat-num"><%= @stats.branches %></div>
        <div class="adm-stat-label">Branches</div>
      </div>
      <div class="adm-stat">
        <div class="adm-stat-icon">🛒</div>
        <div class="adm-stat-num"><%= @stats.orders %></div>
        <div class="adm-stat-label">Total Orders</div>
        <div class="adm-stat-trend"><%= @stats.today_orders %> today</div>
      </div>
      <div class="adm-stat">
        <div class="adm-stat-icon">⏳</div>
        <div class="adm-stat-num"><%= @stats.pending_orders %></div>
        <div class="adm-stat-label">Pending Orders</div>
      </div>
    </div>

    <!-- Registered models grid -->
    <div class="adm-card" style="margin-bottom:24px;">
      <div class="adm-card-header">
        <span class="adm-card-title">📋 Registered Models</span>
        <span style="font-size:11px;color:var(--adm-text2);"><%= length(@registry) %> models registered</span>
      </div>
      <div class="adm-card-body">
        <div class="adm-model-grid">
          <%= for entry <- @registry do %>
            <a href={"/admin/r/#{Qcommerce.Admin.Registry.schema_to_slug(entry.schema)}"} class="adm-model-card">
              <div class="adm-model-icon"><%= entry.icon %></div>
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

    <!-- Quick links -->
    <div class="adm-card">
      <div class="adm-card-header">
        <span class="adm-card-title">⚡ Quick Actions</span>
      </div>
      <div class="adm-card-body" style="display:flex;gap:10px;flex-wrap:wrap;">
        <a href="/admin/r/product/new" class="adm-btn adm-btn-primary">+ Add Product</a>
        <a href="/admin/r/category/new" class="adm-btn adm-btn-primary">+ Add Category</a>
        <a href="/admin/r/branch/new" class="adm-btn adm-btn-primary">+ Add Branch</a>
        <a href="/admin/r/user/new" class="adm-btn adm-btn-ghost">+ Add User</a>
        <a href="/admin/settings" class="adm-btn adm-btn-ghost">⚙️ Settings</a>
      </div>
    </div>
    """
  end
end
