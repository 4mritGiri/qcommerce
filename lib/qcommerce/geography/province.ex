# lib/qcommerce/geography/province.ex
defmodule Qcommerce.Geography.Province do
  @moduledoc """
  Nepal's 7 provinces (Koshi, Madhesh, Bagmati, Gandaki, Lumbini, Karnali, Sudurpashchim).
  Equivalent to the Django Province model.
  """
  use Qcommerce.Core.Schema

  alias Qcommerce.Geography.District

  schema "provinces" do
    # "1".."7"
    field :code, :string
    # "Bagmati Province"
    field :name, :string
    # "बागमती प्रदेश"
    field :name_nepali, :string

    has_many :districts, District

    timestamps(updated_at: false)
  end

  @required [:code, :name]
  @optional [:name_nepali]

  def changeset(province, attrs) do
    province
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:code)
    |> unique_constraint(:name)
  end
end
