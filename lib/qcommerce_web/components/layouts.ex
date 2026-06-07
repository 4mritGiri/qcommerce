# lib/qcommerce_web/components/layouts.ex

defmodule QcommerceWeb.Layouts do
  use QcommerceWeb, :html

  # Embeds all .heex files in the layouts/ directory.
  # Each file becomes a function: root.html.heex → root/1, admin.html.heex → admin/1
  embed_templates "layouts/*"

  def sidebar_icon(assigns) do
    class = assigns[:class] || "nav-svg"
    # Dynamically resolve icon name (supporting emojis, heroicons names, or simple names)
    icon_name = case assigns.icon do
      "🏠" -> "hero-home"
      "⚙️" -> "hero-cog-6-tooth"
      "📦" -> "hero-package"
      "🏷️" -> "hero-tag"
      "🖼️" -> "hero-photo"
      "⚡" -> "hero-bolt"
      "👤" -> "hero-user"
      "🏪" -> "hero-building-storefront"
      "🛒" -> "hero-shopping-cart"
      "🧾" -> "hero-document-text"
      "🏍️" -> "hero-truck"
      "📊" -> "hero-chart-bar"
      "📒" -> "hero-book-open"
      "📔" -> "hero-clipboard-document-list"
      "📋" -> "hero-clipboard"
      "hero-" <> _ = name -> name
      name when is_binary(name) -> "hero-#{name}"
      _ -> "hero-document"
    end

    assigns = assigns |> assign(:icon_name, icon_name) |> assign(:class, class)
    ~H"""
    <span class="icon">
      <QcommerceWeb.CoreComponents.icon name={@icon_name} class={@class} />
    </span>
    """
  end
end
