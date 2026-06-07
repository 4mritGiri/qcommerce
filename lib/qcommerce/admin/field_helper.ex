# lib/qcommerce/admin/field_helper.ex
defmodule Qcommerce.Admin.FieldHelper do
  @moduledoc """
  Introspects Ecto schemas at runtime to auto-generate field metadata.
  Equivalent to Django's ModelAdmin field introspection.
  """

  @doc "Returns all field metadata for a schema module."
  def fields_for(schema_mod) do
    fields   = schema_mod.__schema__(:fields)
    required = required_fields(schema_mod)

    Enum.map(fields, fn field ->
      type = schema_mod.__schema__(:type, field)
      %{
        name:       field,
        type:       type,
        required:   field in required,
        virtual:    false,
        label:      humanize(field),
        input_type: input_type_for(type, field)
      }
    end)
  end

  @doc "Subset filtered to the given field name list, preserving order."
  def fields_for(schema_mod, field_names) do
    all = fields_for(schema_mod)
    Enum.map(field_names, fn name ->
      Enum.find(all, %{name: name, label: humanize(name), input_type: :text, type: :string, required: false},
        &(&1.name == name))
    end)
  end

  @doc "Format a value for display in the list view."
  def format_value(nil),                do: "—"
  def format_value(true),               do: "✅"
  def format_value(false),              do: "❌"
  def format_value(%DateTime{} = dt),   do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  def format_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_string(dt) |> String.slice(0, 16)
  def format_value(%Decimal{} = d),     do: Decimal.to_string(d)
  def format_value(%Geo.Point{coordinates: {lng, lat}}), do: "#{Float.round(lat, 4)}, #{Float.round(lng, 4)}"
  def format_value(%{__struct__: _} = s), do: inspect(s)
  def format_value(v) when is_atom(v),  do: Atom.to_string(v)
  def format_value(v) when is_binary(v) and byte_size(v) > 60, do: String.slice(v, 0, 60) <> "…"
  def format_value(v),                  do: to_string(v)

  @doc "Humanize a field atom to a display label."
  def humanize(field) when is_atom(field) do
    field |> Atom.to_string() |> humanize()
  end
  def humanize(str) when is_binary(str) do
    str
    |> String.replace("_id", "")
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Return enum values for a parameterized Ecto.Enum field.
  Handles both Ecto 3.9 and 3.11+ parameterized type structures.
  """
  def enum_values(schema_mod, field) do
    case schema_mod.__schema__(:type, field) do
      # Ecto 3.11+ format
      {:parameterized, {Ecto.Enum, %{mappings: mappings}}} ->
        Keyword.keys(mappings)
      # Ecto 3.9-3.10 format
      {:parameterized, Ecto.Enum, %{mappings: mappings}} ->
        Keyword.keys(mappings)
      _ ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp input_type_for({:parameterized, {Ecto.Enum, _}}, _), do: :select
  defp input_type_for({:parameterized, Ecto.Enum, _}, _),   do: :select
  defp input_type_for(:boolean, _),                          do: :checkbox
  defp input_type_for(:decimal, _),                          do: :number
  defp input_type_for(:integer, _),                          do: :number
  defp input_type_for(:float, _),                            do: :number
  defp input_type_for(:utc_datetime, _),                     do: :datetime_local
  defp input_type_for(:utc_datetime_usec, _),                do: :datetime_local
  defp input_type_for(:naive_datetime, _),                   do: :datetime_local
  defp input_type_for(:date, _),                             do: :date
  defp input_type_for(:time, _),                             do: :time
  defp input_type_for(_, :email),                            do: :email
  defp input_type_for(_, :phone),                            do: :tel
  defp input_type_for(_, :description),                      do: :textarea
  defp input_type_for(_, :body),                             do: :textarea
  defp input_type_for(_, :notes),                            do: :textarea
  defp input_type_for(_, :password),                         do: :password
  defp input_type_for(_, :password_hash),                    do: :password
  defp input_type_for(_, :image_url),                        do: :url
  defp input_type_for(_, :url),                              do: :url
  # Binary fields (passkeys, etc.) — show as read-only text
  defp input_type_for(:binary, _),                           do: :text
  defp input_type_for(_, _),                                 do: :text

  defp required_fields(schema_mod) do
    try do
      struct = struct(schema_mod)
      cs = schema_mod.changeset(struct, %{})
      cs.required
    rescue
      # Catch any error — FunctionClauseError, ArgumentError, etc.
      _ -> []
    end
  end
end
