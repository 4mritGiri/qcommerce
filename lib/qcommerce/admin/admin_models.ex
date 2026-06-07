# lib/qcommerce/admin/admin_models.ex
# Django-style admin registrations — one module per model.

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.ProductAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Catalog.Product,
    context:         Qcommerce.Catalog,
    label:           "Products",
    group:           "Catalog",
    icon:            "product",
    roles:           [:super_admin, :manager],
    list_fields:     [:id, :name, :sku, :base_price, :unit, :is_active, :inserted_at],
    search_fields:   [:name, :sku],
    readonly_fields: [:id, :inserted_at, :updated_at]
end

defmodule Qcommerce.Admin.CategoryAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Catalog.Category,
    context:         Qcommerce.Catalog,
    label:           "Categories",
    group:           "Catalog",
    icon:            "tags",
    roles:           [:super_admin, :manager],
    list_fields:     [:id, :name, :slug, :sort_order, :is_active],
    search_fields:   [:name, :slug],
    readonly_fields: [:id, :inserted_at]
end

defmodule Qcommerce.Admin.SlideAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Catalog.Slide,
    context:         Qcommerce.Catalog,
    label:           "Hero Slides",
    group:           "Catalog",
    icon:            "slideshow",
    roles:           [:super_admin],
    list_fields:     [:id, :tag, :heading, :position, :is_active],
    search_fields:   [:tag, :heading],
    readonly_fields: [:id, :inserted_at]
end

defmodule Qcommerce.Admin.FlashSaleAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Catalog.FlashSale,
    context:         Qcommerce.Catalog,
    label:           "Flash Sales",
    group:           "Catalog",
    icon:            "hero-bolt",
    roles:           [:super_admin, :manager],
    list_fields:     [:id, :label, :discount_pct, :ends_at, :is_active],
    search_fields:   [:label],
    readonly_fields: [:id, :inserted_at]
end

# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.UserAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Accounts.User,
    context:         Qcommerce.Accounts,
    label:           "Users",
    group:           "Accounts",
    icon:            "hero-user",
    roles:           [:super_admin],
    list_fields:     [:id, :full_name, :email, :phone, :role, :is_active, :inserted_at],
    search_fields:   [:full_name, :email, :phone],
    # password_hash must never appear in the edit form
    readonly_fields: [:id, :password_hash, :inserted_at, :updated_at]
end

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.BranchAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Platform.Branch,
    context:         Qcommerce.Platform,
    label:           "Branches",
    group:           "Platform",
    icon:            "hero-building-storefront",
    roles:           [:super_admin, :manager],
    list_fields:     [:id, :code, :name, :city, :catchment_radius_m, :is_active],
    search_fields:   [:name, :code, :city],
    # location is a Geo.Point — not editable via text input
    readonly_fields: [:id, :location, :inserted_at, :updated_at]
end

# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.OrderAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Orders.Order,
    context:         Qcommerce.Orders,
    label:           "Orders",
    group:           "Orders",
    icon:            "hero-shopping-cart",
    roles:           [:super_admin, :manager, :staff],
    list_fields:     [:id, :status, :total_amount, :placed_at, :delivered_at],
    search_fields:   [],
    # Orders are read-only in admin — mutations go through the Orders pipeline
    actions:         [:show],
    readonly_fields: [:id, :user_id, :branch_id, :placed_at, :confirmed_at,
                      :picked_at, :dispatched_at, :delivered_at,
                      :cancelled_at, :inserted_at, :updated_at
                    ]
end

defmodule Qcommerce.Admin.OrderItemAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Orders.OrderItem,
    context:         Qcommerce.Orders,
    label:           "Order Items",
    group:           "Orders",
    icon:            "watson-orders",
    roles:           [:super_admin, :manager, :staff],
    list_fields:     [:id, :order_id, :quantity, :unit_price, :line_total, :status],
    search_fields:   [],
    actions:         [:show],
    readonly_fields: [:id, :order_id, :inserted_at]
end

# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.RiderAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Delivery.Rider,
    context:         Qcommerce.Delivery,
    label:           "Riders",
    group:           "Delivery",
    icon:            "truck-fast",
    roles:           [:super_admin, :manager],
    list_fields:     [:id, :user_id, :vehicle_type, :license_number, :status, :inserted_at],
    search_fields:   [:license_number],
    # current_location is a Geo.Point
    readonly_fields: [:id, :current_location, :location_updated_at, :inserted_at]
end

# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.BranchInventoryAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Inventory.BranchInventory,
    context:         Qcommerce.Inventory,
    label:           "Branch Inventory",
    group:           "Inventory",
    icon:            "chart-bar",
    roles:           [:super_admin, :manager],
    list_fields:     [:id, :branch_id, :product_id, :selling_price, :quantity_on_hand, :is_available],
    search_fields:   [],
    readonly_fields: [:id, :updated_at]
end

# ---------------------------------------------------------------------------
# Ledger
# ---------------------------------------------------------------------------

defmodule Qcommerce.Admin.AccountAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Ledger.Account,
    context:         Qcommerce.Ledger,
    label:           "Chart of Accounts",
    group:           "Ledger",
    icon:            "hero-book-open",
    list_fields:     [:id, :code, :name, :account_type, :normal_balance, :shard_count, :is_active],
    search_fields:   [:name, :code],
    readonly_fields: [:id, :inserted_at, :updated_at]
end

defmodule Qcommerce.Admin.JournalAdmin do
  use Qcommerce.Admin.Registry,
    schema:          Qcommerce.Ledger.Journal,
    context:         Qcommerce.Ledger,
    label:           "Journals",
    group:           "Ledger",
    icon:            "hero-clipboard-document-list",
    list_fields:     [:id, :branch_id, :fiscal_year_id, :description, :posted_at],
    search_fields:   [:description],
    actions:         [:show],
    readonly_fields: [:id, :branch_id, :fiscal_year_id, :idempotency_key,
                      :outbox_event_id, :posted_at, :inserted_at]
end
