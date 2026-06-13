# lib/qcommerce/admin/import_export.ex
defmodule Qcommerce.Admin.ImportExport do
  @moduledoc """
  Implements CSV parsing, data coercion, and database import (upsert, create_only, update_only)
  for Ecto models, similar to Django's import_export mixin.
  """

  alias Qcommerce.Repo
  alias Qcommerce.Admin.FieldHelper
  import Ecto.Query

  # ---------------------------------------------------------------------------
  # CSV Parser (State Machine)
  # ---------------------------------------------------------------------------

  def parse_csv(csv_content) do
    csv_content
    |> String.split(~r/\r?\n/)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_line/1)
  end

  def parse_line(line) do
    line
    |> String.to_charlist()
    |> do_parse_line([], [], false)
  end

  defp do_parse_line([], current, acc, _in_quotes) do
    Enum.reverse([Enum.reverse(current) |> List.to_string() | acc])
  end

  defp do_parse_line([?", ?" | rest], current, acc, true) do
    do_parse_line(rest, [?" | current], acc, true)
  end

  defp do_parse_line([?, | rest], current, acc, false) do
    val = Enum.reverse(current) |> List.to_string()
    do_parse_line(rest, [], [val | acc], false)
  end

  defp do_parse_line([?" | rest], current, acc, in_quotes) do
    do_parse_line(rest, current, acc, !in_quotes)
  end

  defp do_parse_line([char | rest], current, acc, in_quotes) do
    do_parse_line(rest, [char | current], acc, in_quotes)
  end

  # ---------------------------------------------------------------------------
  # Import Runner
  # ---------------------------------------------------------------------------

  def import_csv(schema_mod, csv_content, import_mode, unique_keys) do
    case parse_csv(csv_content) do
      [] ->
        {:error, "The CSV file is empty."}

      [headers | rows] ->
        # headers is a list of strings: ["name", "sku", "category__slug", ...]
        # Map each row to a map of column -> value
        results =
          Enum.reduce(rows, %{created: 0, updated: 0, skipped: 0, failed: 0, errors: []}, fn row_cells, acc ->
            # Pad row_cells to headers length in case row is short
            padded_cells = row_cells ++ List.duplicate("", max(0, length(headers) - length(row_cells)))
            row_map = Enum.zip(headers, padded_cells) |> Map.new()
            
            # Check if row is completely empty
            if Enum.all?(Map.values(row_map), &(&1 == "")) do
              acc
            else
              case import_row(schema_mod, row_map, import_mode, unique_keys) do
                {:ok, :created} ->
                  %{acc | created: acc.created + 1}

                {:ok, :updated} ->
                  %{acc | updated: acc.updated + 1}

                {:ok, :skipped} ->
                  %{acc | skipped: acc.skipped + 1}

                {:error, error_msg} ->
                  %{acc | failed: acc.failed + 1, errors: acc.errors ++ [error_msg]}
              end
            end
          end)

        {:ok, results}
    end
  end

  # ---------------------------------------------------------------------------
  # Row Import Logic
  # ---------------------------------------------------------------------------

  def import_row(schema_mod, row_map, import_mode, unique_keys) do
    try do
      coerced_data = coerce_row(schema_mod, row_map)
      
      # Build the Ecto query to check for existing record using unique keys
      existing_record =
        if unique_keys != [] do
          # Build a query where unique_keys match coerced_data
          query =
            Enum.reduce(unique_keys, schema_mod, fn key_str, query_acc ->
              key_atom = String.to_existing_atom(key_str)
              val = Map.get(coerced_data, key_str)
              where(query_acc, [r], field(r, ^key_atom) == ^val)
            end)
          
          Repo.one(query)
        else
          nil
        end

      cs_fn = fn struct, params ->
        if function_exported?(schema_mod, :changeset, 2),
          do: schema_mod.changeset(struct, params),
          else: Ecto.Changeset.cast(struct, params, schema_mod.__schema__(:fields))
      end

      case {import_mode, existing_record} do
        {"create_only", record} when not is_nil(record) ->
          {:ok, :skipped}

        {"create_only", _} ->
          # Create new record
          changeset = cs_fn.(struct(schema_mod), coerced_data)
          case Repo.insert(changeset) do
            {:ok, _} -> {:ok, :created}
            {:error, cs} -> {:error, format_errors(cs)}
          end

        {"update_only", nil} ->
          {:ok, :skipped}

        {"update_only", record} ->
          # Update existing record
          changeset = cs_fn.(record, coerced_data)
          case Repo.update(changeset) do
            {:ok, _} -> {:ok, :updated}
            {:error, cs} -> {:error, format_errors(cs)}
          end

        {"upsert", nil} ->
          # Create new record
          changeset = cs_fn.(struct(schema_mod), coerced_data)
          case Repo.insert(changeset) do
            {:ok, _} -> {:ok, :created}
            {:error, cs} -> {:error, format_errors(cs)}
          end

        {"upsert", record} ->
          # Update existing record
          changeset = cs_fn.(record, coerced_data)
          case Repo.update(changeset) do
            {:ok, _} -> {:ok, :updated}
            {:error, cs} -> {:error, format_errors(cs)}
          end
      end
    rescue
      exc ->
        {:error, "Row processing error: #{Exception.message(exc)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Row Coercion & Association Resolver
  # ---------------------------------------------------------------------------

  def coerce_row(schema_mod, row_map) do
    # 1. Resolve nested associations (e.g. category__slug)
    resolved_assocs =
      Enum.reduce(row_map, %{}, fn {col, val}, acc ->
        if String.contains?(col, "__") do
          [assoc_name_str, lookup_field_str] = String.split(col, "__", parts: 2)
          assoc_atom = String.to_existing_atom(assoc_name_str)
          
          assoc_info = schema_mod.__schema__(:association, assoc_atom)
          if assoc_info && val != "" && val != nil do
            related_schema = assoc_info.queryable
            lookup_field_atom = String.to_existing_atom(lookup_field_str)
            
            case Repo.get_by(related_schema, [{lookup_field_atom, val}]) do
              nil ->
                raise "Related #{related_schema} with #{lookup_field_str}='#{val}' not found."
              related_record ->
                Map.put(acc, to_string(assoc_info.owner_key), related_record.id)
            end
          else
            acc
          end
        else
          acc
        end
      end)

    # 2. Build map of direct fields and coerce them
    Enum.reduce(row_map, %{}, fn {col, val}, acc ->
      if String.contains?(col, "__") do
        acc
      else
        try do
          field_atom = String.to_existing_atom(col)
          if field_atom in schema_mod.__schema__(:fields) do
            type = schema_mod.__schema__(:type, field_atom)
            coerced_val = coerce_val(type, val)
            Map.put(acc, col, coerced_val)
          else
            acc
          end
        rescue
          _ -> acc
        end
      end
    end)
    |> Map.merge(resolved_assocs)
  end

  def coerce_val(_type, nil), do: nil
  def coerce_val(_type, ""), do: nil

  def coerce_val(:integer, val) do
    case Integer.parse(val) do
      {int, _} -> int
      _ ->
        case Float.parse(val) do
          {fl, _} -> trunc(fl)
          _ -> nil
        end
    end
  end

  def coerce_val(:float, val) do
    case Float.parse(val) do
      {fl, _} -> fl
      _ -> nil
    end
  end

  def coerce_val(:decimal, val) do
    case Decimal.cast(val) do
      {:ok, dec} -> dec
      _ -> nil
    end
  end

  def coerce_val(:boolean, val) do
    case String.downcase(String.trim(val)) do
      v when v in ["true", "1", "yes", "y", "t", "active"] -> true
      _ -> false
    end
  end

  def coerce_val(:date, val) do
    case Date.from_iso8601(val) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def coerce_val(:utc_datetime, val) do
    case DateTime.from_iso8601(val) do
      {:ok, dt, _} -> dt
      _ ->
        case NaiveDateTime.from_iso8601(val) do
          {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
          _ -> nil
        end
    end
  end

  def coerce_val(:naive_datetime, val) do
    case NaiveDateTime.from_iso8601(val) do
      {:ok, ndt} -> ndt
      _ -> nil
    end
  end

  def coerce_val(_, val), do: val

  # ---------------------------------------------------------------------------
  # Sample CSV Generator
  # ---------------------------------------------------------------------------

  def sample_csv(schema_mod) do
    fields = schema_mod.__schema__(:fields)
    exclude = [:id, :inserted_at, :updated_at, :password_hash]
    
    assocs =
      schema_mod.__schema__(:associations)
      |> Enum.map(&schema_mod.__schema__(:association, &1))
      |> Enum.filter(&(&1.relationship == :parent))
      |> Map.new(fn assoc -> {assoc.owner_key, assoc.field} end)

    headers =
      Enum.flat_map(fields, fn f ->
        cond do
          f in exclude ->
            []

          Map.has_key?(assocs, f) ->
            assoc_name = Map.get(assocs, f)
            related_schema = schema_mod.__schema__(:association, assoc_name).queryable
            related_fields = related_schema.__schema__(:fields)
            lookup =
              Enum.find([:code, :sku, :slug, :email, :name, :id], fn rf -> rf in related_fields end)
            
            ["#{assoc_name}__#{lookup}"]

          true ->
            [to_string(f)]
        end
      end)
      |> Enum.join(",")

    headers <> "\n\n"
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
    |> Enum.map(fn {field, msgs} ->
      "#{FieldHelper.humanize(field)}: #{Enum.join(msgs, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
