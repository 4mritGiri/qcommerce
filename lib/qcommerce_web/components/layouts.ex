# lib/qcommerce_web/components/layouts.ex

defmodule QcommerceWeb.Layouts do
  use QcommerceWeb, :html

  # Embeds all .heex files in the layouts/ directory.
  # Each file becomes a function: root.html.heex → root/1, admin.html.heex → admin/1
  embed_templates "layouts/*"
end
