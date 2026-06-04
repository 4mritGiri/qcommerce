# lib/qcommerce/rate_limiters/api_limiter.ex

defmodule Qcommerce.RateLimiters.ApiLimiter do
  @moduledoc """
  Rate limiter for general API endpoints (product search, order listing).
  Hammer 7.x: each limiter is its own module with `use Hammer`.
  Limit: 100 requests per minute per user/IP.
  """
  use Hammer, backend: :ets

  @limit 100
  @window :timer.minutes(1)

  @doc """
  Check rate limit for a given key (user_id or IP address string).
  Returns :ok or {:error, :rate_limited}.
  """
  def check(key) do
    case hit("api:#{key}", @window, @limit) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end
end
