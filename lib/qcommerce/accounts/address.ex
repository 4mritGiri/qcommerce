# lib/qcommerce/accounts/address.ex

defmodule Qcommerce.Accounts.Address do
  use Qcommerce.Core.Schema

  @moduledoc """
  Delivery address belonging to a user.
  location is a PostGIS GEOGRAPHY point used for branch proximity checks.
  """

  alias Qcommerce.Accounts.User

  schema "addresses" do
    belongs_to :user, User

    field :label, :string, default: "Home"
    field :line1, :string
    field :line2, :string
    field :city, :string
    field :location, Geo.PostGIS.Geometry
    field :is_default, :boolean, default: false

    timestamps(updated_at: false)
  end

  @required [:user_id, :label, :line1, :city]
  @optional [:line2, :location, :is_default]

  def changeset(address, attrs) do
    address
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:line1, min: 5)
    |> assoc_constraint(:user)
  end
end
