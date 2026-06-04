# This file must live outside any module definition.
# Postgrex.Types.define/3 runs at compile time and generates a module
# that teaches Postgrex how to encode/decode PostGIS GEOGRAPHY/GEOMETRY
# column types as Elixir Geo structs (Geo.Point, Geo.Polygon, etc.)
#
# Correct API for Postgrex >= 0.17 + Ecto 3.x:
#   - Use Ecto.Adapters.Postgres.extensions() — NOT Postgrex.DefaultTypes.extensions()
#   - Pass json: Jason so geo_postgis uses Jason for GeoJSON casting
Postgrex.Types.define(
  Qcommerce.PostgresTypes,
  [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
  json: Jason
)
