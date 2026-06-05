# lib/qcommerce/catalog/slide.ex
defmodule Qcommerce.Catalog.Slide do
  use Qcommerce.Core.Schema

  @moduledoc """
  Hero carousel slide. Each slide has a theme, headline, and up to 5 featured products.
  Slides are ordered by position and only active slides are shown.
  Products are linked via the slide_products join table.
  """

  alias Qcommerce.Catalog.Product

  schema "slides" do
    # CSS class: "slide-green", "slide-amber" etc.
    field :theme, :string
    # e.g. "⚡ 10 Min Delivery"
    field :tag, :string
    # e.g. "Freshness at lightning speed"
    field :heading, :string
    # subtitle
    field :sub, :string
    field :cta_label, :string, default: "Shop now"
    # decorative emoji overlay
    field :emojis, {:array, :string}, default: []
    field :position, :integer, default: 0
    field :is_active, :boolean, default: true

    many_to_many :products, Product,
      join_through: "slide_products",
      join_keys: [slide_id: :id, product_id: :id],
      on_replace: :delete

    timestamps()
  end

  @required [:theme, :tag, :heading]
  @optional [:sub, :cta_label, :emojis, :position, :is_active]

  def changeset(slide, attrs) do
    slide
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:heading, min: 3, max: 120)
  end
end
