# lib/qcommerce_web/live/admin/settings_live.ex
defmodule QcommerceWeb.Admin.SettingsLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.Settings

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    user    = user_id && Qcommerce.Repo.get(Qcommerce.Accounts.User, user_id)

    if is_nil(user) or user.role != :super_admin do
      {:ok, push_navigate(socket, to: "/")}
    else
      {:ok,
       socket
       |> assign(:page_title, "System Settings")
       |> assign(:current_user, user)
       |> assign(:admin_section, :settings)
       |> assign(:breadcrumb, [{"Admin", "/admin"}, {"Settings", nil}])
       |> assign(:settings, Settings.list_all())}
    end
  end

  @impl true
  def handle_event("toggle_setting", %{"key" => key}, socket) do
    current = Settings.get_bool(key, false)
    Settings.set(key, !current)
    {:noreply,
     socket
     |> assign(:settings, Settings.list_all())
     |> put_flash(:info, "Setting updated.")}
  end

  def handle_event("save_setting", %{"key" => key, "value" => value}, socket) do
    Settings.set(key, value)
    {:noreply,
     socket
     |> assign(:settings, Settings.list_all())
     |> put_flash(:info, "Saved.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="adm-page-header">
      <h1 class="adm-page-title">⚙️ System Settings</h1>
      <p class="adm-page-sub">Configure platform behavior, feature flags, and authentication methods</p>
    </div>

    <%= for {group, group_settings} <- Enum.group_by(@settings, & &1.group) do %>
      <div class="adm-card" style="margin-bottom: 24px; overflow: hidden;">
        <div class="adm-card-header">
          <span class="adm-card-title"><%= String.capitalize(group || "general") %> Settings</span>
        </div>
        <div class="adm-card-body" style="padding: 0;">
          <%= for setting <- group_settings do %>
            <div style="display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid var(--adm-border); gap: 16px;">
              <div style="flex: 1;">
                <div style="font-size: 13.5px; font-weight: 600; color: var(--adm-text); margin-bottom: 3px;">
                  <%= setting.label || setting.key %>
                </div>
                <%= if setting.description do %>
                  <div style="font-size: 11.5px; color: var(--adm-text2); line-height: 1.4;"><%= setting.description %></div>
                <% end %>
                <div style="font-size: 9.5px; font-family: monospace; color: var(--adm-text3); margin-top: 4px;"><%= setting.key %></div>
              </div>

              <%= if setting.value in ["true", "false"] do %>
                <button
                  phx-click="toggle_setting"
                  phx-value-key={setting.key}
                  style={"width: 44px; height: 24px; border-radius: 12px; border: none; cursor: pointer; transition: background .2s; position: relative; background: #{if setting.value == "true", do: "var(--adm-green)", else: "var(--adm-border)"};"}
                  title={if setting.value == "true", do: "Enabled", else: "Disabled"}>
                  <span style={"position: absolute; top: 2px; width: 20px; height: 20px; background: #fff; border-radius: 50%; transition: left .2s; left: #{if setting.value == "true", do: "22px", else: "2px"};"}>
                  </span>
                </button>
              <% else %>
                <form phx-submit="save_setting" style="display: flex; gap: 8px; align-items: center;">
                  <input type="hidden" name="key" value={setting.key} />
                  <input type="text" name="value" value={setting.value} class="adm-input"
                    style="height: 34px; width: 180px; padding: 0 10px; font-size: 13px; outline: none;" />
                  <button type="submit" class="adm-btn adm-btn-primary" style="height: 34px;">
                    Save
                  </button>
                </form>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end
end
