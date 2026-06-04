# lib/qcommerce/rate_limiters/auth_limiter.ex

defmodule Qcommerce.RateLimiters.AuthLimiter do
  @moduledoc """
  Stricter rate limiter for authentication endpoints.
  Prevents brute-force password attacks.
  Limit: 10 attempts per 15 minutes per IP address.
  """
  use Hammer, backend: :ets

  @limit 10
  @window :timer.minutes(15)

  @doc """
  Check rate limit for login attempts by IP.
  Returns :ok or {:error, :rate_limited}.
  """
  def check(ip) do
    case hit("auth:#{ip}", @window, @limit) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end
end
