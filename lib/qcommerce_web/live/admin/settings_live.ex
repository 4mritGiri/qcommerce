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
    <div style="max-width:800px;margin:0 auto;padding:32px 16px">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:32px">
        <h1 style="font-size:22px;font-weight:800">⚙️ System Settings</h1>
        <a href="/" style="font-size:13px;color:var(--green);font-weight:600;text-decoration:none">← Back to store</a>
      </div>

      <.flash_group flash={@flash} />

      <%= for {group, group_settings} <- Enum.group_by(@settings, & &1.group) do %>
        <div style="background:#fff;border-radius:14px;border:1.5px solid var(--border);margin-bottom:24px;overflow:hidden">
          <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:var(--text2);padding:14px 20px 10px;border-bottom:1px solid var(--border)">
            <%= String.capitalize(group || "general") %>
          </div>

          <%= for setting <- group_settings do %>
            <div style="display:flex;align-items:flex-start;justify-content:space-between;padding:16px 20px;border-bottom:1px solid #f3f4f6;gap:16px">
              <div style="flex:1">
                <div style="font-size:14px;font-weight:600;color:var(--text);margin-bottom:3px">
                  <%= setting.label || setting.key %>
                </div>
                <%= if setting.description do %>
                  <div style="font-size:12px;color:var(--text2);line-height:1.4"><%= setting.description %></div>
                <% end %>
                <div style="font-size:10px;font-family:monospace;color:var(--text3);margin-top:4px"><%= setting.key %></div>
              </div>

              <%= if setting.value in ["true", "false"] do %>
                <button
                  phx-click="toggle_setting"
                  phx-value-key={setting.key}
                  style={"width:44px;height:24px;border-radius:12px;border:none;cursor:pointer;transition:background .2s;position:relative;background:#{if setting.value == "true", do: "var(--green)", else: "#d1d5db"}"}
                  title={if setting.value == "true", do: "Enabled", else: "Disabled"}>
                  <span style={"position:absolute;top:2px;width:20px;height:20px;background:#fff;border-radius:50%;transition:left .2s;left:#{if setting.value == "true", do: "22px", else: "2px"}"}>
                  </span>
                </button>
              <% else %>
                <form phx-submit="save_setting" style="display:flex;gap:8px;align-items:center">
                  <input type="hidden" name="key" value={setting.key} />
                  <input type="text" name="value" value={setting.value}
                    style="height:32px;border:1.5px solid var(--border);border-radius:8px;padding:0 10px;font-size:13px;width:160px;outline:none" />
                  <button type="submit"
                    style="height:32px;padding:0 14px;background:var(--green);color:#fff;border:none;border-radius:8px;font-size:12px;font-weight:600;cursor:pointer">
                    Save
                  </button>
                </form>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
