# lib/qcommerce/catalog/product.ex
defmodule Qcommerce.Catalog.Product do
  use Qcommerce.Core.Schema

  @moduledoc """
  Global product catalog. Prices here are reference/defaults only.
  Actual selling price per branch lives in BranchInventory.selling_price.
  old_price enables showing crossed-out original price + discount % in the UI.
  """

  alias Qcommerce.Catalog.Category

  schema "products" do
    belongs_to :category, Category

    field :name, :string
    field :sku, :string
    field :description, :string
    field :base_price, :decimal
    # nil means no discount shown
    field :old_price, :decimal
    field :unit, :string, default: "piece"
    field :image_url, :string
    # display fallback when no image
    field :emoji, :string, default: "🛒"
    field :is_active, :boolean, default: true

    timestamps()
  end

  @required [:category_id, :name, :sku, :base_price]
  @optional [:description, :unit, :image_url, :emoji, :is_active, :old_price]

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

  # ---------------------------------------------------------------------------
  # Display helpers — used in HomeLive templates
  # ---------------------------------------------------------------------------

  @doc "Format price as 'Rs. 32'"
  def format_price(price), do: "Rs. #{Decimal.round(price, 0)}"

  @doc "Discount percentage between old_price and base_price. nil if no discount."
  def discount_pct(%{old_price: nil}), do: nil
  def discount_pct(%{old_price: old}) when is_nil(old), do: nil

  def discount_pct(%{base_price: current, old_price: old}) do
    if Decimal.gt?(old, Decimal.new(0)) do
      pct =
        old
        |> Decimal.sub(current)
        |> Decimal.div(old)
        |> Decimal.mult(Decimal.new(100))
        |> Decimal.round(0)
        |> Decimal.to_integer()

      if pct > 0, do: pct, else: nil
    end
  end

  def discount_pct(_), do: nil
end
