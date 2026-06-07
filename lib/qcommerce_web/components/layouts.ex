# lib/qcommerce_web/components/layouts.ex

defmodule QcommerceWeb.Layouts do
  use QcommerceWeb, :html

  # Embeds all .heex files in the layouts/ directory.
  # Each file becomes a function: root.html.heex → root/1, admin.html.heex → admin/1
  embed_templates "layouts/*"

  def sidebar_icon(assigns) do
    class = assigns[:class] || "nav-svg"
    icon = assigns.icon || "hero-document"

    cond do
      # If the icon starts with an SVG tag, render it directly as raw HTML
      String.starts_with?(icon, "<svg") ->
        # Inject the custom styling class into the raw SVG tag to ensure it scales correctly
        modified_svg = String.replace(icon, "<svg", "<svg class=\"#{class}\"")
        assigns = assigns |> assign(:modified_svg, raw(modified_svg))
        ~H"""
        <span class="icon">
          {@modified_svg}
        </span>
        """

      # If it's a file name, check if we can load the file from assets/icons/ or priv/static/icons/
      svg_content = read_svg(icon) ->
        modified_svg = String.replace(svg_content, "<svg", "<svg class=\"#{class}\"")
        assigns = assigns |> assign(:modified_svg, raw(modified_svg))
        ~H"""
        <span class="icon">
          {@modified_svg}
        </span>
        """

      # Otherwise, use the standard dynamic icon helper component
      true ->
        assigns = assigns |> assign(:icon_name, icon) |> assign(:class, class)
        ~H"""
        <span class="icon">
          <QcommerceWeb.CoreComponents.icon name={@icon_name} class={@class} />
        </span>
        """
    end
  end

  defp read_svg(icon) do
    if is_binary(icon) and not String.contains?(icon, " ") and not String.starts_with?(icon, "hero-") do
      paths = [
        Path.join(["assets", "icons", "#{icon}.svg"]),
        Path.join(["assets", "icons", icon]),
        Path.join(["assets", "#{icon}.svg"]),
        Path.join([:code.priv_dir(:qcommerce), "static", "icons", "#{icon}.svg"]),
        Path.join([:code.priv_dir(:qcommerce), "static", "icons", icon])
      ]

      Enum.find_value(paths, fn path ->
        case File.read(path) do
          {:ok, content} -> content
          _ -> nil
        end
      end)
    else
      nil
    end
  end
end
