defmodule QcommerceWeb.Live.Components.LayoutComponents do
  use QcommerceWeb, :html

  # ---------------------------------------------------------------------------
  # Footer
  # ---------------------------------------------------------------------------
  def footer(assigns) do
    ~H"""
    <footer>
      <div class="footer-inner">
        <div class="footer-copy">© 2025 QCommerce · Delivered in 10 minutes</div>
        <div class="footer-links">
          <a href="#">Privacy</a>
          <a href="#">Terms</a>
          <a href="#">Help</a>
          <a href="#">Careers</a>
        </div>
      </div>
    </footer>
    """
  end
end
