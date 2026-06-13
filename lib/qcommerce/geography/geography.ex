# lib/qcommerce/geography/geography.ex
defmodule Qcommerce.Geography do
  @moduledoc """
  Public context for Nepal's administrative geography.

  Hierarchy:
    Province → District → LocalBody (municipality / metropolitan / rural)

  Used by:
    - HomeLive location picker (search + GPS reverse-geocode)
    - Customer address forms (province/district/local_body selects)
    - Delivery availability check (`service_available?/1`)
  """

  import Ecto.Query
  alias Qcommerce.Repo
  alias Qcommerce.Geography.{Province, District, LocalBody}

  # ---------------------------------------------------------------------------
  # Provinces
  # ---------------------------------------------------------------------------

  @doc "All provinces ordered by code."
  def list_provinces do
    Repo.all(from p in Province, order_by: p.code)
  end

  def get_province(id), do: Repo.get(Province, id)

  # ---------------------------------------------------------------------------
  # Districts
  # ---------------------------------------------------------------------------

  @doc "All districts in a province, ordered by name."
  def list_districts(province_id) do
    Repo.all(
      from d in District,
        where: d.province_id == ^province_id,
        order_by: d.name
    )
  end

  def get_district(id), do: Repo.get(District, id)

  # ---------------------------------------------------------------------------
  # Local bodies
  # ---------------------------------------------------------------------------

  @doc "All local bodies in a district, ordered by name."
  def list_local_bodies(district_id) do
    Repo.all(
      from lb in LocalBody,
        where: lb.district_id == ^district_id,
        order_by: lb.name
    )
  end

  @doc """
  Searches local bodies by name prefix/substring across all districts.
  Also preloads the district + province for full label construction.
  Returns up to `limit` results (default 8).

  Used by the location picker search box.
  """
  def search_local_bodies(query, limit \\ 8) when is_binary(query) do
    q = "%#{String.downcase(query)}%"

    Repo.all(
      from lb in LocalBody,
        join: d in assoc(lb, :district),
        join: p in assoc(d, :province),
        where: ilike(lb.name, ^q) or ilike(lb.name_nepali, ^q),
        order_by: [
          # Prioritise service-available areas
          desc: lb.is_service_available,
          # Then metropolitan/sub-metropolitan first
          asc:
            fragment(
              "CASE ? WHEN 'metropolitan' THEN 1 WHEN 'sub_metropolitan' THEN 2 WHEN 'municipality' THEN 3 ELSE 4 END",
              lb.type
            ),
          asc: lb.name
        ],
        limit: ^limit,
        preload: [district: {d, province: p}]
    )
  end

  @doc """
  Finds the closest matching local body given GPS coordinates.
  Uses the district name from Nominatim's reverse-geocode response to look up
  a matching district, then returns all its local bodies for the picker.

  Returns `{:ok, [%LocalBody{}, ...]}` or `{:error, :not_found}`.
  """
  def local_bodies_near_district(district_name) when is_binary(district_name) do
    q = "%#{String.downcase(district_name)}%"

    results =
      Repo.all(
        from lb in LocalBody,
          join: d in assoc(lb, :district),
          join: p in assoc(d, :province),
          where: ilike(d.name, ^q),
          order_by: [desc: lb.is_service_available, asc: lb.name],
          preload: [district: {d, province: p}]
      )

    if results == [], do: {:error, :not_found}, else: {:ok, results}
  end

  @doc """
  Checks if QCommerce delivers to a given local body id.
  """
  def service_available?(local_body_id) do
    Repo.exists?(
      from lb in LocalBody,
        where: lb.id == ^local_body_id and lb.is_service_available == true
    )
  end

  # ---------------------------------------------------------------------------
  # Build a short display label for a LocalBody (used in the nav strip)
  # ---------------------------------------------------------------------------

  @doc """
  Returns a short location label for the navbar, e.g.:
    "Thamel, Kathmandu"       — when a ward/neighbourhood is known
    "Kathmandu Metropolitan"  — fallback from local body name
  """
  def short_label(%LocalBody{} = lb) do
    district_name =
      case lb.district do
        %District{name: n} -> n
        _ -> nil
      end

    if district_name do
      "#{lb.name}, #{district_name}"
    else
      lb.name
    end
  end

  def short_label(nil), do: "Choose location"
  def short_label(name) when is_binary(name), do: name
end
