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
    base =
      socket
      |> assign(:action, action)
      |> assign(:search, params["q"] || "")
      |> assign(:page, String.to_integer(params["page"] || "1"))

    case action do
      :list  -> load_list(base, config, params)
      :show  -> load_record(base, config, params["id"])
      :edit  -> load_edit(base, config, params["id"])
      :new   -> load_new(base, config)
    end
  end

  defp load_list(socket, config, params) do
    q    = params["q"] || ""
    page = String.to_integer(params["page"] || "1")
    {records, total} = fetch_list(config, q, page)
    slug = socket.assigns.resource_slug

    socket
    |> assign(:page_title, config.label)
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, nil}])
    |> assign(:records, records)
    |> assign(:total, total)
    |> assign(:total_pages, max(1, ceil(total / @per_page)))
    |> assign(:list_fields, FieldHelper.fields_for(config.schema, config.list_fields))
    |> assign(:filters, %{})
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
  end

  defp load_new(socket, config) do
    form_fields = form_fields_for(config)
    slug = socket.assigns.resource_slug

    socket
    |> assign(:page_title, "New #{config.label}")
    |> assign(:breadcrumb, [{"Admin", "/admin"}, {config.label, "/admin/r/#{slug}"}, {"New", nil}])
    |> assign(:record, struct(config.schema))
    |> assign(:form_fields, form_fields)
    |> assign(:changeset_errors, %{})
  end

  defp form_fields_for(config) do
    all = FieldHelper.fields_for(config.schema)
    readonly = config.readonly_fields || []
    Enum.reject(all, fn f -> f.name in readonly end)
  end

  # ---------------------------------------------------------------------------
  # Data fetching (generic — bypasses context, queries schema directly)
  # ---------------------------------------------------------------------------

  defp fetch_list(config, q, page) do
    import Ecto.Query

    base =
      from(r in config.schema)
      |> maybe_search(config, q)

    total = Repo.aggregate(base, :count)

    offset_val = (page - 1) * @per_page

    records =
      base
      |> limit(@per_page)
      |> offset(^offset_val)
      |> order_by([r], desc: r.id)
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

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    slug = socket.assigns.resource_slug
    {:noreply, push_patch(socket, to: "/admin/r/#{slug}?q=#{URI.encode(q)}&page=1")}
  end

  def handle_event("page", %{"p" => p}, socket) do
    slug = socket.assigns.resource_slug
    q    = socket.assigns.search
    {:noreply, push_patch(socket, to: "/admin/r/#{slug}?q=#{URI.encode(q)}&page=#{p}")}
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
        <p class="adm-page-sub"><%= @total %> records total</p>
      </div>
      <%= if :edit in (@config.actions || [:show, :edit, :delete]) do %>
        <a href={"/admin/r/#{@resource_slug}/new"} class="adm-btn adm-btn-primary">+ Add <%= @config.label |> String.replace(~r/s$/, "") %></a>
      <% end %>
    </div>

    <div class="adm-card">
      <!-- Toolbar -->
      <div class="adm-toolbar">
        <form phx-submit="search" style="display:contents;">
          <div class="adm-search-wrap">
            <span class="adm-search-icon">🔍</span>
            <input
              id="adm-search"
              type="text" name="q" value={@search}
              placeholder={"Search #{@config.label |> String.downcase()}…"}
              class="adm-search"
              phx-debounce="350"
              phx-change="search"
            />
          </div>
        </form>
        <div class="adm-spacer"></div>
        <span style="font-size:11px;color:var(--adm-text2);">
          Page <%= @page %> / <%= @total_pages %>
        </span>
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
                <%= for field <- @list_fields do %>
                  <th><%= field.label %></th>
                <% end %>
                <th style="text-align:right;">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for record <- @records do %>
                <tr>
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
                      <button
                        phx-click="delete"
                        phx-value-id={record.id}
                        data-confirm={"Delete record ##{record.id}?"}
                        class="adm-btn adm-btn-danger"
                        style="font-size:11px;height:28px;padding:0 10px;margin-left:4px;">
                        Del
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
              <div class={"adm-field #{if field.input_type == :textarea, do: "full"}"}>
                <label class="adm-label" for={"field_#{field.name}"}>
                  <%= field.label %>
                  <%= if field.required do %><span class="req">*</span><% end %>
                </label>

                <%= render_input(field, @record, @config, @changeset_errors) %>

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
    val   = Map.get(record || %{}, field.name)
    opts  = FieldHelper.enum_values(config.schema, field.name)
    options_html =
      Enum.map(opts, fn opt ->
        sel = if to_string(opt) == to_string(val), do: "selected", else: ""
        "<option value=\"#{opt}\" #{sel}>#{opt}</option>"
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
