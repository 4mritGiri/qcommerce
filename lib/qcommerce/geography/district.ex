# lib/qcommerce/geography/district.ex
defmodule Qcommerce.Geography.District do
  @moduledoc """
  Nepal's 77 districts. Belongs to a Province.
  Equivalent to the Django District model.
  """
  use Qcommerce.Core.Schema

  alias Qcommerce.Geography.{Province, LocalBody}

  schema "districts" do
    belongs_to :province, Province

    # "Kathmandu"
    field :name, :string
    # "काठमाडौँ"
    field :name_nepali, :string

    has_many :local_bodies, LocalBody

    timestamps(updated_at: false)
  end

  @required [:name]
  @optional [:province_id, :name_nepali]

  def changeset(district, attrs) do
    district
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:name)
    |> assoc_constraint(:province)
  end
end
