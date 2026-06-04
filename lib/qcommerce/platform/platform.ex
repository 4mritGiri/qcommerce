# lib/qcommerce/platform/platform.ex

defmodule Qcommerce.Platform do
  @moduledoc """
  Public context API for platform configuration.
  Manages branches (dark stores) and fiscal years.

  Rule: no other context calls Repo directly for branches or fiscal_years.
  They call this module.
  """

  import Ecto.Query

  alias Qcommerce.Repo
  alias Qcommerce.Core.{Error, Query}
  alias Qcommerce.Platform.{Branch, FiscalYear}

  # ---------------------------------------------------------------------------
  # Branches
  # ---------------------------------------------------------------------------

  @spec list_branches(keyword()) :: {:ok, [Branch.t()]}
  def list_branches(params \\ []) do
    branches =
      Branch
      |> Query.filter_by(:is_active, params[:is_active])
      |> Query.filter_by(:city, params[:city])
      |> Query.sort("name", "asc", allowed: [:name, :city, :code])
      |> Repo.all()

    {:ok, branches}
  end

  @spec get_branch(binary()) :: {:ok, Branch.t()} | {:error, Error.t()}
  def get_branch(id) do
    case Repo.get(Branch, id) do
      nil -> {:error, Error.not_found("Branch", id)}
      branch -> {:ok, branch}
    end
  end

  @spec get_branch_by_code(String.t()) :: {:ok, Branch.t()} | {:error, Error.t()}
  def get_branch_by_code(code) do
    case Repo.get_by(Branch, code: code) do
      nil -> {:error, Error.not_found("Branch")}
      branch -> {:ok, branch}
    end
  end

  @spec create_branch(map()) :: {:ok, Branch.t()} | {:error, Error.t()}
  def create_branch(attrs) do
    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert()
    |> handle_result()
  end

  @spec update_branch(Branch.t(), map()) :: {:ok, Branch.t()} | {:error, Error.t()}
  def update_branch(%Branch{} = branch, attrs) do
    branch
    |> Branch.changeset(attrs)
    |> Repo.update()
    |> handle_result()
  end

  # ---------------------------------------------------------------------------
  # Fiscal Years
  # ---------------------------------------------------------------------------

  @spec current_fiscal_year() :: {:ok, FiscalYear.t()} | {:error, Error.t()}
  def current_fiscal_year do
    today = Date.utc_today()

    query =
      from fy in FiscalYear,
        where: fy.start_date <= ^today and fy.end_date >= ^today,
        where: fy.is_closed == false,
        limit: 1

    case Repo.one(query) do
      nil -> {:error, Error.not_found("FiscalYear")}
      fy -> {:ok, fy}
    end
  end

  @spec get_fiscal_year(binary()) :: {:ok, FiscalYear.t()} | {:error, Error.t()}
  def get_fiscal_year(id) do
    case Repo.get(FiscalYear, id) do
      nil -> {:error, Error.not_found("FiscalYear", id)}
      fy -> {:ok, fy}
    end
  end

  @spec list_fiscal_years() :: {:ok, [FiscalYear.t()]}
  def list_fiscal_years do
    fiscal_years =
      FiscalYear
      |> order_by([fy], desc: fy.start_date)
      |> Repo.all()

    {:ok, fiscal_years}
  end

  @spec create_fiscal_year(map()) :: {:ok, FiscalYear.t()} | {:error, Error.t()}
  def create_fiscal_year(attrs) do
    %FiscalYear{}
    |> FiscalYear.changeset(attrs)
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
