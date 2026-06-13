# lib/qcommerce_web/live/admin/resource_live.ex
#
# Generic CRUD LiveView — auto-generates list, show, new, edit from the
# registered admin config + Ecto schema introspection.
#
# URL pattern:
#   /admin/r/:resource              → :list
#   /admin/r/:resource/new          → :new
#   /admin/r/:resource/:id          → :show
#   /admin/r/:resource/:id/edit     → :edit

defmodule QcommerceWeb.Admin.ResourceLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.{Repo, Admin.Registry, Admin.FieldHelper}
  alias Qcommerce.Accounts.User

  import Ecto.Query

  # ---------------------------------------------------------------------------
  # Mount — auth guard + registry lookup
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"resource" => slug} = _params, session, socket) do
    user_id = session["user_id"]
    user    = user_id && Repo.get(User, user_id)

    allowed_roles = [:super_admin, :manager, :staff]

    cond do
      is_nil(user) or user.role not in allowed_roles ->
        {:ok, push_navigate(socket, to: "/")}

      true ->
        config = Registry.get(slug)

        cond do
          is_nil(config) ->
            {:ok,
             socket
             |> put_flash(:error, "Model '#{slug}' is not registered.")
             |> push_navigate(to: "/admin")}

          user.role not in (config[:roles] || [:super_admin]) ->
            {:ok,
             socket
             |> put_flash(:error, "You don't have permission to access this resource.")
             |> push_navigate(to: "/admin")}

          true ->
            {:ok,
             socket
             |> assign(:current_user, user)
             |> assign(:config, config)
             |> assign(:resource_slug, Registry.schema_to_slug(config.schema))
             |> assign(:admin_resource, config.schema)
             |> assign(:delete_confirm_id, nil)
             |> assign(:show_import_modal, false)
             |> assign(:show_export_modal, false)
             |> assign(:import_mode, "upsert")
             |> assign(:import_unique_keys, [])
             |> assign(:import_errors, [])
             |> assign(:import_result, nil)
             |> assign(:export_selected_fields, [])
             |> allow_upload(:import_file, accept: ~w(.csv), max_entries: 1)}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # handle_params — primary driver
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(params, _uri, socket) do
    if config = socket.assigns[:config] do
      {:noreply, load_page(socket, config, socket.assigns.live_action, params)}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Page loaders
  # ---------------------------------------------------------------------------

  defp load_page(socket, config, action, params) do
    q    = params["q"] || ""
    page = String.to_integer(params["page"] || "1")

    # Django-style multi-column sort via `o` param (e.g. "1.-2.3")
    # Fall back to legacy sort_by/sort_dir for backwards compat
    sort_orders =
      case params["o"] do
        nil_or_empty when nil_or_empty in [nil, ""] ->
          # Build from legacy or config default
          legacy_by  = params["sort_by"]  || default_sort_field(config)
          legacy_dir = params["sort_dir"] || default_sort_dir(config)
          [{legacy_by, legacy_dir}]
        o_str ->
          parse_o_param(o_str, config)
      end

    # Legacy single sort aliases (kept for template assigns)
    {sort_by, sort_dir} = List.first(sort_orders) || {"id", "desc"}

    filter_names = FieldHelper.filterable_fields(config.schema, config.filters)
                   |> Enum.map(&to_string(&1.name))
    filters = Map.take(params, filter_names)

    date_drill = %{
      "year"  => params["year"],
      "month" => params["month"],
      "day"   => params["day"]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    base =
      socket
      |> assign(:action, action)
      |> assign(:search, q)
      |> assign(:page, page)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:sort_orders, sort_orders)
      |> assign(:filters, filters)
      |> assign(:date_drill, date_drill)

    case action do
      :list -> load_list(base, config, params)
      :show -> load_record(base, config, params["id"])
      :edit -> load_edit(base, config, params["id"])
      :new  -> load_new(base, config)
    end
  end

  defp default_sort_field(config) do
    case config.ordering do
      [first | _] -> first |> to_string() |> String.trim_leading("-")
      _ -> "id"
    end
  end

  defp default_sort_dir(config) do
    case config.ordering do
      [first | _] -> if String.starts_with?(to_string(first), "-"), do: "desc", else: "asc"
      _ -> "desc"
    end
  end

  defp per_page(config), do: Map.get(config, :list_per_page, 25)

  defp load_list(socket, config, _params) do
    q          = socket.assigns.search    || ""
    page       = socket.assigns.page      || 1
    sort_orders = socket.assigns[:sort_orders] || [{socket.assigns[:sort_by] || "id", socket.assigns[:sort_dir] || "desc"}]
    filters    = socket.assigns.filters   || %{}
    date_drill = socket.assigns.date_drill || %{}

    pp = per_page(config)
    {records, total} = fetch_list_multi(config, q, page, sort_orders, filters, date_drill, pp)
    filter_opts = FieldHelper.fetch_filter_options(config.schema, config.filters)
    slug = socket.assigns.resource_slug

    existing_open   = socket.assigns[:filter_open]   || %{}
    existing_search = socket.assigns[:filter_search] || %{}
    filter_open   = Map.new(filter_opts, fn {k, _} -> {k, Map.get(existing_open,   k, false)} end)
    filter_search = Map.new(filter_opts, fn {k, _} -> {k, Map.get(existing_search, k, "")} end)

    # Date hierarchy counts for current level
    date_counts =
      if config.date_hierarchy do
        build_date_hierarchy_counts(config, date_drill)
      else
        []
      end

    socket
    |> assign(:page_title,    config.label)
    |> assign(:breadcrumb,    [{"Admin", "/admin"}, {config.label, nil}])
    |> assign(:records,       records)
    |> assign(:total,         total)
    |> assign(:per_page,      pp)
    |> assign(:total_pages,   max(1, ceil(total / pp)))
    |> assign(:list_fields,   FieldHelper.fields_for(config.schema, config.list_fields))
    |> assign(:filter_options, filter_opts)
    |> assign(:filter_open,   filter_open)
    |> assign(:filter_search, filter_search)
    |> assign(:selected_ids,  socket.assigns[:selected_ids] || [])
    |> assign(:resource_slug, slug)
    |> assign(:date_counts,   date_counts)
  end

  defp load_record(socket, config, id) do
    record     = Repo.get(config.schema, id)
    all_fields = FieldHelper.fields_for(config.schema)
    slug       = socket.assigns.resource_slug

    socket
    |> assign(:page_title, "#{config.label} ##{id}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"##{id}", nil}])
    |> assign(:record, record)
    |> assign(:all_fields, all_fields)
  end

  defp load_edit(socket, config, id) do
    record     = Repo.get!(config.schema, id)
    fieldsets  = FieldHelper.fieldset_fields(config.schema, config)
    slug       = socket.assigns.resource_slug
    inlines    = load_inlines(config, record.id)

    socket
    |> assign(:page_title,       "Edit #{config.label} ##{id}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"Edit ##{id}", nil}])
    |> assign(:record,           record)
    |> assign(:fieldsets,        fieldsets)
    |> assign(:inlines,          inlines)
    |> assign(:changeset_errors, %{})
    |> assign(:collapsed_fieldsets, [])
    |> init_autocomplete(flat_form_fields(fieldsets), record)
  end

  defp load_new(socket, config) do
    fieldsets = FieldHelper.fieldset_fields(config.schema, config)
    slug      = socket.assigns.resource_slug
    record    = struct(config.schema)

    socket
    |> assign(:page_title,       "New #{config.label_singular}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"New", nil}])
    |> assign(:record,           record)
    |> assign(:fieldsets,        fieldsets)
    |> assign(:inlines,          [])
    |> assign(:changeset_errors, %{})
    |> assign(:collapsed_fieldsets, [])
    |> init_autocomplete(flat_form_fields(fieldsets), record)
  end

  # Flatten fieldsets → list of fields
  defp flat_form_fields(fieldsets) do
    Enum.flat_map(fieldsets, fn {_title, _classes, fields} -> fields end)
  end

  defp load_inlines(config, parent_id) do
    Enum.map(config.inlines, fn inline ->
      records = FieldHelper.inline_records(inline, parent_id)
      fields  = FieldHelper.inline_fields_for(inline)
      %{inline: inline, records: records, fields: fields, new_rows: inline[:extra] || 1}
    end)
  end

  # ---------------------------------------------------------------------------
  # Data fetching
  # ---------------------------------------------------------------------------


  defp fetch_list_multi(config, q, page, sort_orders, filters, date_drill, pp) do
    base =
      from(r in config.schema)
      |> maybe_search(config, q)
      |> maybe_filter(config.schema, filters)
      |> maybe_date_drill(config, date_drill)

    total = Repo.aggregate(base, :count)

    offset_val = (page - 1) * pp

    # Build order_by by reducing each sort column
    ordered_query =
      Enum.reduce(sort_orders, base, fn {field_str, dir_str}, query ->
        f   = String.to_atom(field_str)
        dir = String.to_atom(dir_str)
        order_by(query, [r], [{^dir, field(r, ^f)}])
      end)

    records =
      ordered_query
      |> limit(^pp)
      |> offset(^offset_val)
      |> Repo.all()

    {records, total}
  end

  defp maybe_search(query, _config, ""),  do: query
  defp maybe_search(query, _config, nil), do: query
  defp maybe_search(query, config, q) do
    fields = config.search_fields
    if fields == [] do
      query
    else
      like_q = "%#{q}%"
      conditions = Enum.reduce(fields, false, fn f, acc ->
        dynamic([r], ilike(field(r, ^f), ^like_q) or ^acc)
      end)
      where(query, ^conditions)
    end
  end

  defp maybe_filter(query, schema_mod, filters) do
    Enum.reduce(filters, query, fn {field_str, val}, q_acc ->
      if val == "" or val == nil do
        q_acc
      else
        field_atom = String.to_atom(field_str)
        type = schema_mod.__schema__(:type, field_atom)

        cond do
          type == :boolean ->
            bool_val = val == "true"
            where(q_acc, [r], field(r, ^field_atom) == ^bool_val)

          match?({:parameterized, {Ecto.Enum, _}}, type) or
          match?({:parameterized, Ecto.Enum, _}, type) ->
            enum_val = String.to_atom(val)
            where(q_acc, [r], field(r, ^field_atom) == ^enum_val)

          true ->
            # Try integer parse for FK fields
            case Integer.parse(val) do
              {int_val, ""} -> where(q_acc, [r], field(r, ^field_atom) == ^int_val)
              _             -> where(q_acc, [r], field(r, ^field_atom) == ^val)
            end
        end
      end
    end)
  end

  defp maybe_date_drill(query, _config, date_drill) when map_size(date_drill) == 0, do: query
  defp maybe_date_drill(query, config, date_drill) do
    field_atom = config.date_hierarchy
    if is_nil(field_atom), do: query, else: apply_date_drill(query, field_atom, date_drill)
  end

  defp apply_date_drill(query, field_atom, %{"year" => y, "month" => m, "day" => d}) do
    year  = String.to_integer(y)
    month = String.to_integer(m)
    day   = String.to_integer(d)
    where(query, [r],
      fragment("extract(year  from ?)::int", field(r, ^field_atom)) == ^year and
      fragment("extract(month from ?)::int", field(r, ^field_atom)) == ^month and
      fragment("extract(day   from ?)::int", field(r, ^field_atom)) == ^day
    )
  end
  defp apply_date_drill(query, field_atom, %{"year" => y, "month" => m}) do
    year  = String.to_integer(y)
    month = String.to_integer(m)
    where(query, [r],
      fragment("extract(year  from ?)::int", field(r, ^field_atom)) == ^year and
      fragment("extract(month from ?)::int", field(r, ^field_atom)) == ^month
    )
  end
  defp apply_date_drill(query, field_atom, %{"year" => y}) do
    year = String.to_integer(y)
    where(query, [r],
      fragment("extract(year from ?)::int", field(r, ^field_atom)) == ^year
    )
  end
  defp apply_date_drill(query, _, _), do: query

  defp build_date_hierarchy_counts(config, date_drill) do
    field_atom = config.date_hierarchy
    _base = from(r in config.schema)

    try do
      cond do
        map_size(date_drill) == 0 ->
          # Year level
          Repo.all(
            from r in config.schema,
            group_by: fragment("extract(year from ?)::int", field(r, ^field_atom)),
            select: {fragment("extract(year from ?)::int", field(r, ^field_atom)), count(r.id)},
            order_by: fragment("extract(year from ?)::int", field(r, ^field_atom))
          )
          |> Enum.map(fn {y, c} -> {:year, y, c} end)

        Map.has_key?(date_drill, "year") and not Map.has_key?(date_drill, "month") ->
          y = String.to_integer(date_drill["year"])
          Repo.all(
            from r in config.schema,
            where: fragment("extract(year from ?)::int", field(r, ^field_atom)) == ^y,
            group_by: fragment("extract(month from ?)::int", field(r, ^field_atom)),
            select: {fragment("extract(month from ?)::int", field(r, ^field_atom)), count(r.id)},
            order_by: fragment("extract(month from ?)::int", field(r, ^field_atom))
          )
          |> Enum.map(fn {m, c} -> {:month, m, c} end)

        true -> []
      end
    rescue
      _ -> []
    end
  end

  # ---------------------------------------------------------------------------
  # Autocomplete helpers
  # ---------------------------------------------------------------------------

  defp init_autocomplete(socket, form_fields, record) do
    autocompletes = Enum.filter(form_fields, &(&1.input_type == :autocomplete))

    {searches, results, selected} =
      Enum.reduce(autocompletes, {%{}, %{}, %{}}, fn field, {s_acc, r_acc, sel_acc} ->
        initial_list  = Repo.all(from(x in field.assoc.schema, limit: 10))
        current_val   = Map.get(record || %{}, field.name)
        selected_rec  = if current_val, do: Repo.get(field.assoc.schema, current_val), else: nil

        {
          Map.put(s_acc,   to_string(field.name), ""),
          Map.put(r_acc,   to_string(field.name), initial_list),
          Map.put(sel_acc, to_string(field.name), selected_rec)
        }
      end)

    socket
    |> assign(:autocomplete_search,   searches)
    |> assign(:autocomplete_results,  results)
    |> assign(:autocomplete_selected, selected)
    |> assign(:autocomplete_open,     Map.new(autocompletes, &{to_string(&1.name), false}))
  end

  # ---------------------------------------------------------------------------
  # Event Handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: current_path(socket, %{"q" => q, "page" => "1"}))}
  end

  def handle_event("page", %{"p" => p}, socket) do
    {:noreply, push_patch(socket, to: current_path(socket, %{"page" => to_string(p)}))}
  end

  def handle_event("sort", %{"field" => field_name, "multi" => "true"}, socket) do
    # Multi-sort: append/cycle/remove this field in the sort_orders list
    orders = socket.assigns[:sort_orders] || [{socket.assigns.sort_by, socket.assigns.sort_dir}]
    new_orders =
      case Enum.find_index(orders, fn {f, _} -> f == field_name end) do
        nil ->
          # Not in list — add as asc at end
          orders ++ [{field_name, "asc"}]
        idx ->
          {_, cur_dir} = Enum.at(orders, idx)
          if cur_dir == "asc" do
            # asc → desc
            List.replace_at(orders, idx, {field_name, "desc"})
          else
            # desc → remove
            List.delete_at(orders, idx)
          end
      end
    new_orders = if new_orders == [], do: [{"id", "desc"}], else: new_orders
    o_str = encode_o_param(new_orders, socket.assigns.list_fields)
    {:noreply, push_patch(socket, to: current_path(socket, %{"o" => o_str, "page" => "1"}))}
  end

  def handle_event("sort", %{"field" => field_name}, socket) do
    # Single-sort: replace entire sort with just this field (Django default click)
    orders = socket.assigns[:sort_orders] || []
    new_orders =
      case Enum.find(orders, fn {f, _} -> f == field_name end) do
        nil              -> [{field_name, "asc"}]
        {_, "asc"}  -> [{field_name, "desc"}]
        {_, "desc"} -> [{field_name, "asc"}]
      end
    o_str = encode_o_param(new_orders, socket.assigns.list_fields)
    {:noreply, push_patch(socket, to: current_path(socket, %{"o" => o_str, "page" => "1"}))}
  end

  # Filter dropdown
  def handle_event("filter_toggle", %{"field" => field_name}, socket) do
    current  = Map.get(socket.assigns.filter_open, field_name, false)
    new_open = socket.assigns.filter_open
               |> Map.new(fn {k, _} -> {k, false} end)
               |> Map.put(field_name, !current)
    {:noreply, assign(socket, :filter_open, new_open)}
  end

  def handle_event("filter_search", %{"field" => field_name, "value" => q}, socket) do
    {:noreply, assign(socket, :filter_search, Map.put(socket.assigns.filter_search, field_name, q))}
  end

  def handle_event("filter_pick", %{"field" => field_name, "value" => val}, socket) do
    new_filters =
      if val == "",
        do:   Map.delete(socket.assigns.filters, field_name),
        else: Map.put(socket.assigns.filters, field_name, val)

    new_open   = Map.put(socket.assigns.filter_open,   field_name, false)
    new_search = Map.put(socket.assigns.filter_search, field_name, "")

    slug     = socket.assigns.resource_slug
    sort_by  = socket.assigns.sort_by
    sort_dir = socket.assigns.sort_dir
    q        = socket.assigns.search

    query_params =
      %{"q" => q, "page" => "1", "sort_by" => sort_by, "sort_dir" => sort_dir}
      |> Map.merge(new_filters)
      |> URI.encode_query()

    socket =
      socket
      |> assign(:filter_open,   new_open)
      |> assign(:filter_search, new_search)
      |> assign(:filters,       new_filters)

    {:noreply, push_patch(socket, to: "/admin/r/#{slug}?#{query_params}")}
  end

  def handle_event("filter_clear_all", _params, socket) do
    slug = socket.assigns.resource_slug
    {:noreply, push_patch(socket, to: "/admin/r/#{slug}")}
  end

  # Date hierarchy
  def handle_event("date_drill", params, socket) do
    slug = socket.assigns.resource_slug
    drill_params = Map.take(params, ["year", "month", "day"])
    query = Map.merge(%{"page" => "1"}, drill_params) |> URI.encode_query()
    {:noreply, push_patch(socket, to: "/admin/r/#{slug}?#{query}")}
  end

  # Bulk selection
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id_str   = to_string(id)
    selected = socket.assigns.selected_ids
    new_sel  = if id_str in selected, do: List.delete(selected, id_str), else: [id_str | selected]
    {:noreply, assign(socket, :selected_ids, new_sel)}
  end

  def handle_event("toggle_select_all", _params, socket) do
    all_ids    = Enum.map(socket.assigns.records, &to_string(&1.id))
    selected   = socket.assigns.selected_ids
    all_sel?   = Enum.all?(all_ids, &(&1 in selected))
    new_sel    = if all_sel?, do: selected -- all_ids, else: Enum.uniq(selected ++ all_ids)
    {:noreply, assign(socket, :selected_ids, new_sel)}
  end

  # Built-in bulk delete
  def handle_event("bulk_action", %{"action" => "delete"}, socket) do
    config = socket.assigns.config
    ids    = socket.assigns.selected_ids

    case Repo.delete_all(from(r in config.schema, where: r.id in ^ids)) do
      {count, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deleted #{count} record(s).")
         |> assign(:selected_ids, [])
         |> push_patch(to: current_path(socket, %{"page" => "1"}))}

      _ ->
        {:noreply, put_flash(socket, :error, "Bulk delete failed.")}
    end
  end

  # Custom bulk actions
  def handle_event("bulk_action", %{"action" => "export_csv"}, socket) do
    config  = socket.assigns.config
    records = socket.assigns.records
    fields  = socket.assigns.list_fields

    csv_content = build_csv(records, fields)
    filename    = "#{config.label |> String.downcase() |> String.replace(" ", "_")}_export.csv"

    {:noreply,
     socket
     |> push_event("download_csv", %{content: csv_content, filename: filename})
     |> put_flash(:info, "CSV download triggered.")}
  end

  def handle_event("bulk_action", %{"action" => action_id}, socket) do
    config  = socket.assigns.config
    ids     = socket.assigns.selected_ids
    schema  = config.schema

    result =
      case action_id do
        "mark_active" ->
          Repo.update_all(from(r in schema, where: r.id in ^ids), set: [is_active: true])
          {:ok, "Marked #{length(ids)} record(s) active."}

        "mark_inactive" ->
          Repo.update_all(from(r in schema, where: r.id in ^ids), set: [is_active: false])
          {:ok, "Marked #{length(ids)} record(s) inactive."}

        "activate_users" ->
          Repo.update_all(from(r in schema, where: r.id in ^ids), set: [is_active: true])
          {:ok, "Activated #{length(ids)} user(s)."}

        "deactivate_users" ->
          Repo.update_all(from(r in schema, where: r.id in ^ids), set: [is_active: false])
          {:ok, "Deactivated #{length(ids)} user(s)."}

        _ ->
          {:error, "Unknown action: #{action_id}"}
      end

    case result do
      {:ok, msg} ->
        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> assign(:selected_ids, [])
         |> push_patch(to: current_path(socket, %{}))}

      {:error, msg} ->
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  # Fieldset collapse toggle
  def handle_event("toggle_fieldset", %{"title" => title}, socket) do
    collapsed = socket.assigns[:collapsed_fieldsets] || []
    new_collapsed =
      if title in collapsed,
        do:   List.delete(collapsed, title),
        else: [title | collapsed]
    {:noreply, assign(socket, :collapsed_fieldsets, new_collapsed)}
  end

  # Delete confirmation modal
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_confirm_id, id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_confirm_id, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    config = socket.assigns.config
    record = Repo.get!(config.schema, id)

    case Repo.delete(record) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:delete_confirm_id, nil)
         |> put_flash(:info, "Record ##{id} deleted.")
         |> push_navigate(to: "/admin/r/#{socket.assigns.resource_slug}")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:delete_confirm_id, nil)
         |> put_flash(:error, "Could not delete record ##{id} — it may have dependent records.")}
    end
  end

  # Autocomplete
  def handle_event("autocomplete_toggle", %{"field" => field_name}, socket) do
    open    = socket.assigns.autocomplete_open
    current = Map.get(open, field_name, false)
    {:noreply, assign(socket, :autocomplete_open, Map.put(open, field_name, !current))}
  end

  def handle_event("autocomplete_search", %{"field" => field_name, "value" => query}, socket) do
    all_fields = flat_form_fields(socket.assigns.fieldsets)
    field      = Enum.find(all_fields, &(to_string(&1.name) == field_name))

    if field do
      target_schema   = field.assoc.schema
      schema_fields   = target_schema.__schema__(:fields)
      searchable      = Enum.filter([:name, :title, :full_name, :code, :email, :sku], &(&1 in schema_fields))

      q = from(x in target_schema) |> limit(10)

      matching_query =
        if query != "" and searchable != [] do
          like_q     = "%#{query}%"
          conditions = Enum.reduce(searchable, false, fn f, acc ->
            dynamic([x], ilike(field(x, ^f), ^like_q) or ^acc)
          end)
          where(q, ^conditions)
        else
          q
        end

      results = Repo.all(matching_query)

      {:noreply,
       socket
       |> assign(:autocomplete_search,  Map.put(socket.assigns.autocomplete_search,  field_name, query))
       |> assign(:autocomplete_results, Map.put(socket.assigns.autocomplete_results, field_name, results))
       |> assign(:autocomplete_open,    Map.put(socket.assigns.autocomplete_open,    field_name, true))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("autocomplete_select", %{"field" => field_name, "id" => id}, socket) do
    all_fields = flat_form_fields(socket.assigns.fieldsets)
    field      = Enum.find(all_fields, &(to_string(&1.name) == field_name))

    if field do
      selected_rec    = Repo.get(field.assoc.schema, id)
      updated_record  = Map.put(socket.assigns.record, field.name, id)

      {:noreply,
       socket
       |> assign(:record,              updated_record)
       |> assign(:autocomplete_selected, Map.put(socket.assigns.autocomplete_selected, field_name, selected_rec))
       |> assign(:autocomplete_open,    Map.put(socket.assigns.autocomplete_open,    field_name, false))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("autocomplete_clear", %{"field" => field_name}, socket) do
    all_fields = flat_form_fields(socket.assigns.fieldsets)
    field      = Enum.find(all_fields, &(to_string(&1.name) == field_name))

    if field do
      updated_record = Map.put(socket.assigns.record, field.name, nil)

      {:noreply,
       socket
       |> assign(:record,              updated_record)
       |> assign(:autocomplete_selected, Map.put(socket.assigns.autocomplete_selected, field_name, nil))
       |> assign(:autocomplete_open,    Map.put(socket.assigns.autocomplete_open,    field_name, false))}
    else
      {:noreply, socket}
    end
  end

  # Save (create / update)
  def handle_event("save", %{"record" => attrs}, socket) do
    config = socket.assigns.config
    record = socket.assigns.record
    slug   = socket.assigns.resource_slug

    cs_fn = fn struct, a ->
      if function_exported?(config.schema, :changeset, 2),
        do:   config.schema.changeset(struct, a),
        else: Ecto.Changeset.cast(struct, a, [])
    end

    result =
      if is_nil(Map.get(record, :id)) do
        struct(config.schema) |> cs_fn.(stringify_keys(attrs)) |> Repo.insert()
      else
        record |> cs_fn.(stringify_keys(attrs)) |> Repo.update()
      end

    case result do
      {:ok, saved} ->
        # Save inlines if present
        save_inlines(config, saved.id, attrs)

        {:noreply,
         socket
         |> put_flash(:info, "#{config.label_singular} saved successfully.")
         |> push_navigate(to: "/admin/r/#{slug}/#{saved.id}")}

      {:error, %Ecto.Changeset{} = cs} ->
        errors = Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
        end)
        {:noreply, assign(socket, :changeset_errors, errors)}
    end
  end
  # ---------------------------------------------------------------------------
  # Import / Export Actions
  # ---------------------------------------------------------------------------

  def handle_event("open_import_modal", _params, socket) do
    schema = socket.assigns.config.schema
    default_keys =
      Enum.filter([:code, :sku, :email, :name], fn f -> f in schema.__schema__(:fields) end)
      |> Enum.map(&to_string/1)

    {:noreply,
     socket
     |> assign(:show_import_modal, true)
     |> assign(:import_errors, [])
     |> assign(:import_result, nil)
     |> assign(:import_mode, "upsert")
     |> assign(:import_unique_keys, default_keys)}
  end

  def handle_event("close_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, false)}
  end

  def handle_event("open_export_modal", _params, socket) do
    schema = socket.assigns.config.schema
    exclude = [:id, :inserted_at, :updated_at, :password_hash]
    all_fields =
      schema.__schema__(:fields)
      |> Enum.reject(&(&1 in exclude))
      |> Enum.map(&to_string/1)

    {:noreply,
     socket
     |> assign(:show_export_modal, true)
     |> assign(:export_selected_fields, all_fields)}
  end

  def handle_event("close_export_modal", _params, socket) do
    {:noreply, assign(socket, :show_export_modal, false)}
  end

  def handle_event("import_change", params, socket) do
    import_mode = params["import_mode"] || "upsert"
    unique_keys = Map.keys(params["unique_keys"] || %{})
    {:noreply,
     socket
     |> assign(:import_mode, import_mode)
     |> assign(:import_unique_keys, unique_keys)}
  end

  def handle_event("import_submit", _params, socket) do
    import_mode = socket.assigns.import_mode
    unique_keys = socket.assigns.import_unique_keys
    schema = socket.assigns.config.schema

    uploaded_files =
      consume_uploaded_entries(socket, :import_file, fn %{path: path}, _entry ->
        case File.read(path) do
          {:ok, content} -> {:ok, content}
          error -> error
        end
      end)

    case uploaded_files do
      [csv_content] ->
        case Qcommerce.Admin.ImportExport.import_csv(schema, csv_content, import_mode, unique_keys) do
          {:ok, result} ->
            # Reload list to reflect new data
            updated_socket =
              socket
              |> assign(:import_result, result)
              |> assign(:import_errors, result.errors)
              |> load_list(socket.assigns.config, %{})

            {:noreply, put_flash(updated_socket, :info, "Import process completed successfully.")}

          {:error, msg} ->
            {:noreply,
             socket
             |> assign(:import_errors, [msg])
             |> assign(:import_result, nil)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please select a valid CSV file to upload.")}
    end
  end

  def handle_event("export_submit", %{"fields" => fields_map}, socket) do
    selected_fields = Map.keys(fields_map)
    config = socket.assigns.config
    schema = config.schema

    # Build the full filtered query (without pagination limit/offset)
    query =
      from(r in schema)
      |> maybe_search(config, socket.assigns.search)
      |> maybe_filter(schema, socket.assigns.filters)
      |> maybe_date_drill(config, socket.assigns.date_drill)

    records = Repo.all(query)

    # Build Ecto field metadata list for selected fields
    fields_meta =
      Enum.map(selected_fields, fn f_str ->
        f_atom = String.to_existing_atom(f_str)
        %{name: f_atom, label: FieldHelper.humanize(f_atom)}
      end)

    csv_content = build_csv(records, fields_meta)
    filename = "#{config.label |> String.downcase() |> String.replace(" ", "_")}_export.csv"

    {:noreply,
     socket
     |> assign(:show_export_modal, false)
     |> push_event("download_csv", %{content: csv_content, filename: filename})
     |> put_flash(:info, "CSV export of selected fields triggered.")}
  end

  def handle_event("download_sample_csv", _params, socket) do
    schema = socket.assigns.config.schema
    csv_content = Qcommerce.Admin.ImportExport.sample_csv(schema)
    filename = "#{socket.assigns.config.label |> String.downcase() |> String.replace(" ", "_")}_sample.csv"
    {:noreply,
     socket
     |> push_event("download_csv", %{content: csv_content, filename: filename})}
  end

  # ---------------------------------------------------------------------------
  # Inline save helper
  # ---------------------------------------------------------------------------

  defp save_inlines(_config, _parent_id, attrs) do
    # Inline data arrives as "inlines" → "0" → %{...fields...}
    inline_data = Map.get(attrs, "inlines", %{})

    Enum.each(inline_data, fn {_idx_str, row_attrs} ->
      case Map.get(row_attrs, "__inline_schema") do
        nil -> :ok
        schema_str ->
          schema = String.to_existing_atom(schema_str)
          id_str = Map.get(row_attrs, "id", "")
          clean  = Map.drop(row_attrs, ["id", "__inline_schema", "_delete"])
          should_delete = Map.get(row_attrs, "_delete") == "true"

          cond do
            id_str != "" and should_delete ->
              case Repo.get(schema, id_str) do
                nil -> :ok
                rec -> Repo.delete(rec)
              end

            id_str != "" ->
              case Repo.get(schema, id_str) do
                nil -> :ok
                rec ->
                  if function_exported?(schema, :changeset, 2),
                    do:   schema.changeset(rec, stringify_keys(clean)) |> Repo.update(),
                    else: :ok
              end

            not should_delete and map_size(clean) > 0 ->
              if function_exported?(schema, :changeset, 2) do
                struct(schema) |> schema.changeset(stringify_keys(clean)) |> Repo.insert()
              end

            true -> :ok
          end
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # CSV export helper
  # ---------------------------------------------------------------------------

  defp build_csv(records, fields) do
    header = Enum.map(fields, &to_string(&1.label)) |> Enum.join(",")
    rows =
      Enum.map(records, fn record ->
        Enum.map(fields, fn field ->
          raw_val = Map.get(record, field.name)
          val_str = format_csv_value(raw_val)
          "\"#{String.replace(val_str, "\"", "\"\"")}\""
        end)
        |> Enum.join(",")
      end)
    Enum.join([header | rows], "\n")
  end

  defp format_csv_value(nil), do: ""
  defp format_csv_value(true), do: "true"
  defp format_csv_value(false), do: "false"
  defp format_csv_value(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  defp format_csv_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_string(dt)
  defp format_csv_value(%Decimal{} = d), do: Decimal.to_string(d)
  defp format_csv_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_csv_value(v), do: to_string(v)

  # ---------------------------------------------------------------------------
  # URL helpers
  # ---------------------------------------------------------------------------

  defp current_path(socket, extra_params) do
    slug    = socket.assigns.resource_slug
    q       = socket.assigns[:search]  || ""
    page    = socket.assigns[:page]    || 1
    filters = socket.assigns[:filters] || %{}
    orders  = socket.assigns[:sort_orders] || []
    list_fields = socket.assigns[:list_fields] || []

    o_str = encode_o_param(orders, list_fields)

    params =
      %{"q" => q, "page" => to_string(page), "o" => o_str}
      |> Map.merge(filters)
      |> Map.merge(extra_params)
      |> Enum.reject(fn {_, v} -> v == "" or is_nil(v) end)
      |> Map.new()
      |> URI.encode_query()

    "/admin/r/#{slug}?#{params}"
  end

  # Encode sort_orders list to Django-style "o" param: "1.-2.3"
  defp encode_o_param([], _fields), do: ""
  defp encode_o_param(orders, fields) do
    field_names = Enum.map(fields, &to_string(&1.name))
    orders
    |> Enum.flat_map(fn {field_str, dir} ->
      idx = Enum.find_index(field_names, &(&1 == field_str))
      if idx do
        col = idx + 1
        [if(dir == "desc", do: "-#{col}", else: "#{col}")]
      else
        []
      end
    end)
    |> Enum.join(".")
  end

  # Parse "o" param back to [{field_str, dir}] list
  defp parse_o_param(o_str, config) do
    fields = FieldHelper.fields_for(config.schema, config.list_fields)
    field_names = Enum.map(fields, &to_string(&1.name))
    o_str
    |> String.split(".")
    |> Enum.flat_map(fn part ->
      {neg, idx_str} = if String.starts_with?(part, "-"), do: {true, String.slice(part, 1..-1//1)}, else: {false, part}
      case Integer.parse(idx_str) do
        {n, ""} when n >= 1 and n <= length(field_names) ->
          field_str = Enum.at(field_names, n - 1)
          dir = if neg, do: "desc", else: "asc"
          [{field_str, dir}]
        _ -> []
      end
    end)
    |> case do
      [] -> [{default_sort_field(config), default_sort_dir(config)}]
      list -> list
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  # ---------------------------------------------------------------------------
  # Render dispatcher
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    if Map.get(assigns, :action) == nil do
      ~H"""
      <div style="padding:40px;color:var(--adm-text2);display:flex;align-items:center;gap:10px;">
        <span class="adm-spinner"></span> Loading…
      </div>
      """
    else
      case assigns.action do
        :list -> render_list(assigns)
        :show -> render_show(assigns)
        :edit -> render_form(assigns, :edit)
        :new  -> render_form(assigns, :new)
      end
    end
  end

  # ===========================================================================
  # LIST VIEW
  # ===========================================================================

  defp render_list(assigns) do
    ~H"""
    <!-- Delete confirmation modal -->
    <%= if @delete_confirm_id do %>
      <div style="position:fixed;inset:0;z-index:200;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;" phx-click="cancel_delete">
        <div style="background:var(--adm-card);border:1px solid var(--adm-border);border-radius:16px;padding:32px;width:400px;max-width:90vw;" phx-click-away="cancel_delete">
          <div style="display:flex;align-items:center;gap:8px;font-size:18px;font-weight:700;margin-bottom:8px;color:var(--adm-red);">
            <QcommerceWeb.Layouts.sidebar_icon icon="warning" class="w-5 h-5" />
            Confirm Delete
          </div>
          <p style="color:var(--adm-text2);font-size:13.5px;margin-bottom:24px;">
            Are you sure you want to delete record <strong style="color:var(--adm-text);">#<%= @delete_confirm_id %></strong>?
            This action <strong style="color:var(--adm-red);">cannot be undone</strong>.
          </p>
          <div style="display:flex;gap:10px;justify-content:flex-end;">
            <button phx-click="cancel_delete" class="adm-btn adm-btn-ghost">Cancel</button>
            <button phx-click="delete" phx-value-id={@delete_confirm_id} class="adm-btn adm-btn-danger">Delete</button>
          </div>
        </div>
      </div>
    <% end %>
    <!-- Import CSV Modal -->
    <%= if @show_import_modal do %>
      <div style="position:fixed;inset:0;z-index:200;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;">
        <div style="background:var(--adm-card);border:1px solid var(--adm-border);border-radius:16px;padding:32px;width:550px;max-width:95vw;max-height:90vh;overflow-y:auto;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
            <h2 style="font-size:18px;font-weight:700;display:flex;align-items:center;gap:8px;color:var(--adm-text);margin:0;">
              <QcommerceWeb.Layouts.sidebar_icon icon="hero-arrow-up-tray" class="w-5 h-5" />
              Import CSV: <%= @config.label %>
            </h2>
            <button type="button" phx-click="close_import_modal" class="adm-btn adm-btn-ghost" style="padding:4px;border:none;">
              <QcommerceWeb.Layouts.sidebar_icon icon="hero-x-circle" class="w-5 h-5" />
            </button>
          </div>

          <form phx-submit="import_submit" phx-change="import_change">
            <!-- Download Sample -->
            <div style="background:var(--adm-surface);border:1px solid var(--adm-border);border-radius:10px;padding:16px;margin-bottom:20px;display:flex;align-items:center;justify-content:space-between;gap:12px;">
              <div>
                <div style="font-weight:600;font-size:13px;color:var(--adm-text);">Need a template?</div>
                <div style="font-size:11.5px;color:var(--adm-text2);">Download a sample CSV structure for this schema.</div>
              </div>
              <button type="button" phx-click="download_sample_csv" class="adm-btn adm-btn-primary" style="font-size:11px;padding:6px 12px;">
                Download Sample
              </button>
            </div>

            <!-- Mode Selection -->
            <div style="margin-bottom:20px;">
              <label style="display:block;font-weight:600;font-size:13px;margin-bottom:6px;color:var(--adm-text);">Import Mode</label>
              <select name="import_mode" class="adm-select" style="width:100%;font-size:13px;">
                <option value="upsert" selected={@import_mode == "upsert"}>Upsert (Create new or Update existing)</option>
                <option value="create_only" selected={@import_mode == "create_only"}>Create Only (Skip existing)</option>
                <option value="update_only" selected={@import_mode == "update_only"}>Update Only (Ignore new)</option>
              </select>
            </div>

            <!-- Unique Matching Keys -->
            <div style="margin-bottom:20px;">
              <label style="display:block;font-weight:600;font-size:13px;margin-bottom:6px;color:var(--adm-text);">
                Unique Match Keys (for identifying existing records)
              </label>
              <div style="display:grid;grid-template-columns:repeat(auto-fill, minmax(135px, 1fr));gap:10px;background:var(--adm-surface);border:1px solid var(--adm-border);border-radius:10px;padding:12px;max-height:150px;overflow-y:auto;">
                <%= for field <- @config.schema.__schema__(:fields) |> Enum.reject(&(&1 in [:inserted_at, :updated_at, :password_hash])) do %>
                  <% field_str = to_string(field) %>
                  <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--adm-text2);cursor:pointer;user-select:none;">
                    <input type="checkbox" name={"unique_keys[#{field_str}]"} checked={field_str in @import_unique_keys} style="cursor:pointer;" />
                    <%= FieldHelper.humanize(field) %>
                  </label>
                <% end %>
              </div>
            </div>

            <!-- File Upload -->
            <div style="margin-bottom:24px;">
              <label style="display:block;font-weight:600;font-size:13px;margin-bottom:6px;color:var(--adm-text);">Select CSV File</label>
              <div style="border:2px dashed var(--adm-border);border-radius:12px;padding:24px;text-align:center;background:var(--adm-surface);">
                <.live_file_input upload={@uploads.import_file} style="display:block;margin:0 auto 12px;font-size:13px;" />
                <p style="font-size:11.5px;color:var(--adm-text3);margin:0;">Max size: 5MB. Format: CSV only.</p>
              </div>
            </div>

            <!-- Import Results/Feedback -->
            <%= if @import_result do %>
              <div style="margin-bottom:20px;padding:16px;background:rgba(16,185,129,.1);border:1px solid rgba(16,185,129,.2);border-radius:10px;">
                <div style="font-weight:600;font-size:14px;color:#10b981;margin-bottom:8px;">Import Finished</div>
                <div style="display:grid;grid-template-columns:repeat(4, 1fr);gap:8px;text-align:center;font-size:12px;color:var(--adm-text2);">
                  <div>
                    <div style="font-weight:700;font-size:16px;color:var(--adm-text);"><%= @import_result.created %></div>
                    Created
                  </div>
                  <div>
                    <div style="font-weight:700;font-size:16px;color:var(--adm-text);"><%= @import_result.updated %></div>
                    Updated
                  </div>
                  <div>
                    <div style="font-weight:700;font-size:16px;color:var(--adm-text);"><%= @import_result.skipped %></div>
                    Skipped
                  </div>
                  <div>
                    <div style="font-weight:700;font-size:16px;color:var(--adm-red);"><%= @import_result.failed %></div>
                    Failed
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @import_errors != [] do %>
              <div style="margin-bottom:20px;padding:16px;background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.2);border-radius:10px;">
                <div style="font-weight:600;font-size:14px;color:var(--adm-red);margin-bottom:8px;">Import Errors / Warnings</div>
                <div style="max-height:120px;overflow-y:auto;font-size:11.5px;color:var(--adm-text2);font-family:monospace;display:flex;flex-direction:column;gap:4px;text-align:left;">
                  <%= for err <- @import_errors do %>
                    <div>• <%= err %></div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Submit / Actions -->
            <div style="display:flex;gap:12px;justify-content:flex-end;border-top:1px solid var(--adm-border);padding-top:20px;">
              <button type="button" phx-click="close_import_modal" class="adm-btn adm-btn-ghost">Close</button>
              <button type="submit" class="adm-btn adm-btn-primary" disabled={@uploads.import_file.entries == []}>
                Start Import
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <!-- Export Modal -->
    <%= if @show_export_modal do %>
      <div style="position:fixed;inset:0;z-index:200;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;">
        <div style="background:var(--adm-card);border:1px solid var(--adm-border);border-radius:16px;padding:32px;width:500px;max-width:95vw;max-height:90vh;overflow-y:auto;">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
            <h2 style="font-size:18px;font-weight:700;display:flex;align-items:center;gap:8px;color:var(--adm-text);margin:0;">
              <QcommerceWeb.Layouts.sidebar_icon icon="hero-arrow-down-tray" class="w-5 h-5" />
              Export: <%= @config.label %>
            </h2>
            <button type="button" phx-click="close_export_modal" class="adm-btn adm-btn-ghost" style="padding:4px;border:none;">
              <QcommerceWeb.Layouts.sidebar_icon icon="hero-x-circle" class="w-5 h-5" />
            </button>
          </div>

          <form phx-submit="export_submit">
            <!-- Select Fields -->
            <div style="margin-bottom:24px;">
              <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
                <label style="font-weight:600;font-size:13px;color:var(--adm-text);">Fields to Export</label>
                <span style="font-size:11px;color:var(--adm-text3);">Check fields to include in export</span>
              </div>
              <div style="display:grid;grid-template-columns:repeat(auto-fill, minmax(130px, 1fr));gap:10px;background:var(--adm-surface);border:1px solid var(--adm-border);border-radius:10px;padding:12px;max-height:250px;overflow-y:auto;">
                <%= for field <- @config.schema.__schema__(:fields) |> Enum.reject(&(&1 in [:password_hash])) do %>
                  <% field_str = to_string(field) %>
                  <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--adm-text2);cursor:pointer;user-select:none;">
                    <input type="checkbox" name={"fields[#{field_str}]"} checked={field_str in @export_selected_fields} style="cursor:pointer;" />
                    <%= FieldHelper.humanize(field) %>
                  </label>
                <% end %>
              </div>
            </div>

            <!-- Format / Info -->
            <div style="background:var(--adm-surface);border:1px solid var(--adm-border);border-radius:10px;padding:12px;font-size:11.5px;color:var(--adm-text2);margin-bottom:20px;display:flex;align-items:center;gap:8px;">
              <QcommerceWeb.Layouts.sidebar_icon icon="hero-information-circle" class="w-5 h-5" style="color:var(--adm-accent);" />
              <span>This will export all matching records across all pages based on current filters and search query.</span>
            </div>

            <!-- Submit / Actions -->
            <div style="display:flex;gap:12px;justify-content:flex-end;border-top:1px solid var(--adm-border);padding-top:20px;">
              <button type="button" phx-click="close_export_modal" class="adm-btn adm-btn-ghost">Cancel</button>
              <button type="submit" class="adm-btn adm-btn-primary">
                Export CSV
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <!-- Page header -->
    <div class="adm-page-header" style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;flex-wrap:wrap;">
      <div>
        <h1 class="adm-page-title" style="display:inline-flex;align-items:center;gap:8px;">
          <QcommerceWeb.Layouts.sidebar_icon icon={@config.icon} class="w-6 h-6" />
          <%= @config.label %>
        </h1>
        <p class="adm-page-sub">
          <%= if @config.show_full_result_count do %>
            <strong style="color:var(--adm-text);"><%= @total %></strong> records
          <% end %>
          <%= if map_size(@filters) > 0 do %>
            <span style="color:var(--adm-accent2);"> · <%= map_size(@filters) %> filter(s) active</span>
          <% end %>
          <%= if length(@selected_ids) > 0 do %>
            <span style="color:var(--adm-yellow);"> · <%= length(@selected_ids) %> selected</span>
          <% end %>
        </p>
      </div>
      <div style="display:flex;align-items:center;gap:10px;">
        <button phx-click="open_import_modal" class="adm-btn adm-btn-ghost" style="font-size:13px;display:inline-flex;align-items:center;gap:6px;height:36px;">
          <QcommerceWeb.Layouts.sidebar_icon icon="hero-arrow-up-tray" class="w-4 h-4" />
          Import
        </button>
        <button phx-click="open_export_modal" class="adm-btn adm-btn-ghost" style="font-size:13px;display:inline-flex;align-items:center;gap:6px;height:36px;">
          <QcommerceWeb.Layouts.sidebar_icon icon="hero-arrow-down-tray" class="w-4 h-4" />
          Export
        </button>
        <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
          <a href={"/admin/r/#{@resource_slug}/new"} class="adm-btn adm-btn-primary" style="height:36px;display:inline-flex;align-items:center;">
            + New <%= @config.label_singular %>
          </a>
        <% end %>
      </div>
    </div>

    <!-- Date hierarchy breadcrumb -->
    <%= if @config.date_hierarchy && @date_counts != [] do %>
      <div class="adm-card" style="margin-bottom:16px;padding:12px 20px;display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
        <span style="font-size:11px;font-weight:600;color:var(--adm-text3);text-transform:uppercase;letter-spacing:.8px;margin-right:4px;">Date</span>
        <%= if map_size(@date_drill) > 0 do %>
          <button phx-click="date_drill" class="adm-date-crumb">All</button>
          <QcommerceWeb.Layouts.sidebar_icon icon="chevron-right-small" class="w-3 h-3" style="color:var(--adm-text3);" />
        <% end %>
        <%= for entry <- @date_counts do %>
          <% {type, val, count} = entry %>
          <% label = case type do
            :year  -> "#{val}"
            :month -> month_name(val)
            _      -> "#{val}"
          end %>
          <% drill_params = case type do
            :year  -> %{"year" => to_string(val)}
            :month -> %{"year" => @date_drill["year"], "month" => to_string(val)}
            _      -> %{}
          end %>
          <button phx-click="date_drill" phx-value-year={drill_params["year"]}
            phx-value-month={drill_params["month"]}
            class={"adm-date-crumb #{if drill_params == @date_drill, do: "active"}"}>
            <%= label %> <span style="font-size:10px;opacity:.6;">(<%= count %>)</span>
          </button>
        <% end %>
      </div>
    <% end %>

    <!-- Main card -->
    <div class="adm-card">
      <!-- Toolbar -->
      <div class="adm-toolbar">
        <form phx-submit="search" style="display:contents;">
          <div class="adm-search-wrap">
            <span class="adm-search-icon"><QcommerceWeb.Layouts.sidebar_icon icon="search" class="w-4 h-4" /></span>
            <input id="adm-search" type="text" name="q" value={@search}
              placeholder={"Search #{String.downcase(@config.label)}…"}
              class="adm-search" phx-debounce="300" phx-change="search" />
          </div>
        </form>


        <!-- Filter dropdowns -->
        <%= for {field_name, opts} <- @filter_options do %>
          <% is_open    = Map.get(@filter_open,   field_name, false) %>
          <% search_q   = Map.get(@filter_search,  field_name, "") %>
          <% active_val = Map.get(@filters,        field_name, "") %>
          <% field_label = FieldHelper.humanize(field_name) %>
          <% active_label =
            if active_val != "",
              do: Enum.find_value(opts, active_val, fn {l, v} -> if v == active_val, do: l end),
              else: nil %>

          <div style={"position:relative;z-index:#{if is_open, do: 200, else: 10};"}>
            <button
              type="button"
              phx-click="filter_toggle"
              phx-value-field={field_name}
              style={"display:flex;align-items:center;gap:6px;height:34px;padding:0 12px;
                      border-radius:20px;font-size:12px;font-weight:600;cursor:pointer;
                      border:1px solid #{if active_val != "", do: "var(--adm-accent)", else: "var(--adm-border)"};
                      background:#{if active_val != "", do: "rgba(99,102,241,.15)", else: "var(--adm-card)"};
                      color:#{if active_val != "", do: "var(--adm-accent2)", else: "var(--adm-text2)"};
                      white-space:nowrap;transition:all .15s;"}
            >
              <%= field_label %>
              <%= if active_label do %>
                <span style="background:var(--adm-accent);color:#fff;border-radius:10px;padding:1px 7px;font-size:10px;">
                  <%= active_label %>
                </span>
              <% end %>
              <span style="font-size:10px;opacity:.6;"><%= if is_open, do: "▴", else: "▾" %></span>
            </button>

            <%= if is_open do %>
              <div style="position:absolute;top:calc(100% + 6px);left:0;min-width:200px;
                          background:var(--adm-card);border:1px solid var(--adm-border);
                          border-radius:10px;box-shadow:0 8px 32px rgba(0,0,0,.5);
                          overflow:hidden;">

                <div style="padding:8px 8px 4px;">
                  <div style="position:relative;">
                    <span style="position:absolute;left:9px;top:50%;transform:translateY(-50%);color:var(--adm-text3);font-size:12px;">
                      🔍
                    </span>
                    <input
                      type="text"
                      value={search_q}
                      placeholder={"Search #{field_label}…"}
                      phx-keyup="filter_search"
                      phx-value-field={field_name}
                      phx-debounce="150"
                      style="width:100%;background:var(--adm-surface);border:1px solid var(--adm-border);
                             border-radius:7px;color:var(--adm-text);padding:6px 10px 6px 30px;
                             font-size:12px;outline:none;"
                    />
                  </div>
                </div>

                <div style="max-height:200px;overflow-y:auto;padding:4px 4px 6px;">
                  <div
                    phx-click="filter_pick"
                    phx-value-field={field_name}
                    phx-value-value=""
                    style={"cursor:pointer;padding:7px 12px;border-radius:7px;font-size:12px;
                            color:#{if active_val == "", do: "var(--adm-accent2)", else: "var(--adm-text3)"};
                            background:#{if active_val == "", do: "rgba(99,102,241,.12)", else: "transparent"};
                            display:flex;align-items:center;gap:6px;"}
                  >
                    <span style="width:14px;text-align:center;">
                      <%= if active_val == "", do: "✓", else: "" %>
                    </span>
                    All <%= field_label %>
                  </div>

                  <%= for {label, val} <- Enum.filter(opts, fn {l, _} ->
                        search_q == "" or String.contains?(String.downcase(l), String.downcase(search_q))
                      end) do %>
                    <div
                      phx-click="filter_pick"
                      phx-value-field={field_name}
                      phx-value-value={val}
                      style={"cursor:pointer;padding:7px 12px;border-radius:7px;font-size:12px;
                              color:#{if val == active_val, do: "var(--adm-accent2)", else: "var(--adm-text2)"};
                              background:#{if val == active_val, do: "rgba(99,102,241,.12)", else: "transparent"};
                              display:flex;align-items:center;gap:6px;transition:background .1s;"}
                    >
                      <span style="width:14px;text-align:center;">
                        <%= if val == active_val, do: "✓", else: "" %>
                      </span>
                      <%= label %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Clear filters -->
        <%= if map_size(@filters) > 0 do %>
          <button phx-click="filter_clear_all" class="adm-btn adm-btn-ghost" style="font-size:11px;color:var(--adm-red);">
            <QcommerceWeb.Layouts.sidebar_icon icon="x" class="w-3 h-3" /> Clear filters
          </button>
        <% end %>

        <span class="adm-spacer"></span>

        <!-- Bulk actions select dropdown -->
        <%= if length(@selected_ids) > 0 do %>
          <div style="display:inline-flex;align-items:center;gap:8px;background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.2);padding:3px 10px;border-radius:20px;margin-right:8px;">
            <span style="font-size:11.5px;color:#f87171;font-weight:600;white-space:nowrap;">
              <%= length(@selected_ids) %> selected
            </span>
            <form phx-submit="bulk_action" style="display:flex;align-items:center;gap:6px;margin:0;">
              <select
                name="action"
                class="adm-select"
                style="height:26px;font-size:11px;width:auto;min-width:130px;padding:2px 8px;border-radius:14px;border-color:rgba(239,68,68,.25);background:var(--adm-surface);color:var(--adm-text);outline:none;"
              >
                <option value="">— Action —</option>
                <%= if :delete in (@config.actions || [:show, :edit, :delete]) do %>
                  <option value="delete">Delete selected</option>
                <% end %>
                <%= for action <- (@config.custom_actions || []) do %>
                  <option value={action.id}><%= action.label %></option>
                <% end %>
              </select>
              <button
                type="submit"
                class="adm-btn adm-btn-danger"
                style="height:26px;padding:0 12px;font-size:11px;border-radius:14px;border:none;"
              >
                Apply
              </button>
            </form>
          </div>
        <% end %>

        <span style="font-size:11px;color:var(--adm-text2);">
          Page <%= @page %> / <%= @total_pages %>
        </span>
      </div>

      <!-- Table -->
      <div class="adm-table-wrap">
        <%= if @records == [] do %>
          <div class="adm-empty">
            <div style="display:flex;justify-content:center;margin-bottom:12px;color:var(--adm-text3);">
              <QcommerceWeb.Layouts.sidebar_icon icon={@config.icon} class="w-12 h-12" />
            </div>
            <div class="adm-empty-msg">No <%= String.downcase(@config.label) %> found</div>
            <div class="adm-empty-sub">
              <%= if @search != "" or map_size(@filters) > 0 do %>
                Try adjusting your search or filters.
              <% else %>
                Add a new record to get started.
              <% end %>
            </div>
          </div>
        <% else %>
          <table class="adm-table">
            <thead>
              <tr>
                <th style="width:38px;padding:10px 8px;">
                  <% all_ids = Enum.map(@records, &to_string(&1.id)) %>
                  <% all_sel = Enum.all?(all_ids, &(&1 in @selected_ids)) %>
                  <input type="checkbox" phx-click="toggle_select_all"
                    checked={all_sel and length(all_ids) > 0}
                    style="cursor:pointer;accent-color:var(--adm-accent);" />
                </th>
                <%= for {field, _col_idx} <- Enum.with_index(@list_fields, 1) do %>
                  <% field_str = to_string(field.name) %>
                  <% sort_entry = Enum.find_index(@sort_orders, fn {f, _} -> f == field_str end) %>
                  <% sort_pos   = if sort_entry != nil, do: sort_entry + 1, else: nil %>
                  <% sort_dir_for = if sort_entry != nil, do: elem(Enum.at(@sort_orders, sort_entry), 1), else: nil %>
                  <% is_sorted  = sort_pos != nil %>
                  <% multi_sort = length(@sort_orders) > 1 %>
                  <th
                    style={"cursor:#{if FieldHelper.sortable?(field), do: "pointer", else: "default"};user-select:none;#{if is_sorted, do: "color:var(--adm-accent2);", else: ""}"}
                    id={"sort-th-#{field_str}"}
                    phx-hook={if FieldHelper.sortable?(field), do: "SortHeader", else: nil}
                    data-field={if FieldHelper.sortable?(field), do: field_str, else: nil}
                    title={if FieldHelper.sortable?(field), do: "Click · Shift+Click to multi-sort", else: nil}
                  >
                    <div style="display:flex;align-items:center;gap:4px;white-space:nowrap;">
                      <%= field.label %>
                      <%= if is_sorted do %>
                        <span style="display:inline-flex;align-items:center;gap:1px;color:var(--adm-accent2);">
                          <%= if multi_sort do %>
                            <span style="font-size:9px;font-weight:700;background:var(--adm-accent);color:#fff;
                                         border-radius:3px;padding:0 3px;line-height:15px;margin-right:1px;">
                              <%= sort_pos %>
                            </span>
                          <% end %>
                          <span style="font-size:11px;font-weight:700;">
                            <%= if sort_dir_for == "asc", do: "▲", else: "▼" %>
                          </span>
                        </span>
                      <% else %>
                        <%= if FieldHelper.sortable?(field) do %>
                          <span style="font-size:11px;opacity:0.3;">↕</span>
                        <% end %>
                      <% end %>
                    </div>
                  </th>
                <% end %>
                <th style="text-align:right;width:140px;">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for record <- @records do %>
                <% is_sel = to_string(record.id) in @selected_ids %>
                <tr class={"adm-tr #{if is_sel, do: "selected"}"}>
                  <td style="padding:8px;width:38px;">
                    <input type="checkbox" phx-click="toggle_select" phx-value-id={record.id}
                      checked={is_sel} style="cursor:pointer;accent-color:var(--adm-accent);" />
                  </td>
                  <%= for field <- @list_fields do %>
                    <% is_link = field.name in (@config.list_display_links || [:id]) %>
                    <td class={if field.name == :id, do: "adm-id"}>
                      <%= if is_link do %>
                        <a href={"/admin/r/#{@resource_slug}/#{record.id}"}
                          style="color:var(--adm-accent2);text-decoration:none;font-weight:500;">
                          <%= render_cell(field, Map.get(record, field.name), @config) %>
                        </a>
                      <% else %>
                        <%= render_cell(field, Map.get(record, field.name), @config) %>
                      <% end %>
                    </td>
                  <% end %>
                  <td style="text-align:right;white-space:nowrap;">
                    <a href={"/admin/r/#{@resource_slug}/#{record.id}"}
                      class="adm-action-btn" title="View">
                        <QcommerceWeb.Layouts.sidebar_icon icon="eye" class="w-4 h-4" />
                      </a>
                    <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
                      <a href={"/admin/r/#{@resource_slug}/#{record.id}/edit"}
                        class="adm-action-btn adm-action-edit" title="Edit">
                          <QcommerceWeb.Layouts.sidebar_icon icon="pencil" class="w-4 h-4" />
                        </a>
                    <% end %>
                    <%= if :delete in (@config.actions || [:show, :edit, :delete]) do %>
                      <button phx-click="confirm_delete" phx-value-id={record.id}
                        class="adm-action-btn adm-action-del" title="Delete">
                          <QcommerceWeb.Layouts.sidebar_icon icon="trash" class="w-4 h-4" />
                        </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>

      <!-- Pagination -->
      <%= if @total_pages > 1 do %>
        <div class="adm-pagination">
          <span style="margin-right:8px;color:var(--adm-text2);font-size:12px;">
            <%= (@page - 1) * @per_page + 1 %>–<%= min(@page * @per_page, @total) %> of <%= @total %>
          </span>
          <%= if @page > 1 do %>
            <button phx-click="page" phx-value-p={@page - 1} class="adm-page-btn">
              <QcommerceWeb.Layouts.sidebar_icon icon="chevron-left" class="w-4 h-4" />
            </button>
          <% end %>
          <%= for p <- page_range(@page, @total_pages) do %>
            <%= if p == :ellipsis do %>
              <span style="color:var(--adm-text3);padding:0 4px;">…</span>
            <% else %>
              <button phx-click="page" phx-value-p={p}
                class={"adm-page-btn #{if p == @page, do: "current"}"}><%= p %></button>
            <% end %>
          <% end %>
          <%= if @page < @total_pages do %>
            <button phx-click="page" phx-value-p={@page + 1} class="adm-page-btn">
              <QcommerceWeb.Layouts.sidebar_icon icon="chevron-right" class="w-4 h-4" />
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # SHOW VIEW
  # ===========================================================================

  defp render_show(assigns) do
    ~H"""
    <!-- Delete modal -->
    <%= if @delete_confirm_id do %>
      <div style="position:fixed;inset:0;z-index:200;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;">
        <div style="background:var(--adm-card);border:1px solid var(--adm-border);border-radius:16px;padding:32px;width:400px;">
          <div style="display:flex;align-items:center;gap:8px;font-size:16px;font-weight:700;margin-bottom:8px;color:var(--adm-red);">
            <QcommerceWeb.Layouts.sidebar_icon icon="warning" class="w-5 h-5" />
            Confirm Delete
          </div>
          <p style="color:var(--adm-text2);font-size:13px;margin-bottom:20px;">
            Delete record <strong>#<%= @delete_confirm_id %></strong>? This cannot be undone.
          </p>
          <div style="display:flex;gap:10px;justify-content:flex-end;">
            <button phx-click="cancel_delete" class="adm-btn adm-btn-ghost">Cancel</button>
            <button phx-click="delete" phx-value-id={@delete_confirm_id} class="adm-btn adm-btn-danger">Delete</button>
          </div>
        </div>
      </div>
    <% end %>

    <div class="adm-page-header" style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;flex-wrap:wrap;">
      <div>
        <h1 class="adm-page-title" style="display:inline-flex;align-items:center;gap:8px;">
          <QcommerceWeb.Layouts.sidebar_icon icon={@config.icon} class="w-6 h-6" />
          <%= @config.label_singular %> #<%= @record && @record.id %>
        </h1>
        <p class="adm-page-sub">Viewing record details · <span style="font-family:monospace;font-size:11px;"><%= inspect(@config.schema) %></span></p>
      </div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;">
        <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">← Back to <%= @config.label %></a>
        <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
          <a href={"/admin/r/#{@resource_slug}/#{@record && @record.id}/edit"} class="adm-btn adm-btn-primary">
            <QcommerceWeb.Layouts.sidebar_icon icon="pencil" class="w-4 h-4" /> Edit
          </a>
        <% end %>
        <%= if :delete in (@config.actions || [:show, :edit, :delete]) do %>
          <button phx-click="confirm_delete" phx-value-id={@record && @record.id}
            class="adm-btn adm-btn-danger">
            <QcommerceWeb.Layouts.sidebar_icon icon="trash" class="w-4 h-4" /> Delete
          </button>
        <% end %>
      </div>
    </div>

    <%= if @record do %>
      <div class="adm-card">
        <div class="adm-card-header">
          <span class="adm-card-title">Field Values</span>
          <div style="display:flex;align-items:center;gap:8px;">
            <span style="font-size:10px;color:var(--adm-text3);font-family:monospace;">id: <%= @record.id %></span>
          </div>
        </div>
        <div class="adm-card-body">
          <div class="adm-form-grid">
            <%= for field <- @all_fields do %>
              <div class={"adm-field #{if field.input_type in [:textarea, :autocomplete], do: "full"}"}>
                <div class="adm-label"><%= field.label %></div>
                <div class="adm-readonly-val">
                  <%= render_cell(field, Map.get(@record, field.name), @config) %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- History/audit hint -->
      <div style="margin-top:16px;padding:12px 16px;background:rgba(99,102,241,.05);border:1px solid rgba(99,102,241,.15);border-radius:8px;font-size:11.5px;color:var(--adm-text2);">
        <span style="display:inline-flex;align-items:center;gap:4px;color:var(--adm-accent2);font-weight:600;">
          <QcommerceWeb.Layouts.sidebar_icon icon="info" class="w-4 h-4" /> History:
        </span>
        Created: <strong><%= FieldHelper.format_value(Map.get(@record, :inserted_at)) %></strong>
        <%= if Map.has_key?(@record, :updated_at) do %>
          · Updated: <strong><%= FieldHelper.format_value(Map.get(@record, :updated_at)) %></strong>
        <% end %>
      </div>
    <% else %>
      <div class="adm-card adm-empty">
        <div class="adm-empty-icon"><QcommerceWeb.Layouts.sidebar_icon icon="search" class="w-10 h-10" /></div>
        <div class="adm-empty-msg">Record not found</div>
      </div>
    <% end %>
    """
  end

  # ===========================================================================
  # NEW / EDIT FORM
  # ===========================================================================

  defp render_form(assigns, mode) do
    assigns = Phoenix.Component.assign(assigns, :form_mode, mode)

    ~H"""
    <div class="adm-page-header" style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;flex-wrap:wrap;">
      <div>
        <h1 class="adm-page-title" style="display:inline-flex;align-items:center;gap:8px;">
          <%= if @form_mode == :new do %>
            <QcommerceWeb.Layouts.sidebar_icon icon="hero-plus-circle" class="w-6 h-6" />
            New <%= @config.label_singular %>
          <% else %>
            <QcommerceWeb.Layouts.sidebar_icon icon="hero-pencil-square" class="w-6 h-6" />
            Edit <%= @config.label_singular %> #<%= @record && @record.id %>
          <% end %>
        </h1>
        <p class="adm-page-sub"><%= @config.label %> · <span style="font-family:monospace;font-size:11px;"><%= inspect(@config.schema) %></span></p>
      </div>
      <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">← Cancel</a>
    </div>

    <form phx-submit="save" id="adm-form">
      <!-- Save on top -->
      <%= if @config.save_on_top do %>
        <div style="display:flex;gap:10px;margin-bottom:16px;">
          <button type="submit" class="adm-btn adm-btn-primary">
            <%= if @form_mode == :new, do: "Create #{@config.label_singular}", else: "Save Changes" %>
          </button>
          <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">Cancel</a>
        </div>
      <% end %>

      <!-- Fieldsets -->
      <%= for {title, classes, fields} <- @fieldsets do %>
        <% is_collapsible = "collapse" in classes %>
        <% is_collapsed   = title in (@collapsed_fieldsets || []) %>

        <div class="adm-card" style="margin-bottom:16px;">
          <%= if title != "" do %>
            <div class="adm-card-header" style={"#{if is_collapsible, do: "cursor:pointer;"}"}
              phx-click={if is_collapsible, do: "toggle_fieldset", else: nil}
              phx-value-title={title}>
              <span class="adm-card-title"><%= title %></span>
              <%= if is_collapsible do %>
                <span style="display:inline-flex;align-items:center;gap:3px;color:var(--adm-text3);font-size:11px;">
                <%= if is_collapsed do %>
                  <QcommerceWeb.Layouts.sidebar_icon icon="chevron-right" class="w-3 h-3" /> Show
                <% else %>
                  <QcommerceWeb.Layouts.sidebar_icon icon="chevron-down" class="w-3 h-3" /> Hide
                <% end %>
              </span>
              <% end %>
            </div>
          <% end %>

          <%= unless is_collapsed do %>
            <div class="adm-card-body">
              <div class="adm-form-grid">
                <%= for field <- fields do %>
                  <% full_class = if field.input_type in [:textarea, :autocomplete], do: "full", else: "" %>
                  <div class={"adm-field #{full_class}"}>
                    <label class="adm-label" for={"field_#{field.name}"}>
                      <%= field.label %>
                      <%= if field.required do %><span class="req">*</span><% end %>
                    </label>

                    <%= if field.input_type == :autocomplete do %>
                      <%= render_autocomplete(field, @record, @autocomplete_open, @autocomplete_selected, @autocomplete_results, @autocomplete_search) %>
                    <% else %>
                      <%= render_input(field, @record, @config, @changeset_errors) %>
                    <% end %>

                    <%= if Map.has_key?(@changeset_errors, field.name) do %>
                      <div class="adm-val-error">
                        <span style="display:inline-flex;align-items:center;gap:3px;">
                        <QcommerceWeb.Layouts.sidebar_icon icon="warning" class="w-3 h-3" />
                        <%= Enum.join(Map.get(@changeset_errors, field.name, []), ", ") %>
                      </span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Inline Formsets -->
      <%= for %{inline: inline, records: inline_records, fields: inline_fields} <- @inlines do %>
        <div class="adm-card" style="margin-bottom:16px;">
          <div class="adm-card-header">
            <span class="adm-card-title">
              <span style="display:inline-flex;align-items:center;gap:6px;">
                <QcommerceWeb.Layouts.sidebar_icon icon="link" class="w-4 h-4" />
                <%= inline[:label] || "Related #{inspect(inline.schema)}" %>
              </span>
            </span>
            <span style="font-size:11px;color:var(--adm-text2);">
              <%= length(inline_records) %> existing · <%= inline[:extra] || 1 %> new
            </span>
          </div>
          <div class="adm-card-body" style="padding:0;">
            <div class="adm-table-wrap">
              <table class="adm-table">
                <thead>
                  <tr>
                    <%= for f <- inline_fields do %>
                      <th><%= f.label %></th>
                    <% end %>
                    <th style="width:60px;text-align:center;">Del</th>
                  </tr>
                </thead>
                <tbody>
                  <!-- Existing rows -->
                  <%= for {rec, idx} <- Enum.with_index(inline_records) do %>
                    <tr>
                      <input type="hidden" name={"record[inlines][#{idx}][id]"} value={rec.id} />
                      <input type="hidden" name={"record[inlines][#{idx}][__inline_schema]"} value={inspect(inline.schema)} />
                      <input type="hidden" name={"record[inlines][#{idx}][#{inline.fk_field}]"} value={@record && @record.id} />
                      <%= for f <- inline_fields do %>
                        <td>
                          <%= render_inline_input(f, Map.get(rec, f.name), idx) %>
                        </td>
                      <% end %>
                      <td style="text-align:center;">
                        <label style="cursor:pointer;color:var(--adm-red);">
                          <input type="checkbox" name={"record[inlines][#{idx}][_delete]"} value="true"
                            style="accent-color:var(--adm-red);" />
                        </label>
                      </td>
                    </tr>
                  <% end %>
                  <!-- New blank rows -->
                  <%= for new_idx <- 0..((inline[:extra] || 1) - 1) do %>
                    <% idx = length(inline_records) + new_idx %>
                    <tr class="adm-inline-new">
                      <input type="hidden" name={"record[inlines][#{idx}][__inline_schema]"} value={inspect(inline.schema)} />
                      <input type="hidden" name={"record[inlines][#{idx}][#{inline.fk_field}]"} value={@record && @record.id} />
                      <%= for f <- inline_fields do %>
                        <td>
                          <%= render_inline_input(f, nil, idx) %>
                        </td>
                      <% end %>
                      <td></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Save buttons -->
      <div style="display:flex;gap:10px;margin-top:4px;padding-top:8px;">
        <button type="submit" class="adm-btn adm-btn-primary">
          <%= if @form_mode == :new, do: "Create #{@config.label_singular}", else: "Save Changes" %>
        </button>
        <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">Cancel</a>
        <%= if @form_mode == :edit and :delete in (@config.actions || [:show, :edit, :delete]) do %>
          <button type="button" phx-click="confirm_delete" phx-value-id={@record && @record.id}
            class="adm-btn adm-btn-danger" style="margin-left:auto;">
            <QcommerceWeb.Layouts.sidebar_icon icon="trash" class="w-4 h-4" /> Delete this <%= @config.label_singular %>
          </button>
        <% end %>
      </div>
    </form>

    <!-- Prepopulated fields JS -->
    <%= Phoenix.HTML.raw(FieldHelper.prepopulate_js(Map.get(@config, :prepopulated_fields, []))) %>
    """
  end

  # ---------------------------------------------------------------------------
  # Input renderers
  # ---------------------------------------------------------------------------

  defp render_autocomplete(field, _record, autocomplete_open, autocomplete_selected, autocomplete_results, autocomplete_search) do
    fkey      = to_string(field.name)
    is_open   = Map.get(autocomplete_open,   fkey, false)
    sel_rec   = Map.get(autocomplete_selected, fkey)
    results   = Map.get(autocomplete_results, fkey, [])
    search_q  = Map.get(autocomplete_search, fkey, "")
    current_id = if sel_rec, do: to_string(sel_rec.id), else: ""

    placeholder = "— choose #{field.label} —"
    sel_label   = if sel_rec do
      "#{FieldHelper.humanize(to_string(field.assoc.assoc_name))} ##{sel_rec.id} · #{FieldHelper.assoc_label(sel_rec)}"
    else
      nil
    end

    _assigns = %{
      field: field, fkey: fkey, is_open: is_open, sel_rec: sel_rec,
      results: results, search_q: search_q, current_id: current_id,
      placeholder: placeholder, sel_label: sel_label
    }

    Phoenix.HTML.raw("""
    <div style="position:relative;">
      <input type="hidden" name="record[#{fkey}]" value="#{current_id}" />
      <div class="adm-input adm-ac-trigger"
        phx-click="autocomplete_toggle" phx-value-field="#{fkey}"
        style="display:flex;align-items:center;justify-content:space-between;cursor:pointer;gap:8px;min-height:38px;">
        <span style="#{if sel_rec, do: "color:var(--adm-text);", else: "color:var(--adm-text3);"}font-size:13px;">
          #{if sel_label, do: sel_label, else: placeholder}
        </span>
        <span style="color:var(--adm-text3);font-size:11px;flex-shrink:0;">#{if is_open, do: "▴", else: "▾"}</span>
      </div>

      #{if is_open do
        """
        <div class="adm-ac-dropdown">
          <div style="padding:8px;">
            <input type="text" value="#{search_q}" placeholder="Search…"
              class="adm-filter-search"
              phx-keyup="autocomplete_search" phx-value-field="#{fkey}" phx-debounce="200" />
          </div>
          #{if sel_rec do
            """
            <div style="padding:6px 12px;font-size:11px;color:var(--adm-accent2);border-bottom:1px solid var(--adm-border);display:flex;justify-content:space-between;">
              <span>✓ Selected: ##{sel_rec.id}</span>
              <button type="button" phx-click="autocomplete_clear" phx-value-field="#{fkey}"
                style="background:none;border:none;color:var(--adm-text3);cursor:pointer;">✕ Clear</button>
            </div>
            """
          else "" end}
          <div style="max-height:220px;overflow-y:auto;">
            #{if results == [] do
              ~s(<div style="padding:16px;text-align:center;color:var(--adm-text3;font-size:12px;">No results</div>)
            else
              Enum.map(results, fn rec ->
                is_sel  = sel_rec && sel_rec.id == rec.id
                lbl     = FieldHelper.assoc_label(rec)
                bg      = if is_sel, do: "rgba(99,102,241,.1)", else: "transparent"
                color   = if is_sel, do: "var(--adm-accent2)", else: "var(--adm-text2)"
                """
                <div class="adm-filter-option"
                  phx-click="autocomplete_select" phx-value-field="#{fkey}" phx-value-id="#{rec.id}"
                  style="cursor:pointer;color:#{color};background:#{bg};">
                  <span style="font-family:monospace;font-size:10px;color:var(--adm-text3);margin-right:6px;">##{rec.id}</span>
                  #{lbl}
                </div>
                """
              end) |> Enum.join("")
            end}
          </div>
        </div>
        """
      else "" end}
    </div>
    """)
  end

  defp render_input(%{input_type: :checkbox} = field, record, _config, _errors) do
    val = Map.get(record || %{}, field.name, false)
    Phoenix.HTML.raw("""
    <label class="adm-checkbox">
      <input type="checkbox" name="record[#{field.name}]" id="field_#{field.name}"
             value="true" #{if val, do: "checked"}>
      <span>#{field.label}</span>
    </label>
    <input type="hidden" name="record[#{field.name}]" value="false">
    """)
  end

  defp render_input(%{input_type: :select} = field, record, config, _errors) do
    val  = Map.get(record || %{}, field.name)
    opts = FieldHelper.enum_values(config.schema, field.name)
    options_html =
      Enum.map(opts, fn opt ->
        lbl = opt |> to_string() |> String.replace("_", " ") |> String.capitalize()
        sel = if to_string(opt) == to_string(val || ""), do: "selected", else: ""
        "<option value=\"#{opt}\" #{sel}>#{lbl}</option>"
      end)
      |> Enum.join("")

    Phoenix.HTML.raw("""
    <select name="record[#{field.name}]" id="field_#{field.name}" class="adm-select">
      <option value="">— choose —</option>
      #{options_html}
    </select>
    """)
  end

  defp render_input(%{input_type: :textarea} = field, record, _config, _errors) do
    val     = Map.get(record || %{}, field.name, "") || ""
    escaped = val |> to_string_safe() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Phoenix.HTML.raw("""
    <textarea name="record[#{field.name}]" id="field_#{field.name}" class="adm-textarea">#{escaped}</textarea>
    """)
  end

  defp render_input(field, record, _config, errors) do
    val     = Map.get(record || %{}, field.name, "") |> to_string_safe()
    escaped = val |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    has_err = Map.has_key?(errors, field.name)
    border  = if has_err, do: "border-color:var(--adm-red);", else: ""

    Phoenix.HTML.raw("""
    <input type="#{field.input_type}" name="record[#{field.name}]" id="field_#{field.name}"
           value="#{escaped}" class="adm-input" style="#{border}">
    """)
  end

  defp render_inline_input(field, value, idx) do
    val     = to_string_safe(value)
    escaped = val |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    case field.input_type do
      :checkbox ->
        Phoenix.HTML.raw("""
        <label class="adm-checkbox">
          <input type="checkbox" name="record[inlines][#{idx}][#{field.name}]"
                 value="true" #{if value, do: "checked"}>
        </label>
        <input type="hidden" name="record[inlines][#{idx}][#{field.name}]" value="false">
        """)

      :select ->
        Phoenix.HTML.raw("""
        <select name="record[inlines][#{idx}][#{field.name}]" class="adm-select" style="min-width:100px;">
          <option value="">—</option>
        </select>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <input type="#{field.input_type}" name="record[inlines][#{idx}][#{field.name}]"
               value="#{escaped}" class="adm-input" style="min-width:80px;">
        """)
    end
  end

  # ---------------------------------------------------------------------------
  # Cell renderer for list view
  # ---------------------------------------------------------------------------

  defp render_cell(%{name: :is_active} = _field, true, _config) do
    Phoenix.HTML.raw(~s(<span class="badge badge-green">Active</span>))
  end
  defp render_cell(%{name: :is_active}, false, _config) do
    Phoenix.HTML.raw(~s(<span class="badge badge-red">Inactive</span>))
  end
  defp render_cell(%{name: :is_available}, true, _config) do
    Phoenix.HTML.raw(~s(<span class="badge badge-green">Available</span>))
  end
  defp render_cell(%{name: :is_available}, false, _config) do
    Phoenix.HTML.raw(~s(<span class="badge badge-red">Unavailable</span>))
  end
  defp render_cell(%{name: :status} = _field, val, _config) when not is_nil(val) do
    cls = FieldHelper.badge_for(:status, val)
    Phoenix.HTML.raw(~s(<span class="badge #{cls}">#{val}</span>))
  end
  defp render_cell(%{name: :role}, val, _config) when not is_nil(val) do
    Phoenix.HTML.raw(~s(<span class="badge badge-purple">#{val}</span>))
  end
  defp render_cell(_field, val, config) do
    formatted = FieldHelper.format_value(val, config)
    case formatted do
      {:safe, html} -> Phoenix.HTML.raw(html)
      str           -> str
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination helper
  # ---------------------------------------------------------------------------

  defp page_range(_current, total) when total <= 7, do: 1..total |> Enum.to_list()
  defp page_range(current, total) do
    left  = max(1, current - 2)
    right = min(total, current + 2)
    pages = Enum.to_list(left..right)

    left_gap  = if left  > 2,         do: [:ellipsis], else: []
    right_gap = if right < total - 1, do: [:ellipsis], else: []
    left_end  = if left  > 1,         do: [1],         else: []
    right_end = if right < total,     do: [total],      else: []

    left_end ++ left_gap ++ pages ++ right_gap ++ right_end
  end

  defp month_name(m) do
    ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    |> Enum.at((m || 1) - 1, "?")
  end

  # ---------------------------------------------------------------------------
  # Misc helpers
  # ---------------------------------------------------------------------------

  defp to_string_safe(nil),               do: ""
  defp to_string_safe(%Decimal{} = d),    do: Decimal.to_string(d)
  defp to_string_safe(%DateTime{} = dt),  do: DateTime.to_iso8601(dt) |> String.slice(0, 16)
  defp to_string_safe(v) when is_atom(v), do: Atom.to_string(v)
  defp to_string_safe(v),                 do: to_string(v)
end
