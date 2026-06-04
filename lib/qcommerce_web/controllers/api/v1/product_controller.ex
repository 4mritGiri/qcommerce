# lib/qcommerce_web/controllers/api/v1/product_controller.ex
defmodule QcommerceWeb.Api.V1.ProductController do
  use QcommerceWeb, :controller

  alias Qcommerce.Catalog
  alias Qcommerce.Inventory
  alias QcommerceWeb.Plugs.RateLimitPlug

  action_fallback QcommerceWeb.FallbackController

  plug RateLimitPlug, limiter: :api

  @doc "GET /api/v1/branches/:branch_id/products"
  def index(conn, %{"branch_id" => _branch_id} = params) do
    with {:ok, {products, meta}} <- Catalog.list_products(params) do
      json(conn, %{data: products, meta: meta})
    end
  end

  @doc "GET /api/v1/branches/:branch_id/products/:id"
  def show(conn, %{"branch_id" => branch_id, "id" => product_id}) do
    with {:ok, product} <- Catalog.get_product(product_id),
         {:ok, inventory} <- Inventory.get_inventory(branch_id, product_id) do
      json(conn, %{data: Map.put(product, :inventory, inventory)})
    end
  end

  @doc "GET /api/v1/categories"
  def categories(conn, params) do
    with {:ok, categories} <- Catalog.list_categories(params) do
      json(conn, %{data: categories})
    end
  end
end
