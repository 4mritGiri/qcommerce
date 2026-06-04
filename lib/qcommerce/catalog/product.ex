# lib/qcommerce/catalog/product.ex
defmodule Qcommerce.Catalog.Product do
  use Qcommerce.Core.Schema

  @moduledoc """
  Global product catalog. Prices here are reference/defaults only.
  Actual selling price per branch lives in BranchInventory.selling_price.
  """

  alias Qcommerce.Catalog.Category

  schema "products" do
    belongs_to :category, Category

    field :name, :string
    field :sku, :string
    field :description, :string
    field :base_price, :decimal
    field :unit, :string, default: "piece"
    field :image_url, :string
    field :is_active, :boolean, default: true

    timestamps()
  end

  @required [:category_id, :name, :sku, :base_price]
  @optional [:description, :unit, :image_url, :is_active]

  def changeset(product, attrs) do
    product
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:base_price, greater_than_or_equal_to: 0)
    |> validate_length(:sku, min: 2, max: 100)
    |> unique_constraint(:sku)
    |> assoc_constraint(:category)
  end

  def deactivate_changeset(product), do: change(product, is_active: false)
end
