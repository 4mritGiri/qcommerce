# lib/qcommerce/catalog/category.ex

defmodule Qcommerce.Catalog.Category do
  use Qcommerce.Core.Schema

  schema "categories" do
    belongs_to :parent, __MODULE__, foreign_key: :parent_id

    field :name, :string
    field :slug, :string
    field :image_url, :string
    field :sort_order, :integer, default: 0
    field :is_active, :boolean, default: true

    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :products, Qcommerce.Catalog.Product

    timestamps(updated_at: false)
  end

  @required [:name, :slug]
  @optional [:parent_id, :image_url, :sort_order, :is_active]

  def changeset(category, attrs) do
    category
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "only lowercase letters, numbers, hyphens"
    )
    |> unique_constraint(:slug)
  end
end
