# lib/qcommerce_web/controllers/api/v1/auth_controller.ex
defmodule QcommerceWeb.Api.V1.AuthController do
  use QcommerceWeb, :controller

  alias Qcommerce.Accounts
  alias Qcommerce.Auth.Guardian
  alias QcommerceWeb.Plugs.RateLimitPlug

  action_fallback QcommerceWeb.FallbackController

  # Rate limit auth endpoints strictly — 10 attempts per 15 min per IP
  plug RateLimitPlug, [limiter: :auth] when action in [:login]

  @doc "POST /api/v1/auth/register"
  def register(conn, params) do
    with {:ok, user} <- Accounts.create_user(params),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user, %{}, token_type: "access") do
      conn
      |> put_status(:created)
      |> json(%{data: %{user: user, token: token}})
    end
  end

  @doc "POST /api/v1/auth/login"
  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- Accounts.authenticate(email, password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user, %{}, token_type: "access") do
      json(conn, %{data: %{user: user, token: token}})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "email and password are required"}})
  end

  @doc "GET /api/v1/auth/me — returns current authenticated user"
  def me(conn, _params) do
    json(conn, %{data: conn.assigns.current_user})
  end

  @doc "DELETE /api/v1/auth/logout"
  def logout(conn, _params) do
    token = Guardian.Plug.current_token(conn)
    Guardian.revoke(token)
    send_resp(conn, :no_content, "")
  end
end
