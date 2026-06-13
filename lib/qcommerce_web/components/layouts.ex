# lib/qcommerce_web/components/layouts.ex

defmodule QcommerceWeb.Layouts do
  use QcommerceWeb, :html

  # Embeds all .heex files in the layouts/ directory.
  # Each file becomes a function: root.html.heex → root/1, admin.html.heex → admin/1
  embed_templates "layouts/*"

  def sidebar_icon(assigns) do
    class = assigns[:class] || "nav-svg"
    icon = assigns.icon || "hero-document"
    assigns = assign(assigns, :icon_name, icon) |> assign(:class, class)

    ~H"""
    <QcommerceWeb.CoreComponents.icon name={@icon_name} class={@class} />
    """
  end
end
