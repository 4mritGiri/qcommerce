# lib/qcommerce/platform/branch.ex

defmodule Qcommerce.Platform.Branch do
  use Qcommerce.Core.Schema

  @moduledoc """
  A Branch is a physical dark store that fulfils orders within its
  catchment radius. Every order, inventory record, and ledger entry
  is scoped to a branch — it is the primary data isolation boundary.
  """

  schema "branches" do
    field :code, :string
    field :name, :string
    field :address_line, :string
    field :city, :string
    # PostGIS GEOGRAPHY(POINT, 4326) — decoded as %Geo.Point{} by geo_postgis
    field :location, Geo.PostGIS.Geometry
    field :catchment_radius_m, :integer, default: 3000
    field :is_active, :boolean, default: true

    timestamps()
  end

  @required [:code, :name, :address_line, :city]
  @optional [:location, :catchment_radius_m, :is_active]

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:code, min: 2, max: 50)
    |> validate_number(:catchment_radius_m, greater_than: 0)
    |> unique_constraint(:code)
  end
end
