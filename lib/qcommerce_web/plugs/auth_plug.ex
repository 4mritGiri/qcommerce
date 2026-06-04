# lib/qcommerce_web/plugs/auth_plug.ex

defmodule QcommerceWeb.Plugs.AuthPlug do
  @moduledoc """
  Verifies the current user has one of the required roles.
  Used to protect branch_manager and super_admin routes.

  Usage in router pipeline or individual controller:
    plug QcommerceWeb.Plugs.AuthPlug, roles: [:branch_manager, :super_admin]
  """
  import Plug.Conn

  alias Qcommerce.Core.Error

  def init(opts), do: opts

  def call(conn, roles: allowed_roles) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) ->
        halt_with(conn, Error.unauthorized())

      user.role not in allowed_roles ->
        halt_with(conn, Error.forbidden("Insufficient permissions"))

      true ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp halt_with(conn, error) do
    body = Jason.encode!(Error.to_map(error))

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(Error.to_http(error), body)
    |> halt()
  end
end
