# lib/qcommerce/admin/admin_models.ex
# Django-style admin registrations — one module per schema.

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.ProductAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Catalog.Product,
    context:              Qcommerce.Catalog,
    label:                "Products",
    group:                "Catalog",
    icon:                 "product",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :name, :sku, :base_price, :unit, :is_active, :inserted_at],
    list_display_links:   [:id, :name],
    list_per_page:        30,
    search_fields:        [:name, :sku, :description],
    ordering:             ["-inserted_at"],
    date_hierarchy:       :inserted_at,
    readonly_fields:      [:id, :inserted_at, :updated_at],
    fieldsets: [
      {"Basic Info",  %{fields: [:name, :sku, :description]}},
      {"Pricing",     %{fields: [:base_price, :unit]}},
      {"Status",      %{fields: [:is_active], classes: ["collapse"]}}
    ],
    prepopulated_fields:  [slug: :name],
    save_on_top:          true,
    custom_actions: [
      %{id: "mark_active",   label: "Mark Active",    icon: "hero-check-circle",    confirm: false},
      %{id: "mark_inactive", label: "Mark Inactive",  icon: "hero-x-circle",        confirm: false},
      %{id: "export_csv",    label: "Export CSV",     icon: "hero-arrow-down-tray", confirm: false}
    ]
end

defmodule Qcommerce.Admin.CategoryAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Catalog.Category,
    context:              Qcommerce.Catalog,
    label:                "Categories",
    group:                "Catalog",
    icon:                 "tags",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :name, :slug, :sort_order, :is_active],
    list_display_links:   [:id, :name],
    search_fields:        [:name, :slug],
    ordering:             [:sort_order],
    readonly_fields:      [:id, :inserted_at],
    prepopulated_fields:  [slug: :name]
end

defmodule Qcommerce.Admin.SlideAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Catalog.Slide,
    context:              Qcommerce.Catalog,
    label:                "Hero Slides",
    group:                "Catalog",
    icon:                 "slideshow",
    roles:                [:super_admin],
    list_fields:          [:id, :tag, :heading, :position, :is_active],
    list_display_links:   [:id, :heading],
    search_fields:        [:tag, :heading],
    ordering:             [:position],
    readonly_fields:      [:id, :inserted_at]
end

defmodule Qcommerce.Admin.FlashSaleAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Catalog.FlashSale,
    context:              Qcommerce.Catalog,
    label:                "Flash Sales",
    group:                "Catalog",
    icon:                 "hero-bolt",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :label, :discount_pct, :ends_at, :is_active],
    list_display_links:   [:id, :label],
    search_fields:        [:label],
    ordering:             ["-ends_at"],
    readonly_fields:      [:id, :inserted_at],
    custom_actions: [
      %{id: "mark_active",   label: "Activate",   icon: "hero-check-circle", confirm: false},
      %{id: "mark_inactive", label: "Deactivate", icon: "hero-x-circle",     confirm: false}
    ]
end

# ---------------------------------------------------------------------------
# Carts & Orders
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.CartShareAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Cart.CartShare,
    context:              Qcommerce.Cart,
    label:                "Cart Shares",
    group:                "Carts & Orders",
    icon:                 "shopping-cart-share",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :token, :user_id, :inserted_at],
    list_display_links:   [:id],
    search_fields:        [:token],
    ordering:             ["-inserted_at"],
    readonly_fields:      [:id, :user_id, :token, :inserted_at, :updated_at],
    actions:              [:show]
end

# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.UserAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Accounts.User,
    context:              Qcommerce.Accounts,
    label:                "Users",
    group:                "Accounts",
    icon:                 "hero-user",
    roles:                [:super_admin],
    list_fields:          [:id, :full_name, :email, :phone, :role, :is_active, :inserted_at],
    list_display_links:   [:id, :full_name, :email],
    search_fields:        [:full_name, :email, :phone],
    ordering:             ["-inserted_at"],
    readonly_fields:      [:id, :password_hash, :inserted_at, :updated_at],
    fieldsets: [
      {"Personal Info", %{fields: [:full_name, :email, :phone]}},
      {"Access",        %{fields: [:role, :is_active]}},
      {"Security",      %{fields: [:password_hash], classes: ["collapse"]}}
    ],
    # date_hierarchy:       :inserted_at,
    custom_actions: [
      %{id: "activate_users",   label: "Activate",   icon: "hero-check-circle", confirm: false},
      %{id: "deactivate_users", label: "Deactivate", icon: "hero-x-circle",     confirm: true},
      %{id: "export_csv",       label: "Export CSV", icon: "hero-arrow-down-tray", confirm: false}
    ]
