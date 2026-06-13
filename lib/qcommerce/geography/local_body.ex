# lib/qcommerce/geography/local_body.ex
defmodule Qcommerce.Geography.LocalBody do
  @moduledoc """
  Nepal's municipalities, rural municipalities, and metropolitan cities.
  This is the granular delivery-area unit used for the location picker.

  Types (matching the Django LocalBodyType choices):
    :metropolitan        — e.g. Kathmandu Metropolitan City
    :sub_metropolitan    — e.g. Pokhara Sub-Metropolitan City
    :municipality        — e.g. Bhaktapur Municipality
    :rural_municipality  — e.g. Shivapuri Rural Municipality

  The :is_service_available flag marks whether QCommerce delivers here.
  Seed it false for all rural municipalities; flip to true as you expand.
  """
  use Qcommerce.Core.Schema

  alias Qcommerce.Geography.District

  @type_values ~w(metropolitan sub_metropolitan municipality rural_municipality)a

  schema "local_bodies" do
    belongs_to :district, District

    field :name, :string
    field :name_nepali, :string

    field :type, Ecto.Enum,
      values: @type_values,
      default: :municipality

    # Number of wards — useful for ward-level delivery zones later
    field :number_of_wards, :integer

    # QCommerce delivery coverage flag
    field :is_service_available, :boolean, default: false

    timestamps(updated_at: false)
  end

  @required [:name, :type]
  @optional [:district_id, :name_nepali, :number_of_wards, :is_service_available]

  def changeset(local_body, attrs) do
    local_body
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:type, @type_values)
    |> assoc_constraint(:district)
  end

  @doc "Human-readable type label for the UI."
  def type_label(:metropolitan), do: "Metropolitan City"
  def type_label(:sub_metropolitan), do: "Sub-Metropolitan City"
  def type_label(:municipality), do: "Municipality"
  def type_label(:rural_municipality), do: "Rural Municipality"
  def type_label(_), do: "Municipality"

  @doc "Short display string: 'Kathmandu (Metropolitan City) — Kathmandu District'"
  def display_name(%__MODULE__{} = lb, district_name \\ nil) do
    parts = ["#{lb.name} (#{type_label(lb.type)})"]
    if district_name, do: parts ++ [district_name], else: parts
    Enum.join(parts, " — ")
  end
end
