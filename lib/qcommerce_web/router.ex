# lib/qcommerce_web/router.ex
defmodule QcommerceWeb.Router do
  use QcommerceWeb, :router

  alias QcommerceWeb.Plugs.{AuthPlug, SetCurrentUser}

  # ---------------------------------------------------------------------------
  # Pipelines
  # ---------------------------------------------------------------------------

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QcommerceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Public JSON API — no auth required
  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
  end

  # Authenticated JSON API — requires valid JWT Bearer token
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug CORSPlug
    plug Qcommerce.Auth.Pipeline
    plug SetCurrentUser
  end

  # Branch manager only — authenticated + role check
  pipeline :branch_manager do
    plug AuthPlug, roles: [:branch_manager, :super_admin]
  end

  # Super admin only
  pipeline :super_admin do
    plug AuthPlug, roles: [:super_admin]
  end

  scope "/", QcommerceWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # ---------------------------------------------------------------------------
  # Public API routes — no authentication needed
  # ---------------------------------------------------------------------------

  scope "/api/v1", QcommerceWeb.Api.V1, as: :api_v1 do
    pipe_through :api

    # Auth
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login

    # Public catalog browsing
    get "/categories", ProductController, :categories
    get "/branches/:branch_id/products", ProductController, :index
    get "/branches/:branch_id/products/:id", ProductController, :show
  end

  # ---------------------------------------------------------------------------
  # Authenticated customer API routes
  # ---------------------------------------------------------------------------

  scope "/api/v1", QcommerceWeb.Api.V1, as: :api_v1 do
    pipe_through :api_authenticated

    # Auth
    get "/auth/me", AuthController, :me
    delete "/auth/logout", AuthController, :logout

    # Cart validation
    post "/cart/validate", CartController, :validate

    # Orders
    post "/orders", OrderController, :create
    get "/orders", OrderController, :index
    get "/orders/:id", OrderController, :show
    delete "/orders/:id", OrderController, :cancel
  end

  # ---------------------------------------------------------------------------
  # Branch manager routes — authenticated + branch_manager role
  # ---------------------------------------------------------------------------

  scope "/api/v1/branch", QcommerceWeb.Api.V1, as: :branch do
    pipe_through [:api_authenticated, :branch_manager]

    # Branch order management (to be added)
    # get  "/orders",           BranchOrderController, :index
    # put  "/orders/:id/confirm", BranchOrderController, :confirm
    # put  "/orders/:id/deliver", BranchOrderController, :deliver

    # Inventory management (to be added)
    # get  "/inventory",        InventoryController, :index
    # put  "/inventory/:id",    InventoryController, :update
  end

  # ---------------------------------------------------------------------------
  # Dev routes
  # ---------------------------------------------------------------------------

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:qcommerce, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QcommerceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
