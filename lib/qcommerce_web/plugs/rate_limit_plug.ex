# lib/qcommerce_web/plugs/rate_limit_plug.ex

defmodule QcommerceWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Applies rate limiting using the appropriate limiter module.
  Key is derived from current_user.id if authenticated, remote_ip otherwise.

  Usage:
    plug QcommerceWeb.Plugs.RateLimitPlug, limiter: :api
    plug QcommerceWeb.Plugs.RateLimitPlug, limiter: :auth
  """
  import Plug.Conn

  alias Qcommerce.RateLimiters.{ApiLimiter, AuthLimiter}
  alias Qcommerce.Core.Error

  def init(opts), do: opts

  def call(conn, limiter: limiter_type) do
    key = rate_limit_key(conn)

    result =
      case limiter_type do
        :api -> ApiLimiter.check(key)
        :auth -> AuthLimiter.check(key)
      end

    case result do
      :ok ->
        conn

      {:error, :rate_limited} ->
        error = %Error{
          type: :conflict,
          message: "Too many requests. Please slow down.",
          details: nil
        }

        body = Jason.encode!(Error.to_map(error))

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, body)
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp rate_limit_key(conn) do
    case conn.assigns[:current_user] do
      nil -> conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
      user -> user.id
    end
  end
end
