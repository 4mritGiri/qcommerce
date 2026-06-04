defmodule Qcommerce.Core.Query do
  @moduledoc """
  Reusable Ecto query composition helpers shared by every context.

  ## DRY principle
  Every context pipes through these helpers instead of writing
  raw where/order_by/limit clauses inline. One change here fixes
  every context simultaneously.

  ## Usage
      Product
      |> Query.search([:name, :sku], params["q"])
      |> Query.filter_by(:is_active, true)
      |> Query.sort(params["sort"], params["dir"])
      |> Query.paginate(page: params["page"], per_page: params["per_page"])
      |> Repo.all()
  """

  import Ecto.Query

  @default_page 1
  @default_per_page 20
  @max_per_page 100

  # ---------------------------------------------------------------------------
  # Filtering
  # ---------------------------------------------------------------------------

  @doc "Filter by exact field match. Skips if value is nil."
  def filter_by(query, _field, nil), do: query

  def filter_by(query, field, value) do
    where(query, [q], field(q, ^field) == ^value)
  end

  @doc "Filter by multiple field-value pairs, ANDed together."
  def filter_all(query, filters) when is_list(filters) do
    Enum.reduce(filters, query, fn {field, value}, q ->
      filter_by(q, field, value)
    end)
  end

  @doc """
  Case-insensitive search across one or more text fields (OR logic).
  Skips if term is nil or blank.

  Uses Ecto.Query.dynamic/2 to build the OR chain at runtime safely —
  this avoids the fragment/1 SQL injection restriction while keeping
  full Ecto query composability.

      Product |> Query.search([:name, :sku], "milk") |> Repo.all()
  """
  def search(query, _fields, nil), do: query
  def search(query, _fields, ""), do: query

  def search(query, fields, term) when is_list(fields) and is_binary(term) do
    pattern = "%#{String.trim(term)}%"

    # Build an OR chain using dynamic/2 — the correct Ecto way to compose
    # conditions across a runtime list of fields without string interpolation
    # into fragment/1.
    #
    # dynamic/2 returns a composable Ecto expression, not a string.
    # Ecto parameterizes `^pattern` safely regardless of field count.
    dynamic_condition =
      Enum.reduce(fields, dynamic(false), fn field, acc ->
        dynamic([q], ^acc or ilike(field(q, ^field), ^pattern))
      end)

    where(query, ^dynamic_condition)
  end

  # ---------------------------------------------------------------------------
  # Date range filtering
  # ---------------------------------------------------------------------------

  @doc "Filter records where field >= date. Skips if nil."
  def from_date(query, _field, nil), do: query

  def from_date(query, field, date) do
    where(query, [q], field(q, ^field) >= ^date)
  end

  @doc "Filter records where field <= date. Skips if nil."
  def to_date(query, _field, nil), do: query

  def to_date(query, field, date) do
    where(query, [q], field(q, ^field) <= ^date)
  end

  @doc "Convenience wrapper: from_date + to_date in one call."
  def date_range(query, field, from, to) do
    query
    |> from_date(field, from)
    |> to_date(field, to)
  end

  # ---------------------------------------------------------------------------
  # Sorting
  # ---------------------------------------------------------------------------

  @doc """
  Applies sort order from user-supplied params.
  `allowed` whitelist prevents SQL injection from arbitrary sort fields.
  Falls back to `{:desc, :inserted_at}` for invalid/nil inputs.

      Product
      |> Query.sort("name", "asc", allowed: [:name, :base_price, :inserted_at])
      |> Repo.all()
  """
  def sort(query, field_str, direction_str, opts \\ []) do
    allowed = Keyword.get(opts, :allowed, [:inserted_at, :updated_at, :name])
    default = Keyword.get(opts, :default, {:desc, :inserted_at})
    field = safe_field(field_str, allowed)
    direction = safe_direction(direction_str)

    if field do
      order_by(query, [q], [{^direction, field(q, ^field)}])
    else
      order_by(query, [q], ^[default])
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc """
  Applies LIMIT + OFFSET. Returns {paginated_query, meta}.

      {q, meta} = Query.paginate(base_query, page: 2, per_page: 50)
      results   = Repo.all(q)
      total     = Repo.aggregate(base_query, :count)
      json(conn, %{data: results, meta: Map.put(meta, :total, total)})
  """
  def paginate(query, opts \\ []) do
    page = max(parse_int(opts[:page], @default_page), 1)
    per_page = min(parse_int(opts[:per_page], @default_per_page), @max_per_page)
    offset = (page - 1) * per_page

    paginated = query |> limit(^per_page) |> offset(^offset)
    meta = %{page: page, per_page: per_page, offset: offset}

    {paginated, meta}
  end

  # ---------------------------------------------------------------------------
  # Association loading
  # ---------------------------------------------------------------------------

  @doc "Conditionally preloads a list of associations."
  def with_preloads(query, []), do: query
  def with_preloads(query, associations), do: preload(query, ^associations)

  # ---------------------------------------------------------------------------
  # Scoping helpers — data isolation by branch and user
  # ---------------------------------------------------------------------------

  @doc "Scopes query to a specific branch. Primary isolation mechanism."
  def for_branch(query, branch_id) when is_binary(branch_id) do
    where(query, [q], q.branch_id == ^branch_id)
  end

  @doc "Scopes query to records belonging to a specific user."
  def for_user(query, user_id) when is_binary(user_id) do
    where(query, [q], q.user_id == ^user_id)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp safe_field(nil, _allowed), do: nil

  defp safe_field(str, allowed) when is_binary(str) do
    # String.to_existing_atom/1 raises ArgumentError if the atom was never
    # loaded — meaning it cannot be a real schema field. This is safe.
    atom = String.to_existing_atom(str)
    if atom in allowed, do: atom, else: nil
  rescue
    ArgumentError -> nil
  end

  defp safe_direction("asc"), do: :asc
  defp safe_direction("desc"), do: :desc
  defp safe_direction(_), do: :desc

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> default
    end
  end
end
