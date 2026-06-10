# lib/qcommerce/admin/field_helper.ex
defmodule Qcommerce.Admin.FieldHelper do
  @moduledoc """
  Introspects Ecto schemas at runtime to auto-generate field metadata.
  Equivalent to Django's ModelAdmin field introspection.

  New in v2:
    - fieldset_fields/2        → segments fields into fieldset groups
    - inline_fields_for/1      → builds field metadata for an inline schema
    - prepopulate_js/1         → generates JS snippet for prepopulated_fields
    - format_value/3           → respects empty_value_display from config
    - badge_for/2              → returns CSS badge class for known status atoms
    - sortable?/1              → true if a field is safe to ORDER BY
    - filterable_fields/2      → replaces the version that was in resource_live
    - fetch_filter_options/2   → moved here from resource_live for reuse
    - assoc_label/1            → picks the human label out of a related record
  """

  alias Qcommerce.Repo
  import Ecto.Query, only: [from: 2, limit: 2, where: 2, dynamic: 2]

  # ---------------------------------------------------------------------------
  # Core — fields_for/1,2
  # ---------------------------------------------------------------------------

  @doc "Returns all field metadata for a schema module."
  def fields_for(schema_mod) do
    fields   = schema_mod.__schema__(:fields)
    required = required_fields(schema_mod)
    assocs   = assoc_mappings(schema_mod)

    Enum.map(fields, fn field ->
      type       = schema_mod.__schema__(:type, field)
      assoc      = Map.get(assocs, field)
      input_type = if assoc, do: :autocomplete, else: input_type_for(type, field)

      %{
        name:       field,
        type:       type,
        required:   field in required,
        virtual:    false,
        label:      humanize(field),
        input_type: input_type,
        assoc:      assoc
      }
    end)
  end

  @doc "Subset filtered to the given field name list, preserving order."
  def fields_for(schema_mod, field_names) do
    all = fields_for(schema_mod)

    Enum.map(field_names, fn name ->
      Enum.find(
        all,
        %{name: name, label: humanize(name), input_type: :text, type: :string, required: false, assoc: nil},
        &(&1.name == name)
      )
    end)
  end

  # ---------------------------------------------------------------------------
  # Fieldsets
  # ---------------------------------------------------------------------------

  @doc """
  Given the config's `fieldsets` option and the schema, returns a list of
  `{title, class_list, [field_meta]}` tuples ready for rendering.

  Falls back to a single unnamed fieldset with all form fields when no
  fieldsets are configured.
  """
  def fieldset_fields(schema_mod, config) do
    readonly = config.readonly_fields || []
    all_fields = fields_for(schema_mod)
    editable   = Enum.reject(all_fields, &(&1.name in readonly))

    case config.fieldsets do
      nil ->
        [{"", [], editable}]

      fieldsets ->
        Enum.map(fieldsets, fn {title, opts} ->
          names   = Map.get(opts, :fields, [])
          classes = Map.get(opts, :classes, [])
          fmeta   = fields_for(schema_mod, names)
                    |> Enum.reject(&(&1.name in readonly))
          {title, classes, fmeta}
        end)
    end
  end

  # ---------------------------------------------------------------------------
  # Inline formsets
  # ---------------------------------------------------------------------------

  @doc "Returns field metadata for an inline schema, excluding the FK field."
  def inline_fields_for(inline) do
    schema   = inline.schema
    fk_field = inline.fk_field
    allowed  = inline[:fields]

    all = fields_for(schema)
    filtered = Enum.reject(all, &(&1.name in [:id, fk_field, :inserted_at, :updated_at]))

    if allowed do
      fields_for(schema, allowed)
    else
      filtered
    end
  end

  @doc "Fetches existing inline records for a given parent record."
  def inline_records(inline, parent_id) do
    import Ecto.Query
    schema   = inline.schema
    fk_field = inline.fk_field

    try do
      Repo.all(from(r in schema, where: field(r, ^fk_field) == ^parent_id))
    rescue
      _ -> []
    end
  end

  # ---------------------------------------------------------------------------
  # Prepopulated fields JS
  # ---------------------------------------------------------------------------

  @doc """
  Generates a minimal JS snippet that populates a `slug` field by slugifying
  another field's value as the user types.

  Example output (for `prepopulated_fields: [slug: :name]`):
      document.addEventListener('DOMContentLoaded', function() {
        var src = document.getElementById('field_name');
        var dst = document.getElementById('field_slug');
        if (src && dst) {
          src.addEventListener('input', function() {
            dst.value = src.value.toLowerCase()
              .replace(/[^a-z0-9]+/g, '-')
              .replace(/(^-|-$)/g, '');
          });
        }
      });
  """
  def prepopulate_js([]), do: ""
  def prepopulate_js(prepopulated_fields) do
    snippets =
      Enum.map(prepopulated_fields, fn {dst, src} ->
        """
        (function() {
          var src = document.getElementById('field_#{src}');
          var dst = document.getElementById('field_#{dst}');
          if (src && dst && dst.value === '') {
            src.addEventListener('input', function() {
              dst.value = src.value.toLowerCase()
                .replace(/[^a-z0-9\\s-]/g, '')
                .trim()
                .replace(/[\\s]+/g, '-');
            });
          }
        })();
        """
      end)
      |> Enum.join("\n")

    "<script>document.addEventListener('DOMContentLoaded', function() { #{snippets} });</script>"
  end

  # ---------------------------------------------------------------------------
  # Display helpers
  # ---------------------------------------------------------------------------

  @doc "Format a value for display; respects empty_value_display from config."
  def format_value(value, config \\ nil)
  def format_value(nil, nil),    do: "—"
  def format_value(nil, config), do: config[:empty_value_display] || "—"
  def format_value(true, _),     do: {:safe, ~s(<span class="badge badge-green">Yes</span>)}
  def format_value(false, _),    do: {:safe, ~s(<span class="badge badge-red">No</span>)}
  def format_value(%DateTime{} = dt, _),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  def format_value(%NaiveDateTime{} = dt, _),
    do: NaiveDateTime.to_string(dt) |> String.slice(0, 16)
  def format_value(%Decimal{} = d, _),
    do: Decimal.to_string(d)
  def format_value(%Geo.Point{coordinates: {lng, lat}}, _),
    do: "#{Float.round(lat, 4)}, #{Float.round(lng, 4)}"
  def format_value(%{__struct__: _} = s, _),  do: inspect(s)
  def format_value(v, _) when is_atom(v),      do: Atom.to_string(v)
  def format_value(v, _) when is_binary(v) and byte_size(v) > 60,
    do: String.slice(v, 0, 60) <> "…"
  def format_value(v, _), do: to_string(v)

  @doc "Returns a CSS badge class for well-known status atoms."
  def badge_for(field_name, value) do
    cond do
      field_name in [:is_active, :is_available] and value == true  -> "badge-green"
      field_name in [:is_active, :is_available] and value == false -> "badge-red"
      field_name == :status ->
        case value do
          v when v in [:pending, :waiting]           -> "badge-yellow"
          v when v in [:delivered, :active, :done]   -> "badge-green"
          v when v in [:cancelled, :rejected, :failed] -> "badge-red"
          v when v in [:out_for_delivery, :confirmed, :dispatched] -> "badge-blue"
          _                                           -> "badge-gray"
        end
      field_name == :role -> "badge-purple"
      true -> "badge-gray"
    end
  end

  @doc "Returns true if the field is safe to use as an ORDER BY column."
  def sortable?(%{type: type}) do
    type in [:string, :integer, :float, :decimal, :boolean,
             :utc_datetime, :utc_datetime_usec, :naive_datetime, :date, :id]
  end
  def sortable?(_), do: false

  # ---------------------------------------------------------------------------
  # Humanize
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Enum values
  # ---------------------------------------------------------------------------

  @doc "Return enum values for a parameterized Ecto.Enum field."
  def enum_values(schema_mod, field) do
    case schema_mod.__schema__(:type, field) do
      {:parameterized, {Ecto.Enum, %{mappings: mappings}}} -> Keyword.keys(mappings)
      {:parameterized, Ecto.Enum, %{mappings: mappings}}   -> Keyword.keys(mappings)
      _ -> []
    end
  end

  # ---------------------------------------------------------------------------
  # Filter helpers (moved from ResourceLive for reuse)
  # ---------------------------------------------------------------------------

  @doc "Returns fields suitable for sidebar filtering."
  def filterable_fields(schema_mod, config_filters \\ []) do
    # Explicit filters from config take precedence
    if config_filters != [] do
      Enum.map(config_filters, fn {field, _type} ->
        all = fields_for(schema_mod)
        Enum.find(all, %{name: field, label: humanize(field), type: :string, input_type: :text, assoc: nil}, &(&1.name == field))
      end)
    else
      fields_for(schema_mod)
      |> Enum.filter(fn f ->
        f.type == :boolean or
        match?({:parameterized, {Ecto.Enum, _}}, f.type) or
        match?({:parameterized, Ecto.Enum, _}, f.type) or
        f.input_type == :autocomplete
      end)
    end
  end

  @doc "Returns filter options map: field_name_string → [{label, value}]"
  def fetch_filter_options(schema_mod, config_filters \\ []) do
    filterable_fields(schema_mod, config_filters)
    |> Map.new(fn f ->
      opts =
        cond do
          f.type == :boolean ->
            [{"Yes", "true"}, {"No", "false"}]

          match?({:parameterized, {Ecto.Enum, _}}, f.type) or
          match?({:parameterized, Ecto.Enum, _}, f.type) ->
            enum_values(schema_mod, f.name)
            |> Enum.map(fn val -> {String.capitalize(to_string(val)), to_string(val)} end)

          f.input_type == :autocomplete ->
            target_schema = f.assoc.schema
            try do
              Repo.all(from(x in target_schema, limit: 50))
              |> Enum.map(fn rec -> {assoc_label(rec), to_string(rec.id)} end)
            rescue
              _ -> []
            end

          true -> []
        end

      {to_string(f.name), opts}
    end)
  end

  # ---------------------------------------------------------------------------
  # Assoc label
  # ---------------------------------------------------------------------------

  @doc "Picks the human-readable label out of a related (assoc) record."
  def assoc_label(nil), do: ""
  def assoc_label(record) do
    cond do
      Map.has_key?(record, :name)      -> record.name
      Map.has_key?(record, :label)     -> record.label
      Map.has_key?(record, :title)     -> record.title
      Map.has_key?(record, :full_name) -> record.full_name
      Map.has_key?(record, :code)      -> "#{record.code}"
      Map.has_key?(record, :email)     -> record.email
      Map.has_key?(record, :sku)       -> "[#{record.sku}]"
      true                             -> "##{record.id}"
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp assoc_mappings(schema_mod) do
    schema_mod.__schema__(:associations)
    |> Enum.map(&schema_mod.__schema__(:association, &1))
    |> Enum.filter(&(&1.relationship == :parent))
    |> Map.new(fn assoc ->
      {assoc.owner_key, %{schema: assoc.queryable, assoc_name: assoc.field}}
    end)
  end

  defp input_type_for({:parameterized, {Ecto.Enum, _}}, _), do: :select
  defp input_type_for({:parameterized, Ecto.Enum, _}, _),   do: :select
  defp input_type_for(:boolean, _),                         do: :checkbox
  defp input_type_for(:decimal, _),                         do: :number
  defp input_type_for(:integer, _),                         do: :number
  defp input_type_for(:float, _),                           do: :number
  defp input_type_for(:utc_datetime, _),                    do: :datetime_local
  defp input_type_for(:utc_datetime_usec, _),               do: :datetime_local
  defp input_type_for(:naive_datetime, _),                  do: :datetime_local
  defp input_type_for(:date, _),                            do: :date
  defp input_type_for(:time, _),                            do: :time
  defp input_type_for(_, :email),                           do: :email
  defp input_type_for(_, :phone),                           do: :tel
  defp input_type_for(_, :description),                     do: :textarea
  defp input_type_for(_, :body),                            do: :textarea
  defp input_type_for(_, :notes),                           do: :textarea
  defp input_type_for(_, :content),                         do: :textarea
  defp input_type_for(_, :password),                        do: :password
  defp input_type_for(_, :password_hash),                   do: :password
  defp input_type_for(_, :image_url),                       do: :url
  defp input_type_for(_, :url),                             do: :url
  defp input_type_for(:binary, _),                          do: :text
  defp input_type_for(_, _),                                do: :text

  defp required_fields(schema_mod) do
    try do
      struct = struct(schema_mod)
      cs = schema_mod.changeset(struct, %{})
      cs.required
    rescue
      _ -> []
    end
  end
end
