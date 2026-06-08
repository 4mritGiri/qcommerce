# lib/qcommerce/cart/cart_session.ex
defmodule Qcommerce.Cart.CartSession do
  @moduledoc """
  Manages cart state across guest and authenticated sessions.

  Strategy:
  - Guest carts live in the LiveView socket assigns (in-memory)
  - On login redirect, cart items are serialized into the browser session cookie
  - SessionController merges the guest cart into the user's persistent cart on login
  - CartStore (ETS + DB) holds logged-in user carts between page loads
  """

  @guest_cart_key "guest_cart"

  # ---------------------------------------------------------------------------
  # Serialize / Deserialize  (used by HomeLive ↔ SessionController)
  # ---------------------------------------------------------------------------

  @doc """
  Encodes cart_items map to a JSON string safe for storing in Plug.Session.
  Call this before redirect to login.
  """
  def encode_cart(cart_items) when map_size(cart_items) == 0, do: nil
  def encode_cart(cart_items) do
    items =
      Enum.map(cart_items, fn {pid, item} ->
        %{
          "id"    => to_string(pid),
          "name"  => item.name,
          "emoji" => item.emoji,
          "qty"   => item.qty,
          "price" => Decimal.to_string(item.price)
        }
      end)

    Jason.encode!(items)
  end

  @doc """
  Decodes JSON from session back into the cart_items map format HomeLive expects.
  Returns %{} on nil / bad input.
  """
  def decode_cart(nil), do: %{}
  def decode_cart(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, items} when is_list(items) ->
        Map.new(items, fn item ->
          pid   = item["id"]
          price = case Decimal.parse(item["price"]) do
            {d, _} -> d
            :error  -> Decimal.new("0")
          end
          {pid, %{name: item["name"], emoji: item["emoji"], qty: item["qty"], price: price}}
        end)

      _ -> %{}
    end
  end

  @doc "Session key for guest cart storage."
  def guest_cart_key, do: @guest_cart_key

  # ---------------------------------------------------------------------------
  # Merge  (guest items into logged-in cart)
  # ---------------------------------------------------------------------------

  @doc """
  Merges guest_cart into existing_cart.
  If the same product_id exists in both, quantities are summed.
  """
  def merge(existing_cart, guest_cart) when map_size(guest_cart) == 0, do: existing_cart
  def merge(existing_cart, guest_cart) do
    Enum.reduce(guest_cart, existing_cart, fn {pid, guest_item}, acc ->
      Map.update(acc, pid, guest_item, fn existing ->
        %{existing | qty: existing.qty + guest_item.qty}
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Totals helper (duplicated here so SessionController can use it without
  # depending on HomeLive)
  # ---------------------------------------------------------------------------

  def cart_totals(items) do
    count = map_size(items)
    total = Enum.reduce(items, Decimal.new("0"), fn {_, i}, acc ->
      Decimal.add(acc, Decimal.mult(i.price, Decimal.new(i.qty)))
    end)
    {count, total}
  end
end
