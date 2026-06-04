# lib/qcommerce_web/plugs/set_current_user.ex

defmodule QcommerceWeb.Plugs.SetCurrentUser do
  @moduledoc """
  Loads the current user from Guardian token into conn.assigns.
  Run AFTER Guardian.Plug.LoadResource in the pipeline.

  Usage in router:
    plug QcommerceWeb.Plugs.SetCurrentUser
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)
    assign(conn, :current_user, user)
  end
end
