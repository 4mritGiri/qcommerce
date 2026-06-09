defmodule QcommerceWeb.Paths do
  @moduledoc """
  A centralized navigation module that translates named routing helper functions
  into compile-time verified Phoenix routes (~p).

  Mimics Django's named path architecture. If any target URL route changes
  inside `router.ex`, update it here once to repair it globally across the app.
  """
  use QcommerceWeb, :verified_routes

  # ---------------------------------------------------------------------------
  # Public Browser / LiveView Paths
  # ---------------------------------------------------------------------------

  # def home, do: ~p"/"
  def home(params \\ []), do: ~p"/?#{params}"
  def search, do: ~p"/search"

  @doc "Shared cart path using an encoded token"
  def cart_share(token), do: ~p"/cart/share/#{token}"

  # ---------------------------------------------------------------------------
  # Authentication Paths (SessionController)
  # ---------------------------------------------------------------------------

  def session_login, do: ~p"/session/login"
  def session_signup, do: ~p"/session/signup"
  def session_logout, do: ~p"/session/logout"
  def session_login_phone, do: ~p"/session/login_phone"
  def session_login_qr, do: ~p"/session/login_qr"
  def session_login_passkey, do: ~p"/session/login_passkey"
  def session_save_guest_cart, do: ~p"/session/save_guest_cart"

  # WebAuthn Passkey Endpoints
  def passkey_reg_options, do: ~p"/session/passkey/registration_options"
  def passkey_register, do: ~p"/session/passkey/register"
  def passkey_auth_options, do: ~p"/session/passkey/authentication_options"
  def passkey_authenticate, do: ~p"/session/passkey/authenticate"

  # ---------------------------------------------------------------------------
  # Admin Interface Paths
  # ---------------------------------------------------------------------------

  def admin_dashboard, do: ~p"/admin"
  def admin_settings, do: ~p"/admin/settings"

  @doc "Dynamic resource list view. Example: Paths.admin_resource_list('products')"
  def admin_resource_list(resource), do: ~p"/admin/r/#{resource}"

  @doc "Form path to initialize a new instance of a resource"
  def admin_resource_new(resource), do: ~p"/admin/r/#{resource}/new"

  @doc "Detailed view of a unique resource id entry"
  def admin_resource_show(resource, id), do: ~p"/admin/r/#{resource}/#{id}"

  @doc "Edit view path for an existing unique resource id entry"
  def admin_resource_edit(resource, id), do: ~p"/admin/r/#{resource}/#{id}/edit"

  # ---------------------------------------------------------------------------
  # API v1 Paths (Public & Authenticated REST)
  # ---------------------------------------------------------------------------

  def api_register, do: ~p"/api/v1/auth/register"
  def api_login, do: ~p"/api/v1/auth/login"
  def api_me, do: ~p"/api/v1/auth/me"
  def api_logout, do: ~p"/api/v1/auth/logout"

  def api_categories, do: ~p"/api/v1/categories"
  def api_branch_products(branch_id), do: ~p"/api/v1/branches/#{branch_id}/products"
  def api_branch_product_show(branch_id, id), do: ~p"/api/v1/branches/#{branch_id}/products/#{id}"

  def api_cart_validate, do: ~p"/api/v1/cart/validate"
  def api_orders, do: ~p"/api/v1/orders"
  def api_order_show(id), do: ~p"/api/v1/orders/#{id}"

  # # ---------------------------------------------------------------------------
  # # Development Tool Paths (Dev Routes Only)
  # # ---------------------------------------------------------------------------

  # def dev_dashboard, do: ~p"/dashboard"
  # def dev_mailbox, do: ~p"/mailbox"
end
