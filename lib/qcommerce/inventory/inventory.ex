# lib/qcommerce/inventory/inventory.ex

defmodule Qcommerce.Inventory do
  @moduledoc """
  Public context API for branch stock management.
  All inventory mutations go through this module — never direct Repo calls.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Query}
  alias Qcommerce.Inventory.BranchInventory

  def list_inventory(branch_id, params \\ []) do
    base =
      BranchInventory
      |> Query.for_branch(branch_id)
      |> Query.filter_by(:is_available, params[:is_available])
      |> Query.with_preloads([:product])

    {:ok, Repo.all(base)}
  end

  def get_inventory(branch_id, product_id) do
    case Repo.get_by(BranchInventory, branch_id: branch_id, product_id: product_id) do
      nil -> {:error, Error.not_found("BranchInventory")}
      inv -> {:ok, inv}
    end
  end

  def upsert_inventory(branch_id, product_id, attrs) do
    case Repo.get_by(BranchInventory, branch_id: branch_id, product_id: product_id) do
      nil ->
        %BranchInventory{branch_id: branch_id, product_id: product_id}
        |> BranchInventory.changeset(attrs)
        |> Repo.insert()
        |> handle_result()

      existing ->
        existing
        |> BranchInventory.changeset(attrs)
        |> Repo.update()
        |> handle_result()
    end
  end

  @doc """
  Atomically decrements stock for a single product.
  Returns {:error, :insufficient_stock} if quantity would go below zero.
  """
  def decrement_stock(branch_id, product_id, qty) do
    with {:ok, inv} <- get_inventory(branch_id, product_id) do
      inv
      |> BranchInventory.decrement_changeset(qty)
      |> Repo.update()
      |> handle_result()
    end
  end

  def low_stock_items(branch_id) do
    items =
      BranchInventory
      |> Query.for_branch(branch_id)
      |> where([i], i.quantity_on_hand <= i.reorder_threshold)
      |> Query.with_preloads([:product])
      |> Repo.all()

    {:ok, items}
  end

  defp handle_result({:ok, record}), do: {:ok, record}
  defp handle_result({:error, %Ecto.Changeset{} = cs}), do: {:error, Error.validation(cs)}
  defp handle_result({:error, reason}), do: {:error, Error.internal(inspect(reason))}
end
