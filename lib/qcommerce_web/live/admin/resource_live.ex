# lib/qcommerce_web/live/admin/resource_live.ex
#
# Generic CRUD LiveView — auto-generates list, show, new, edit from the
# registered admin config + Ecto schema introspection.
# URL pattern: /admin/r/:resource          → :list  (live_action: :list)
#              /admin/r/:resource/new      → :new   (live_action: :new)
#              /admin/r/:resource/:id      → :show  (live_action: :show)
#              /admin/r/:resource/:id/edit → :edit  (live_action: :edit)

defmodule QcommerceWeb.Admin.ResourceLive do
  use QcommerceWeb, :live_view

  alias Qcommerce.{Repo, Admin.Registry, Admin.FieldHelper}
  alias Qcommerce.Accounts.User

  @per_page 25

  # ---------------------------------------------------------------------------
  # mount/3 — auth guard + registry lookup
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"resource" => slug} = _params, session, socket) do
    user_id = session["user_id"]
    user    = user_id && Repo.get(User, user_id)

    if is_nil(user) or user.role != :super_admin do
      {:ok, push_navigate(socket, to: "/")}
    else
      config = Registry.get(slug)

      if is_nil(config) do
        {:ok,
         socket
         |> put_flash(:error, "Model '#{slug}' is not registered.")
         |> push_navigate(to: "/admin")}
      else
        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:config, config)
         |> assign(:resource_slug, Registry.schema_to_slug(config.schema))
         |> assign(:admin_resource, config.schema)
         |> assign(:per_page, @per_page)}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # handle_params — primary driver (called after mount on every navigation)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(params, _uri, socket) do
    # Only proceed once config is loaded (mount sets it)
    if config = socket.assigns[:config] do
      action = socket.assigns.live_action
      {:noreply, load_page(socket, config, action, params)}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Page loader
  # ---------------------------------------------------------------------------

  defp load_page(socket, config, action, params) do
    q = params["q"] || ""
    page = String.to_integer(params["page"] || "1")
    sort_by = params["sort_by"] || "id"
    sort_dir = params["sort_dir"] || "desc"

    filter_names = filterable_fields(config.schema) |> Enum.map(&to_string(&1.name))
    filters = Map.take(params, filter_names)

    base =
      socket
      |> assign(:action, action)
      |> assign(:search, q)
      |> assign(:page, page)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:filters, filters)

    case action do
      :list  -> load_list(base, config, params)
      :show  -> load_record(base, config, params["id"])
      :edit  -> load_edit(base, config, params["id"])
      :new   -> load_new(base, config)
    end
  end

  defp load_list(socket, config, params) do
    q       = params["q"] || ""
    page    = String.to_integer(params["page"] || "1")
    sort_by = params["sort_by"] || "id"
    sort_dir = params["sort_dir"] || "desc"

    filter_names = filterable_fields(config.schema) |> Enum.map(&to_string(&1.name))
    filters = Map.take(params, filter_names)

    {records, total} = fetch_list(config, q, page, sort_by, sort_dir, filters)
    filter_opts = fetch_filter_options(config.schema)
    slug = socket.assigns.resource_slug

    socket
    |> assign(:page_title, config.label)
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, nil}])
    |> assign(:records, records)
    |> assign(:total, total)
    |> assign(:total_pages, max(1, ceil(total / @per_page)))
    |> assign(:list_fields, FieldHelper.fields_for(config.schema, config.list_fields))
    |> assign(:filter_options, filter_opts)
    |> assign(:selected_ids, [])
    |> assign(:resource_slug, slug)
  end

  defp load_record(socket, config, id) do
    record = Repo.get(config.schema, id)
    all_fields = FieldHelper.fields_for(config.schema)
    slug = socket.assigns.resource_slug

    socket
    |> assign(:page_title, "#{config.label} ##{id}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"##{id}", nil}])
    |> assign(:record, record)
    |> assign(:all_fields, all_fields)
  end

  defp load_edit(socket, config, id) do
    record = Repo.get(config.schema, id)
    form_fields = form_fields_for(config)
    slug = socket.assigns.resource_slug

    socket
    |> assign(:page_title, "Edit #{config.label} ##{id}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"Edit ##{id}", nil}])
    |> assign(:record, record)
    |> assign(:form_fields, form_fields)
    |> assign(:changeset_errors, %{})
    |> init_autocomplete(form_fields, record)
  end

  defp load_new(socket, config) do
    form_fields = form_fields_for(config)
    slug = socket.assigns.resource_slug
    record = struct(config.schema)

    socket
    |> assign(:page_title, "New #{config.label}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"New", nil}])
    |> assign(:record, record)
    |> assign(:form_fields, form_fields)
    |> assign(:changeset_errors, %{})
    |> init_autocomplete(form_fields, record)
  end

  defp form_fields_for(config) do
    all = FieldHelper.fields_for(config.schema)
    readonly = config.readonly_fields || []
    Enum.reject(all, fn f -> f.name in readonly end)
  end

  # ---------------------------------------------------------------------------
  # Data fetching (generic — bypasses context, queries schema directly)
  # ---------------------------------------------------------------------------

  defp fetch_list(config, q, page, sort_by, sort_dir, filters) do
    import Ecto.Query

    base =
      from(r in config.schema)
      |> maybe_search(config, q)
      |> maybe_filter(config.schema, filters)

    total = Repo.aggregate(base, :count)

    offset_val = (page - 1) * @per_page
    order_field = String.to_atom(sort_by)
    order_direction = String.to_atom(sort_dir)

    records =
      base
      |> limit(@per_page)
      |> offset(^offset_val)
      |> order_by([r], [{^order_direction, field(r, ^order_field)}])
      |> Repo.all()

    {records, total}
  end

  defp maybe_search(query, _config, ""), do: query
  defp maybe_search(query, _config, nil), do: query
  defp maybe_search(query, config, q) do
    import Ecto.Query
    fields = config.search_fields

    if fields == [] do
      query
    else
      like_q = "%#{q}%"
      conditions =
        Enum.reduce(fields, false, fn field, acc ->
          dynamic([r], ilike(field(r, ^field), ^like_q) or ^acc)
        end)
      where(query, ^conditions)
    end
  end

  defp maybe_filter(query, schema_mod, filters) do
    import Ecto.Query

    Enum.reduce(filters, query, fn {field_str, val}, q_acc ->
      if val == "" or val == nil do
        q_acc
      else
        field_atom = String.to_atom(field_str)
        type = schema_mod.__schema__(:type, field_atom)

        cond do
          type == :boolean ->
            bool_val = (val == "true")
            where(q_acc, [r], field(r, ^field_atom) == ^bool_val)

          match?({:parameterized, {Ecto.Enum, _}}, type) or match?({:parameterized, Ecto.Enum, _}, type) ->
            enum_val = String.to_atom(val)
            where(q_acc, [r], field(r, ^field_atom) == ^enum_val)

          true ->
            where(q_acc, [r], field(r, ^field_atom) == ^val)
        end
      end
    end)
  end

  defp filterable_fields(schema_mod) do
    fields = FieldHelper.fields_for(schema_mod)
    Enum.filter(fields, fn f ->
      f.type == :boolean or 
      match?({:parameterized, {Ecto.Enum, _}}, f.type) or
      match?({:parameterized, Ecto.Enum, _}, f.type) or
      f.input_type == :autocomplete
    end)
  end

  defp fetch_filter_options(schema_mod) do
    filterable_fields(schema_mod)
    |> Map.new(fn f ->
      opts =
        cond do
          f.type == :boolean ->
            [{"Yes", "true"}, {"No", "false"}]

          match?({:parameterized, {Ecto.Enum, _}}, f.type) or match?({:parameterized, Ecto.Enum, _}, f.type) ->
            FieldHelper.enum_values(schema_mod, f.name)
            |> Enum.map(fn val -> {String.capitalize(to_string(val)), to_string(val)} end)

          f.input_type == :autocomplete ->
            target_schema = f.assoc.schema
            try do
              import Ecto.Query
              Repo.all(from(x in target_schema, limit: 50))
              |> Enum.map(fn rec -> {assoc_label(rec), to_string(rec.id)} end)
            rescue
              _ -> []
            end

          true ->
            []
        end

      {to_string(f.name), opts}
    end)
  end

  defp assoc_label(nil), do: ""
  defp assoc_label(record) do
    cond do
      Map.has_key?(record, :name) -> record.name
      Map.has_key?(record, :label) -> record.label
      Map.has_key?(record, :title) -> record.title
      Map.has_key?(record, :full_name) -> record.full_name
      Map.has_key?(record, :code) -> "#{record.code}"
      Map.has_key?(record, :email) -> record.email
      Map.has_key?(record, :sku) -> "[#{record.sku}]"
      true -> "##{record.id}"
    end
  end

  defp init_autocomplete(socket, form_fields, record) do
    autocompletes = Enum.filter(form_fields, &(&1.input_type == :autocomplete))

    {searches, results, selected} =
      Enum.reduce(autocompletes, {%{}, %{}, %{}}, fn field, {s_acc, r_acc, sel_acc} ->
        import Ecto.Query
        initial_list = Repo.all(from(x in field.assoc.schema, limit: 10))
        current_val = Map.get(record || %{}, field.name)
        selected_rec = if current_val, do: Repo.get(field.assoc.schema, current_val), else: nil

        {
          Map.put(s_acc, to_string(field.name), ""),
          Map.put(r_acc, to_string(field.name), initial_list),
          Map.put(sel_acc, to_string(field.name), selected_rec)
        }
      end)

    socket
    |> assign(:autocomplete_search, searches)
    |> assign(:autocomplete_results, results)
    |> assign(:autocomplete_selected, selected)
    |> assign(:autocomplete_open, Map.new(autocompletes, &{to_string(&1.name), false}))
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    path = current_path(socket, %{"q" => q, "page" => "1"})
    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("page", %{"p" => p}, socket) do
    path = current_path(socket, %{"page" => to_string(p)})
    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("sort", %{"field" => field_name}, socket) do
    current_by = socket.assigns.sort_by
    current_dir = socket.assigns.sort_dir

    {new_by, new_dir} =
      if current_by == field_name do
        {field_name, if(current_dir == "asc", do: "desc", else: "asc")}
      else
        {field_name, "asc"}
      end

    path = current_path(socket, %{"sort_by" => new_by, "sort_dir" => new_dir, "page" => "1"})
    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("filter_select", %{"field" => field_name, "value" => val}, socket) do
    new_filters =
      if val == "" do
        Map.delete(socket.assigns.filters, field_name)
      else
        Map.put(socket.assigns.filters, field_name, val)
      end

    slug = socket.assigns.resource_slug
    q = socket.assigns.search
    sort_by = socket.assigns.sort_by
    sort_dir = socket.assigns.sort_dir

    query_params =
      %{"q" => q, "page" => "1", "sort_by" => sort_by, "sort_dir" => sort_dir}
      |> Map.merge(new_filters)
      |> URI.encode_query()

    {:noreply, push_patch(socket, to: "/admin/r/#{slug}?#{query_params}")}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    id_str = to_string(id)
    selected = socket.assigns.selected_ids

    new_selected =
      if id_str in selected do
        List.delete(selected, id_str)
      else
        [id_str | selected]
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  def handle_event("toggle_select_all", _params, socket) do
    records = socket.assigns.records
    selected = socket.assigns.selected_ids

    all_page_ids = Enum.map(records, &to_string(&1.id))
    all_selected? = Enum.all?(all_page_ids, &(&1 in selected))

    new_selected =
      if all_selected? do
        selected -- all_page_ids
      else
        Enum.uniq(selected ++ all_page_ids)
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  def handle_event("bulk_action", %{"action" => "delete"}, socket) do
    config = socket.assigns.config
    ids = socket.assigns.selected_ids

    import Ecto.Query
    query = from(r in config.schema, where: r.id in ^ids)

    case Repo.delete_all(query) do
      {count, _} ->
        socket =
          socket
          |> put_flash(:info, "Successfully deleted #{count} records.")
          |> assign(:selected_ids, [])
          |> push_patch(to: current_path(socket, %{"page" => "1"}))

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Bulk delete failed.")}
    end
  end

  def handle_event("bulk_action", _, socket) do
    {:noreply, socket}
  end

  def handle_event("autocomplete_toggle", %{"field" => field_name}, socket) do
    open = socket.assigns.autocomplete_open
    current = Map.get(open, field_name, false)
    {:noreply, assign(socket, :autocomplete_open, Map.put(open, field_name, !current))}
  end

  def handle_event("autocomplete_search", %{"field" => field_name, "value" => query}, socket) do
    field = Enum.find(socket.assigns.form_fields, &(to_string(&1.name) == field_name))

    if field do
      target_schema = field.assoc.schema
      import Ecto.Query

      q = from(x in target_schema) |> limit(10)

      fields_to_search =
        cond do
          function_exported?(target_schema, :__schema__, 2) ->
            schema_fields = target_schema.__schema__(:fields)
            Enum.filter([:name, :title, :full_name, :code, :email, :sku], &(&1 in schema_fields))
          true ->
            []
        end

      matching_query =
        if query != "" and fields_to_search != [] do
          like_q = "%#{query}%"
          conditions = Enum.reduce(fields_to_search, false, fn f, acc ->
            dynamic([x], ilike(field(x, ^f), ^like_q) or ^acc)
          end)
          where(q, ^conditions)
        else
          q
        end

      results = Repo.all(matching_query)

      socket =
        socket
        |> assign(:autocomplete_search, Map.put(socket.assigns.autocomplete_search, field_name, query))
        |> assign(:autocomplete_results, Map.put(socket.assigns.autocomplete_results, field_name, results))
        |> assign(:autocomplete_open, Map.put(socket.assigns.autocomplete_open, field_name, true))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("autocomplete_select", %{"field" => field_name, "id" => id}, socket) do
    field = Enum.find(socket.assigns.form_fields, &(to_string(&1.name) == field_name))

    if field do
      selected_rec = Repo.get(field.assoc.schema, id)
      updated_record = Map.put(socket.assigns.record, field.name, id)

      socket =
        socket
        |> assign(:record, updated_record)
        |> assign(:autocomplete_selected, Map.put(socket.assigns.autocomplete_selected, field_name, selected_rec))
        |> assign(:autocomplete_open, Map.put(socket.assigns.autocomplete_open, field_name, false))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("autocomplete_clear", %{"field" => field_name}, socket) do
    field = Enum.find(socket.assigns.form_fields, &(to_string(&1.name) == field_name))

    if field do
      updated_record = Map.put(socket.assigns.record, field.name, nil)

      socket =
        socket
        |> assign(:record, updated_record)
        |> assign(:autocomplete_selected, Map.put(socket.assigns.autocomplete_selected, field_name, nil))
        |> assign(:autocomplete_open, Map.put(socket.assigns.autocomplete_open, field_name, false))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    config = socket.assigns.config
    record = Repo.get!(config.schema, id)

    case Repo.delete(record) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Record ##{id} deleted.")
         |> push_navigate(to: "/admin/r/#{socket.assigns.resource_slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete record ##{id}.")}
    end
  end

  def handle_event("save", %{"record" => attrs}, socket) do
    config = socket.assigns.config
    record = socket.assigns.record
    slug   = socket.assigns.resource_slug

    # Choose the right changeset fn — default is :changeset/2
    cs_fn = fn struct, a ->
      if function_exported?(config.schema, :changeset, 2) do
        config.schema.changeset(struct, a)
      else
        Ecto.Changeset.cast(struct, a, [])
      end
    end

    result =
      if is_nil(Map.get(record, :id)) do
        struct(config.schema) |> cs_fn.(stringify_keys(attrs)) |> Repo.insert()
      else
        record |> cs_fn.(stringify_keys(attrs)) |> Repo.update()
      end

    case result do
      {:ok, saved} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved successfully.")
         |> push_navigate(to: "/admin/r/#{slug}/#{saved.id}")}

      {:error, %Ecto.Changeset{} = cs} ->
        errors =
          Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {k, v}, acc ->
              String.replace(acc, "%{#{k}}", to_string(v))
            end)
          end)
        {:noreply, assign(socket, :changeset_errors, errors)}
    end
  end

  defp current_path(socket, extra_params \\ %{}) do
    slug = socket.assigns.resource_slug
    q = socket.assigns.search
    page = socket.assigns.page
    sort_by = socket.assigns.sort_by
    sort_dir = socket.assigns.sort_dir

    query_params =
      %{"q" => q, "page" => to_string(page), "sort_by" => sort_by, "sort_dir" => sort_dir}
      |> Map.merge(socket.assigns.filters)
      |> Map.merge(extra_params)
      |> URI.encode_query()

    "/admin/r/#{slug}?#{query_params}"
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  # ---------------------------------------------------------------------------
  # render/1 — dispatches to sub-renders
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    # Guard: handle_params hasn't fired yet
    if Map.get(assigns, :action) == nil do
      ~H"""
      <div style="padding:40px;color:var(--adm-text2);">Loading…</div>
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

  # ── List view ──────────────────────────────────────────────────────────────

  defp render_list(assigns) do
    ~H"""
    <div class="adm-page-header" style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;">
      <div>
        <h1 class="adm-page-title"><%= @config.icon %> <%= @config.label %></h1>
        <p class="adm-page-sub">
          <%= @total %> records total
          <%= if map_size(@filters) > 0 do %><span style="color:var(--adm-accent2);margin-left:6px;">· <%= map_size(@filters) %> filter(s) active</span><% end %>
        </p>
      </div>
      <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
        <a href={"/admin/r/#{@resource_slug}/new"} class="adm-btn adm-btn-primary">+ New <%= @config.label |> String.replace(~r/s$/, "") %></a>
      <% end %>
    </div>

    <div class="adm-card">
      <!-- Toolbar -->
      <div class="adm-toolbar">
        <form phx-submit="search" style="display:contents;">
          <div class="adm-search-wrap">
            <span class="adm-search-icon">🔍</span>
            <input id="adm-search" type="text" name="q" value={@search}
              placeholder={"Search #{@config.label |> String.downcase()}…"}
              class="adm-search" phx-debounce="350" phx-change="search" />
          </div>
        </form>

        <%= for {field_name, opts} <- @filter_options do %>
          <% current_val = Map.get(@filters, field_name, "") %>
          <select class="adm-select" style="height:34px;min-width:110px;font-size:12px;"
            phx-change="filter_select" phx-value-field={field_name}>
            <option value=""><%= Qcommerce.Admin.FieldHelper.humanize(field_name) %>: All</option>
            <%= for {label, val} <- opts do %>
              <option value={val} selected={val == current_val}><%= label %></option>
            <% end %>
          </select>
        <% end %>

        <div class="adm-spacer"></div>

        <%= if @selected_ids != [] do %>
          <span style="font-size:12px;color:var(--adm-accent2);font-weight:600;"><%= length(@selected_ids) %> selected</span>
          <form phx-submit="bulk_action" style="display:contents;">
            <select name="action" class="adm-select" style="height:34px;font-size:12px;">
              <option value="">— Action —</option>
              <%= if :delete in (@config.actions || [:show, :edit, :delete]) do %>
                <option value="delete">Delete selected</option>
              <% end %>
            </select>
            <button type="submit" class="adm-btn adm-btn-danger" style="height:34px;">Apply</button>
          </form>
        <% end %>

        <span style="font-size:11px;color:var(--adm-text2);">Page <%= @page %> / <%= @total_pages %></span>
      </div>

      <!-- Table -->
      <div class="adm-table-wrap">
        <%= if @records == [] do %>
          <div class="adm-empty">
            <div class="adm-empty-icon"><%= @config.icon %></div>
            <div class="adm-empty-msg">No <%= @config.label |> String.downcase() %> found</div>
            <div class="adm-empty-sub">Try a different search or add a new record.</div>
          </div>
        <% else %>
          <table class="adm-table">
            <thead>
              <tr>
                <th style="width:38px;padding:10px 8px;">
                  <input type="checkbox" phx-click="toggle_select_all"
                    style="cursor:pointer;accent-color:var(--adm-accent);" />
                </th>
                <%= for field <- @list_fields do %>
                  <th style="cursor:pointer;user-select:none;" phx-click="sort" phx-value-field={to_string(field.name)}>
                    <%= field.label %>
                    <%= if @sort_by == to_string(field.name) do %>
                      <span style="color:var(--adm-accent2);"><%= if @sort_dir == "asc", do: "↑", else: "↓" %></span>
                    <% end %>
                  </th>
                <% end %>
                <th style="text-align:right;">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for record <- @records do %>
                <% is_sel = to_string(record.id) in @selected_ids %>
                <tr style={if is_sel, do: "background:rgba(99,102,241,.07);", else: ""}>
                  <td style="padding:8px;width:38px;">
                    <input type="checkbox" phx-click="toggle_select" phx-value-id={record.id}
                      style="cursor:pointer;accent-color:var(--adm-accent);" checked={is_sel} />
                  </td>
                  <%= for field <- @list_fields do %>
                    <td class={if field.name == :id, do: "adm-id"}>
                      <%= render_cell(field, Map.get(record, field.name)) %>
                    </td>
                  <% end %>
                  <td style="text-align:right;white-space:nowrap;">
                    <a href={"/admin/r/#{@resource_slug}/#{record.id}"} class="adm-btn adm-btn-ghost" style="font-size:11px;height:28px;padding:0 10px;">View</a>
                    <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
                      <a href={"/admin/r/#{@resource_slug}/#{record.id}/edit"} class="adm-btn adm-btn-ghost" style="font-size:11px;height:28px;padding:0 10px;margin-left:4px;">Edit</a>
                    <% end %>
                    <%= if :delete in (@config.actions || [:show, :edit, :delete]) do %>
                      <button phx-click="delete" phx-value-id={record.id}
                        data-confirm={"Delete ##{record.id}?"}
                        class="adm-btn adm-btn-danger"
                        style="font-size:11px;height:28px;padding:0 10px;margin-left:4px;">Del</button>
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
          <span style="margin-right:8px;color:var(--adm-text2);">
            Showing <%= (@page - 1) * @per_page + 1 %>–<%= min(@page * @per_page, @total) %> of <%= @total %>
          </span>
          <%= if @page > 1 do %>
            <button phx-click="page" phx-value-p={@page - 1} class="adm-page-btn">‹</button>
          <% end %>
          <%= for p <- page_range(@page, @total_pages) do %>
            <%= if p == :ellipsis do %>
              <span style="color:var(--adm-text3);padding:0 4px;">…</span>
            <% else %>
              <button phx-click="page" phx-value-p={p} class={"adm-page-btn #{if p == @page, do: "current"}"}><%= p %></button>
            <% end %>
          <% end %>
          <%= if @page < @total_pages do %>
            <button phx-click="page" phx-value-p={@page + 1} class="adm-page-btn">›</button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_cell(%{name: :is_active} = _field, true),  do: Phoenix.HTML.raw(~s(<span class="badge badge-green">Active</span>))
  defp render_cell(%{name: :is_active} = _field, false), do: Phoenix.HTML.raw(~s(<span class="badge badge-red">Inactive</span>))
  defp render_cell(%{name: :is_available} = _field, true),  do: Phoenix.HTML.raw(~s(<span class="badge badge-green">Available</span>))
  defp render_cell(%{name: :is_available} = _field, false), do: Phoenix.HTML.raw(~s(<span class="badge badge-red">Unavailable</span>))
  defp render_cell(%{name: :status} = _field, val) when not is_nil(val) do
    cls = status_badge_class(val)
    Phoenix.HTML.raw(~s(<span class="badge #{cls}">#{val}</span>))
  end
  defp render_cell(%{name: :role} = _field, val) when not is_nil(val) do
    Phoenix.HTML.raw(~s(<span class="badge badge-blue">#{val}</span>))
  end
  defp render_cell(_field, val), do: FieldHelper.format_value(val)

  defp status_badge_class(:pending),          do: "badge-yellow"
  defp status_badge_class(:delivered),        do: "badge-green"
  defp status_badge_class(:cancelled),        do: "badge-red"
  defp status_badge_class(:rejected),         do: "badge-red"
  defp status_badge_class(:out_for_delivery), do: "badge-blue"
  defp status_badge_class(_),                 do: "badge-gray"

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

  # ── Show / Detail view ─────────────────────────────────────────────────────

  defp render_show(assigns) do
    ~H"""
    <div class="adm-page-header" style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;">
      <div>
        <h1 class="adm-page-title"><%= @config.icon %> <%= @config.label %> #<%= @record && @record.id %></h1>
        <p class="adm-page-sub">Viewing record details</p>
      </div>
      <div style="display:flex;gap:8px;">
        <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">← Back</a>
        <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
          <a href={"/admin/r/#{@resource_slug}/#{@record && @record.id}/edit"} class="adm-btn adm-btn-primary">Edit</a>
        <% end %>
        <%= if :delete in (@config.actions || [:show, :edit, :delete]) do %>
          <button phx-click="delete" phx-value-id={@record && @record.id}
            data-confirm={"Delete this record?"}
            class="adm-btn adm-btn-danger">Delete</button>
        <% end %>
      </div>
    </div>

    <%= if @record do %>
      <div class="adm-card">
        <div class="adm-card-header">
          <span class="adm-card-title">Field Values</span>
          <span style="font-size:11px;color:var(--adm-text2);font-family:monospace;"><%= inspect(@config.schema) %></span>
        </div>
        <div class="adm-card-body">
          <div class="adm-form-grid">
            <%= for field <- @all_fields do %>
              <div class={"adm-field #{if field.input_type == :textarea, do: "full"}"}>
                <div class="adm-label"><%= field.label %></div>
                <div class="adm-readonly-val">
                  <%= FieldHelper.format_value(Map.get(@record, field.name)) %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% else %>
      <div class="adm-card">
        <div class="adm-empty">
          <div class="adm-empty-icon">🔍</div>
          <div class="adm-empty-msg">Record not found</div>
        </div>
      </div>
    <% end %>
    """
  end

  # ── New / Edit form ─────────────────────────────────────────────────────────

  defp render_form(assigns, mode) do
    assigns = Phoenix.Component.assign(assigns, :form_mode, mode)

    ~H"""
    <div class="adm-page-header" style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;">
      <div>
        <h1 class="adm-page-title">
          <%= if @form_mode == :new do %>
            + New <%= @config.label |> String.replace(~r/s$/, "") %>
          <% else %>
            ✏️ Edit <%= @config.label %> #<%= @record && @record.id %>
          <% end %>
        </h1>
        <p class="adm-page-sub"><%= @config.label %> · <%= inspect(@config.schema) %></p>
      </div>
      <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">← Cancel</a>
    </div>

    <div class="adm-card">
      <div class="adm-card-header">
        <span class="adm-card-title">
          <%= if @form_mode == :new, do: "Create Record", else: "Update Record" %>
        </span>
        <span style="font-size:11px;color:var(--adm-text2);">
          * required fields
        </span>
      </div>
      <div class="adm-card-body">
        <form phx-submit="save" id="adm-form">
          <div class="adm-form-grid">
            <%= for field <- @form_fields do %>
              <% full_class = if field.input_type in [:textarea, :autocomplete], do: "full", else: "" %>
              <div class={"adm-field #{full_class}"}>
                <label class="adm-label" for={"field_#{field.name}"}>
                  <%= field.label %>
                  <%= if field.required do %><span class="req">*</span><% end %>
                </label>

                <%= if field.input_type == :autocomplete do %>
                  <%# LiveView-driven Select2-style autocomplete for FK fields %>
                  <% fkey = to_string(field.name) %>
                  <% is_open = Map.get(@autocomplete_open, fkey, false) %>
                  <% sel_rec = Map.get(@autocomplete_selected, fkey) %>
                  <% results = Map.get(@autocomplete_results, fkey, []) %>
                  <% search_q = Map.get(@autocomplete_search, fkey, "") %>
                  <% current_id = if sel_rec, do: to_string(sel_rec.id), else: "" %>

                  <input type="hidden" name={"record[#{fkey}]"} value={current_id} />
                  <div style="position:relative;">
                    <div class="adm-input" style="display:flex;align-items:center;justify-content:space-between;cursor:pointer;gap:8px;"
                      phx-click="autocomplete_toggle" phx-value-field={fkey}>
                      <span style={"#{if sel_rec, do: "color:var(--adm-text);", else: "color:var(--adm-text3);"}"}>
                        <%= if sel_rec, do: "#{Qcommerce.Admin.FieldHelper.humanize(field.assoc.assoc_name)} ##{sel_rec.id}", else: "— choose #{field.label} —" %>
                      </span>
                      <span style="color:var(--adm-text3);font-size:11px;"><%= if is_open, do: "▴", else: "▾" %></span>
                    </div>

                    <%= if is_open do %>
                      <div style="position:absolute;top:calc(100% + 4px);left:0;right:0;z-index:100;background:var(--adm-card);border:1px solid var(--adm-border);border-radius:8px;box-shadow:0 8px 24px rgba(0,0,0,.4);overflow:hidden;">
                        <div style="padding:8px;">
                          <input type="text" value={search_q} placeholder="Search…"
                            style="width:100%;background:var(--adm-surface);border:1px solid var(--adm-border);border-radius:6px;color:var(--adm-text);padding:6px 10px;font-size:12px;outline:none;"
                            phx-keyup="autocomplete_search" phx-value-field={fkey} phx-debounce="200" />
                        </div>
                        <div style="max-height:220px;overflow-y:auto;">
                          <%= if sel_rec do %>
                            <div style="padding:6px 12px;font-size:11px;color:var(--adm-accent2);border-bottom:1px solid var(--adm-border);display:flex;justify-content:space-between;align-items:center;">
                              <span>Selected: #<%= sel_rec.id %></span>
                              <button type="button" phx-click="autocomplete_clear" phx-value-field={fkey}
                                style="background:none;border:none;color:var(--adm-text3);cursor:pointer;font-size:12px;">✕ Clear</button>
                            </div>
                          <% end %>
                          <%= if results == [] do %>
                            <div style="padding:12px;text-align:center;color:var(--adm-text3);font-size:12px;">No results</div>
                          <% else %>
                            <%= for rec <- results do %>
                              <div class="adm-autocomplete-option"
                                phx-click="autocomplete_select" phx-value-field={fkey} phx-value-id={to_string(rec.id)}
                                style={"cursor:pointer;padding:8px 12px;font-size:13px;color:#{if sel_rec && sel_rec.id == rec.id, do: "var(--adm-accent2)", else: "var(--adm-text2)"};background:#{if sel_rec && sel_rec.id == rec.id, do: "rgba(99,102,241,.1)", else: "transparent"};"}>
                                <span style="font-weight:600;color:var(--adm-text3);font-family:monospace;font-size:11px;margin-right:6px;">#<%= rec.id %></span>
                                <%= Qcommerce.Admin.FieldHelper.format_value(Map.get(rec, :name) || Map.get(rec, :full_name) || Map.get(rec, :code) || Map.get(rec, :email) || "Record #{rec.id}") %>
                              </div>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <%= render_input(field, @record, @config, @changeset_errors) %>
                <% end %>

                <%= if Map.has_key?(@changeset_errors, field.name) do %>
                  <div class="adm-val-error">
                    <%= Enum.join(Map.get(@changeset_errors, field.name, []), ", ") %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div style="display:flex;gap:10px;margin-top:24px;padding-top:20px;border-top:1px solid var(--adm-border);">
            <button type="submit" class="adm-btn adm-btn-primary">
              <%= if @form_mode == :new, do: "Create", else: "Save Changes" %>
            </button>
            <a href={"/admin/r/#{@resource_slug}"} class="adm-btn adm-btn-ghost">Cancel</a>
          </div>
        </form>
      </div>
    </div>
    """
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
        sel = if to_string(opt) == to_string(val), do: "selected", else: ""
        "<option value=\"#{opt}\" #{sel}>#{lbl}</option>"
      end)
      |> Enum.join("")

    Phoenix.HTML.raw("""
    <div style="position:relative;">
      <select name="record[#{field.name}]" id="field_#{field.name}" class="adm-select adm-select2">
        <option value="">— choose —</option>
        #{options_html}
      </select>
    </div>
    """)
  end

  defp render_input(%{input_type: :autocomplete} = field, record, _config, _errors) do
    # renders a JS-free LiveView-driven autocomplete (Select2 style)
    # Actual result list and open state come from socket assigns
    fkey = to_string(field.name)
    val  = Map.get(record || %{}, field.name)
    val_str = to_string_safe(val)

    Phoenix.HTML.raw("""
    <div class="adm-ac" data-field="#{fkey}">
      <input type="hidden" name="record[#{fkey}]" value="#{val_str}">
      <div class="adm-ac-trigger" phx-click="autocomplete_toggle" phx-value-field="#{fkey}">
        <span class="adm-ac-value" id="adm-ac-label-#{fkey}">Loading…</span>
        <span style="color:var(--adm-text3);font-size:12px;">▾</span>
      </div>
    </div>
    """)
  end

  defp render_input(%{input_type: :textarea} = field, record, _config, _errors) do
    val = Map.get(record || %{}, field.name, "") || ""
    escaped = val |> to_string_safe() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Phoenix.HTML.raw("""
    <textarea name="record[#{field.name}]" id="field_#{field.name}" class="adm-textarea">#{escaped}</textarea>
    """)
  end

  defp render_input(field, record, _config, _errors) do
    val = Map.get(record || %{}, field.name, "") |> to_string_safe()
    escaped = val |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Phoenix.HTML.raw("""
    <input type="#{field.input_type}" name="record[#{field.name}]" id="field_#{field.name}"
           value="#{escaped}" class="adm-input">
    """)
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(%Decimal{} = d), do: Decimal.to_string(d)
  defp to_string_safe(%DateTime{} = dt), do: DateTime.to_iso8601(dt) |> String.slice(0, 16)
  defp to_string_safe(v) when is_atom(v), do: Atom.to_string(v)
  defp to_string_safe(v), do: to_string(v)
end
