# lib/qcommerce/admin/registry.ex
defmodule Qcommerce.Admin.Registry do
  @moduledoc """
  Django-style admin model registry.

  To register a model:

      use Qcommerce.Admin.Registry,
        schema: Qcommerce.Catalog.Product,
        context: Qcommerce.Catalog,
        label: "Products",
        group: "Catalog",
        icon: "📦",
        list_fields: [:id, :name, :sku, :base_price, :is_active, :inserted_at],
        search_fields: [:name, :sku],
        readonly_fields: [:id, :inserted_at, :updated_at],
        filters: [is_active: :boolean]
  """

  @admin_modules [
    Qcommerce.Admin.ProductAdmin,
    Qcommerce.Admin.CategoryAdmin,
    Qcommerce.Admin.SlideAdmin,
    Qcommerce.Admin.FlashSaleAdmin,
    Qcommerce.Admin.UserAdmin,
    Qcommerce.Admin.BranchAdmin,
    Qcommerce.Admin.OrderAdmin,
    Qcommerce.Admin.OrderItemAdmin,
    Qcommerce.Admin.RiderAdmin,
    Qcommerce.Admin.BranchInventoryAdmin
  ]

  @doc "Return all registered admin configs, sorted by group then label."
  def all do
    Enum.map(@admin_modules, fn mod ->
      Code.ensure_loaded!(mod)
      mod.admin_config()
    end)
    |> Enum.sort_by(&{&1.group, &1.label})
  end

  @doc "Return config for a specific schema module (as string slug or atom)."
  def get(schema_slug) when is_binary(schema_slug) do
    all()
    |> Enum.find(&(schema_to_slug(&1.schema) == schema_slug))
  end

  def get(schema_mod) when is_atom(schema_mod) do
    all()
    |> Enum.find(&(&1.schema == schema_mod))
  end

  @doc "Grouped registry entries for the sidebar nav."
  def grouped do
    all()
    |> Enum.group_by(& &1.group)
    |> Enum.sort_by(fn {group, _} -> group end)
  end

  @doc "Convert a schema module name to a URL-safe slug, e.g. Qcommerce.Catalog.Product -> catalog-product"
  def schema_to_slug(schema_mod) do
    schema_mod
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      def admin_config do
        %{
          schema:          Keyword.fetch!(unquote(opts), :schema),
          context:         Keyword.fetch!(unquote(opts), :context),
          label:           Keyword.get(unquote(opts), :label, "Records"),
          group:           Keyword.get(unquote(opts), :group, "General"),
          icon:            Keyword.get(unquote(opts), :icon, "📋"),
          list_fields:     Keyword.get(unquote(opts), :list_fields, [:id, :inserted_at]),
          search_fields:   Keyword.get(unquote(opts), :search_fields, []),
          readonly_fields: Keyword.get(unquote(opts), :readonly_fields, [:id, :inserted_at, :updated_at]),
          filters:         Keyword.get(unquote(opts), :filters, []),
          actions:         Keyword.get(unquote(opts), :actions, [:show, :edit, :delete]),
          per_page:        Keyword.get(unquote(opts), :per_page, 25),
          list_fn:         Keyword.get(unquote(opts), :list_fn, :list),
          get_fn:          Keyword.get(unquote(opts), :get_fn, :get),
          create_fn:       Keyword.get(unquote(opts), :create_fn, :create),
          update_fn:       Keyword.get(unquote(opts), :update_fn, :update),
          delete_fn:       Keyword.get(unquote(opts), :delete_fn, :delete)
        }
      end
    end
  end
end
