defmodule Qcommerce.Cart.CartShare do
  @moduledoc """
  Schema for shareable cart links with expiry.
  Each share link encodes items + quantities and expires after TTL.

  Migration:
    mix ecto.gen.migration create_cart_shares

    def change do
      create table(:cart_shares, primary_key: false) do
        add :id,         :binary_id, primary_key: true
        add :token,      :string,    null: false
        add :items,      :map,       null: false   # %{"product_id" => %{qty, price, name, emoji}}
        add :total,      :decimal,   null: false
        add :item_count, :integer,   null: false
        add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
        add :expires_at, :utc_datetime, null: false
        add :view_count, :integer,   default: 0
        timestamps()
      end

      create unique_index(:cart_shares, [:token])
      create index(:cart_shares, [:expires_at])
    end
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cart_shares" do
    field :token,      :string
    field :items,      :map
    field :total,      :decimal
    field :item_count, :integer
    field :expires_at, :utc_datetime
    field :view_count, :integer, default: 0

    belongs_to :creator, Qcommerce.Accounts.User
    timestamps()
  end

  @ttl_hours 24

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:token, :items, :total, :item_count, :creator_id, :expires_at])
    |> validate_required([:token, :items, :total, :item_count, :expires_at])
    |> unique_constraint(:token)
  end

  def build(cart_items, creator_id \\ nil) do
    total     = compute_total(cart_items)
    item_count = Enum.reduce(cart_items, 0, fn {_, i}, acc -> acc + i.qty end)
    expires_at = DateTime.utc_now() |> DateTime.add(@ttl_hours * 3600, :second) |> DateTime.truncate(:second)

    %__MODULE__{}
    |> changeset(%{
      token:      generate_token(),
      items:      serialize_items(cart_items),
      total:      total,
      item_count: item_count,
      creator_id: creator_id,
      expires_at: expires_at
    })
  end

  def expired?(%__MODULE__{expires_at: exp}) do
    DateTime.compare(DateTime.utc_now(), exp) == :gt
  end

  def seconds_remaining(%__MODULE__{expires_at: exp}) do
    max(0, DateTime.diff(exp, DateTime.utc_now(), :second))
  end

  defp generate_token do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp compute_total(items) do
    Enum.reduce(items, Decimal.new("0"), fn {_, i}, acc ->
      Decimal.add(acc, Decimal.mult(parse_price(i.price), Decimal.new(i.qty)))
    end)
  end

  defp serialize_items(items) do
    Map.new(items, fn {k, v} ->
      {to_string(k), %{
        "qty"   => v.qty,
        "price" => Decimal.to_string(parse_price(v.price)),
        "name"  => v.name,
        "emoji" => v.emoji
      }}
    end)
  end

  defp parse_price(p) when is_binary(p) do
    case Decimal.parse(p) do {d, _} -> d; :error -> Decimal.new("0") end
  end
  defp parse_price(%Decimal{} = d), do: d
  defp parse_price(p), do: Decimal.new("#{p}")
end
