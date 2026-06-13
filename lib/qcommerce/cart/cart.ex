defmodule Qcommerce.Cart do
  @moduledoc """
  Context for cart operations — share link creation, lookup, expiry cleanup.
  """

  import Ecto.Query
  alias Qcommerce.Repo
  alias Qcommerce.Cart.CartShare

  # ---------------------------------------------------------------------------
  # Share links
  # ---------------------------------------------------------------------------

  @doc """
  Creates a shareable cart link from the current cart_items map.

  ## Example
      {:ok, share} = Cart.create_share(socket.assigns.cart_items, user_id)
  """
  def create_share(cart_items, creator_id \\ nil) when map_size(cart_items) > 0 do
    CartShare.build(cart_items, creator_id)
    |> Repo.insert()
  end

  @doc """
  Looks up a share by token. Returns {:ok, share} or {:error, :not_found | :expired}.
  Also increments view_count atomically.
  """
  def get_share(token) when is_binary(token) do
    case Repo.get_by(CartShare, token: token) do
      nil ->
        {:error, :not_found}

      share ->
        if CartShare.expired?(share) do
          {:error, :expired}
        else
          # Bump view count without a full update
          Repo.update_all(
            from(s in CartShare, where: s.id == ^share.id),
            inc: [view_count: 1]
          )

          {:ok, share}
        end
    end
  end

  @doc """
  Deserializes stored items map back to the LiveView cart_items format.
  """
  def deserialize_items(%CartShare{items: items}) do
    Map.new(items, fn {k, v} ->
      {k,
       %{
         qty: v["qty"],
         price: Decimal.new(v["price"]),
         name: v["name"],
         emoji: v["emoji"],
         savings_per_unit: v["savings_per_unit"] || 0
       }}
    end)
  end

  @doc """
  Deletes all expired shares. Call from a periodic Oban job or GenServer.

  ## Example (Oban worker)
      def perform(_job), do: Cart.prune_expired_shares()
  """
  def prune_expired_shares do
    {count, _} =
      from(s in CartShare, where: s.expires_at < ^DateTime.utc_now())
      |> Repo.delete_all()

    {:ok, count}
  end

  @doc """
  Builds a share URL that works in every environment (dev, staging, prod).

  Reads from the Phoenix endpoint config so localhost:4000 is used in dev
  and the real domain in production — no hardcoded hostname.
  Falls back to the application-level :base_url config if the endpoint is
  not available (e.g. in tests or background jobs run before the endpoint starts).
  """
  def share_url(token) do
    base =
      try do
        QcommerceWeb.Endpoint.url()
      rescue
        _ -> Application.get_env(:qcommerce, :base_url, "https://qcom.app")
      end

    "#{base}/cart/share/#{token}"
  end
end
