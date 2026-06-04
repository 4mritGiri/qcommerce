# lib/qcommerce/catalog/catalog.ex

defmodule Qcommerce.Catalog do
  @moduledoc """
  Public context API for product catalog and categories.
  Read-heavy — products and categories change infrequently.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Query}
  alias Qcommerce.Catalog.{Category, Product}

  # ---------------------------------------------------------------------------
  # Products
  # ---------------------------------------------------------------------------

  def list_products(params \\ []) do
    base =
      Product
      |> Query.filter_by(:is_active, params[:is_active])
      |> Query.filter_by(:category_id, params[:category_id])
      |> Query.search([:name, :sku], params[:q])
      |> Query.sort(params[:sort], params[:dir], allowed: [:name, :base_price, :inserted_at])

    total = Repo.aggregate(base, :count)
    {paginated, meta} = Query.paginate(base, page: params[:page], per_page: params[:per_page])

    {:ok, {Repo.all(paginated), Map.put(meta, :total, total)}}
  end

  def get_product(id) do
    case Repo.get(Product, id) do
      nil -> {:error, Error.not_found("Product", id)}
      product -> {:ok, product}
    end
  end

  def get_product_by_sku(sku) do
    case Repo.get_by(Product, sku: sku) do
      nil -> {:error, Error.not_found("Product")}
      product -> {:ok, product}
    end
  end

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
    |> handle_result()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
    |> handle_result()
  end

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  def list_categories(params \\ []) do
    categories =
      Category
      |> Query.filter_by(:is_active, params[:is_active])
      # top-level only; children via preload
      |> where([c], is_nil(c.parent_id))
      |> order_by([c], asc: c.sort_order, asc: c.name)
      |> Query.with_preloads([:children])
      |> Repo.all()

    {:ok, categories}
  end

  def get_category(id) do
    case Repo.get(Category, id) do
      nil -> {:error, Error.not_found("Category", id)}
      category -> {:ok, category}
    end
  end

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
    |> handle_result()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp handle_result({:ok, record}), do: {:ok, record}
  defp handle_result({:error, %Ecto.Changeset{} = cs}), do: {:error, Error.validation(cs)}
  defp handle_result({:error, reason}), do: {:error, Error.internal(inspect(reason))}
end
