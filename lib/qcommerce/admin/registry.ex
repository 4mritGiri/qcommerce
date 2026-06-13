# lib/qcommerce/admin/registry.ex
defmodule Qcommerce.Admin.Registry do
  @moduledoc """
  Django-style admin model registry.

  Supports all major Django ModelAdmin options:

    use Qcommerce.Admin.Registry,
      schema:               Qcommerce.Catalog.Product,
      context:              Qcommerce.Catalog,
      label:                "Products",
      label_singular:       "Product",         # auto-derived if omitted
      group:                "Catalog",
      icon:                 "hero-package",
      roles:                [:super_admin, :manager],

      # List view
      list_fields:          [:id, :name, :sku, :base_price, :is_active, :inserted_at],
      list_display_links:   [:id, :name],       # clickable columns → show page
      list_select_related:  [:category],        # preload associations in list
      list_per_page:        25,
      show_full_result_count: true,

      # Search
      search_fields:        [:name, :sku, :description],

      # Filters (sidebar list_filter equivalent)
      filters:              [is_active: :boolean, status: :enum],

      # Default ordering
      ordering:             [:inserted_at],     # prefix "-" for desc: ["-inserted_at"]

      # Form
      readonly_fields:      [:id, :inserted_at, :updated_at],
      fieldsets: [
        {"Basic Info",    %{fields: [:name, :sku, :description]}},
        {"Pricing",       %{fields: [:base_price, :unit, :tax_rate], classes: ["collapse"]}},
        {"Meta",          %{fields: [:is_active, :inserted_at, :updated_at]}}
      ],
      prepopulated_fields:  [slug: :name],       # auto-fill slug from name (JS)
      date_hierarchy:       :inserted_at,        # drill-down by date

      # Display
      empty_value_display:  "—",
      save_on_top:          false,               # show save buttons at top too

      # Custom actions beyond default [:show, :edit, :delete]
      actions:              [:show, :edit, :delete],
      custom_actions: [
        %{id: "mark_active",   label: "Mark Active",   icon: "hero-check-circle", confirm: false},
        %{id: "mark_inactive", label: "Mark Inactive",  icon: "hero-x-circle",    confirm: false},
        %{id: "export_csv",    label: "Export CSV",     icon: "hero-arrow-down-tray", confirm: false}
      ],

      # Inline formsets (related models shown inline on edit page)
      inlines: [
        %{
          schema:         Qcommerce.Catalog.ProductVariant,
          context:        Qcommerce.Catalog,
          fk_field:       :product_id,
          label:          "Variants",
          fields:         [:sku, :price, :stock],
          extra:          1,        # blank rows to append
          max_num:        20,
          can_delete:     true
        }
      ],

      # Context function overrides (default: list/1, get!/2, create/2, update/3, delete/2)
      list_fn:   :list_products,
      get_fn:    :get_product!,
      create_fn: :create_product,
      update_fn: :update_product,
      delete_fn: :delete_product
  """

  @admin_modules [
    Qcommerce.Admin.ProductAdmin,
    Qcommerce.Admin.CategoryAdmin,
    Qcommerce.Admin.SlideAdmin,
    Qcommerce.Admin.FlashSaleAdmin,
    Qcommerce.Admin.CartShareAdmin,
    Qcommerce.Admin.UserAdmin,
    Qcommerce.Admin.BranchAdmin,
    Qcommerce.Admin.OrderAdmin,
    Qcommerce.Admin.OrderItemAdmin,
    Qcommerce.Admin.RiderAdmin,
    Qcommerce.Admin.BranchInventoryAdmin,
    Qcommerce.Admin.AccountAdmin,
    Qcommerce.Admin.JournalAdmin,
    Qcommerce.Admin.ProvinceAdmin,
    Qcommerce.Admin.DistrictAdmin,
    Qcommerce.Admin.LocalBodyAdmin,
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Return all registered admin configs, sorted by group then label."
  def all do
    Enum.map(@admin_modules, fn mod ->
      Code.ensure_loaded!(mod)
      mod.admin_config()
    end)
    |> Enum.sort_by(&{&1.group, &1.label})
  end

  @doc "Return configs visible to a specific user (filtered by role)."
  def all_for(nil), do: []

  def all_for(%{role: role}) do
    all()
    |> Enum.filter(fn config ->
      roles = config[:roles] || [:super_admin]
      roles == :all or role in roles
    end)
  end

  @doc "Return config for a specific schema module (as string slug or atom)."
  def get(schema_slug) when is_binary(schema_slug) do
    all() |> Enum.find(&(schema_to_slug(&1.schema) == schema_slug))
  end

  def get(schema_mod) when is_atom(schema_mod) do
    all() |> Enum.find(&(&1.schema == schema_mod))
  end

  @doc "Grouped registry entries for the sidebar nav."
  def grouped do
    all()
    |> Enum.group_by(& &1.group)
    |> Enum.sort_by(fn {group, _} -> group end)
  end

  @doc "Grouped registry entries filtered to what the given user can see."
  def grouped_for(nil), do: []

  def grouped_for(user) do
    all_for(user)
    |> Enum.group_by(& &1.group)
    |> Enum.sort_by(fn {group, _} -> group end)
  end

  @doc "Convert a schema module name to a URL-safe slug, e.g. Qcommerce.Catalog.Product -> product"
  def schema_to_slug(schema_mod) do
    schema_mod
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end

  @doc "Checks if a user has a specific permission on a config."
  def can?(user, config, action) when action in [:create, :edit, :delete] do
    roles = Map.get(config, :roles, [:super_admin])
    roles == :all or user.role in roles
  end

  def can?(_user, _config, :show), do: true
  def can?(_user, _config, _), do: false

  # ---------------------------------------------------------------------------
  # __using__ macro — injects admin_config/0 into each admin module
  # ---------------------------------------------------------------------------

  defmacro __using__(opts) do
    env = __CALLER__

    label = Keyword.get(opts, :label, "Records")

    label_singular =
      Keyword.get(opts, :label_singular) ||
        if String.ends_with?(label, "ies"),
          do: String.replace_suffix(label, "ies", "y"),
          else: String.replace_suffix(label, "s", "")

    schema_mod  = opts |> Keyword.fetch!(:schema)  |> Macro.expand(env)
    context_mod = opts |> Keyword.fetch!(:context) |> Macro.expand(env)

    # Inlines: expand schema/context module aliases at compile time.
    # Other values (fk_field, label, fields, etc.) are plain atoms/strings
    # so they survive unquote correctly without Macro.escape.
    expanded_inlines =
      Keyword.get(opts, :inlines, [])
      |> Enum.map(fn {:%{}, meta, kvs} ->
        updated =
          Enum.map(kvs, fn
            {:schema,  s} -> {:schema,  Macro.expand(s, env)}
            {:context, c} -> {:context, Macro.expand(c, env)}
            other         -> other
          end)
        {:%{}, meta, updated}
      end)

    # custom_actions, fieldsets, filters etc. contain only plain Elixir
    # literals (strings, atoms, booleans). Injecting their AST directly
    # via unquote lets the compiler evaluate them to real maps/tuples at
    # runtime — avoiding the double-escape that Macro.escape(config) caused.
    quote do
      @doc "Returns the admin config map for this registered module."
      def admin_config do
        %{
          schema:               unquote(schema_mod),
          context:              unquote(context_mod),
          label:                unquote(label),
          label_singular:       unquote(label_singular),
          group:                unquote(Keyword.get(opts, :group, "General")),
          icon:                 unquote(Keyword.get(opts, :icon, "hero-document")),
          roles:                unquote(Keyword.get(opts, :roles, [:super_admin])),
          list_fields:          unquote(Keyword.get(opts, :list_fields, [:id, :inserted_at])),
          list_display_links:   unquote(Keyword.get(opts, :list_display_links, [:id])),
          list_select_related:  unquote(Keyword.get(opts, :list_select_related, [])),
          list_per_page:        unquote(Keyword.get(opts, :list_per_page, 25)),
          show_full_result_count: unquote(Keyword.get(opts, :show_full_result_count, true)),
          date_hierarchy:       unquote(Keyword.get(opts, :date_hierarchy)),
          search_fields:        unquote(Keyword.get(opts, :search_fields, [])),
          filters:              unquote(Keyword.get(opts, :filters, [])),
          ordering:             unquote(Keyword.get(opts, :ordering, ["-inserted_at"])),
          readonly_fields:      unquote(Keyword.get(opts, :readonly_fields, [:id, :inserted_at, :updated_at])),
          fieldsets:            unquote(Keyword.get(opts, :fieldsets)),
          prepopulated_fields:  unquote(Keyword.get(opts, :prepopulated_fields, [])),
          save_on_top:          unquote(Keyword.get(opts, :save_on_top, false)),
          empty_value_display:  unquote(Keyword.get(opts, :empty_value_display, "—")),
          actions:              unquote(Keyword.get(opts, :actions, [:show, :edit, :delete])),
          custom_actions:       unquote(Keyword.get(opts, :custom_actions, [])),
          inlines:              unquote(expanded_inlines),
          list_fn:              unquote(Keyword.get(opts, :list_fn, :list)),
          get_fn:               unquote(Keyword.get(opts, :get_fn, :get)),
          create_fn:            unquote(Keyword.get(opts, :create_fn, :create)),
          update_fn:            unquote(Keyword.get(opts, :update_fn, :update)),
          delete_fn:            unquote(Keyword.get(opts, :delete_fn, :delete))
        }
      end
    end
  end
end