end

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.BranchAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Platform.Branch,
    context:              Qcommerce.Platform,
    label:                "Branches",
    group:                "Platform",
    icon:                 "hero-building-storefront",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :code, :name, :city, :catchment_radius_m, :is_active],
    list_display_links:   [:id, :name],
    search_fields:        [:name, :code, :city],
    ordering:             [:name],
    readonly_fields:      [:id, :location, :inserted_at, :updated_at],
    fieldsets: [
      {"Branch Info", %{fields: [:code, :name, :city]}},
      {"Coverage",    %{fields: [:catchment_radius_m]}},
      {"Status",      %{fields: [:is_active]}}
    ]
end

# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.OrderAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Orders.Order,
    context:              Qcommerce.Orders,
    label:                "Orders",
    group:                "Orders",
    icon:                 "hero-shopping-cart",
    roles:                [:super_admin, :manager, :staff],
    list_fields:          [:id, :status, :total_amount, :placed_at, :delivered_at],
    list_display_links:   [:id],
    search_fields:        [],
    ordering:             ["-placed_at"],
    date_hierarchy:       :placed_at,
    actions:              [:show],
    readonly_fields:      [:id, :user_id, :branch_id, :placed_at, :confirmed_at,
                           :picked_at, :dispatched_at, :delivered_at,
                           :cancelled_at, :inserted_at, :updated_at],
    custom_actions: [
      %{id: "export_csv", label: "Export CSV", icon: "hero-arrow-down-tray", confirm: false}
    ]
end

defmodule Qcommerce.Admin.OrderItemAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Orders.OrderItem,
    context:              Qcommerce.Orders,
    label:                "Order Items",
    group:                "Orders",
    icon:                 "watson-orders",
    roles:                [:super_admin, :manager, :staff],
    list_fields:          [:id, :order_id, :quantity, :unit_price, :line_total, :status],
    list_display_links:   [:id],
    search_fields:        [],
    ordering:             ["-inserted_at"],
    actions:              [:show],
    readonly_fields:      [:id, :order_id, :inserted_at]
end

# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.RiderAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Delivery.Rider,
    context:              Qcommerce.Delivery,
    label:                "Riders",
    group:                "Delivery",
    icon:                 "truck-fast",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :user_id, :vehicle_type, :license_number, :status, :inserted_at],
    list_display_links:   [:id],
    search_fields:        [:license_number],
    ordering:             ["-inserted_at"],
    readonly_fields:      [:id, :current_location, :location_updated_at, :inserted_at],
    custom_actions: [
      %{id: "mark_active",   label: "Set Active",   icon: "hero-check-circle", confirm: false},
      %{id: "mark_inactive", label: "Set Inactive",  icon: "hero-x-circle",    confirm: false}
    ]
end

# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.BranchInventoryAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Inventory.BranchInventory,
    context:              Qcommerce.Inventory,
    label:                "Branch Inventory",
    group:                "Inventory",
    icon:                 "chart-bar",
    roles:                [:super_admin, :manager],
    list_fields:          [:id, :branch_id, :product_id, :selling_price, :quantity_on_hand, :is_available],
    list_display_links:   [:id],
    search_fields:        [],
    ordering:             [:branch_id, :product_id],
    readonly_fields:      [:id, :updated_at],
    custom_actions: [
      %{id: "export_csv", label: "Export CSV", icon: "hero-arrow-down-tray", confirm: false}
    ]
end

# ---------------------------------------------------------------------------
# Ledger
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.AccountAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Ledger.Account,
    context:              Qcommerce.Ledger,
    label:                "Chart of Accounts",
    group:                "Ledger",
    icon:                 "hero-book-open",
    list_fields:          [:id, :code, :name, :account_type, :normal_balance, :shard_count, :is_active],
    list_display_links:   [:id, :name],
    search_fields:        [:name, :code],
    ordering:             [:code],
    readonly_fields:      [:id, :inserted_at, :updated_at]
end

defmodule Qcommerce.Admin.JournalAdmin do
  use Qcommerce.Admin.Registry,
    schema:               Qcommerce.Ledger.Journal,
    context:              Qcommerce.Ledger,
    label:                "Journals",
    group:                "Ledger",
    icon:                 "hero-clipboard-document-list",
    list_fields:          [:id, :branch_id, :fiscal_year_id, :description, :posted_at],
    list_display_links:   [:id],
    search_fields:        [:description],
    ordering:             ["-posted_at"],
    actions:              [:show],
    readonly_fields:      [:id, :branch_id, :fiscal_year_id, :idempotency_key,
                           :outbox_event_id, :posted_at, :inserted_at],
    date_hierarchy:       :posted_at
end
