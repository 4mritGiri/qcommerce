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

  # ── Browser / LiveView ──
  scope "/", QcommerceWeb do
    pipe_through :browser

    # get "/", PageController, :home
    live "/", HomeLive, :index
    live "/search", HomeLive, :search

    # Authentication routes (handled by SessionController)
    post "/session/login", SessionController, :login
    post "/session/signup", SessionController, :signup
    post "/session/logout", SessionController, :logout
    get "/session/login_phone", SessionController, :login_phone
    get "/session/login_qr", SessionController, :login_qr
    get "/session/login_passkey", SessionController, :login_passkey
  end

  scope "/admin", QcommerceWeb.Admin do
    pipe_through :browser
    live "/settings", SettingsLive, :index
  end


  # ── Public API ──
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

  # ── Authenticated API ──
  scope "/api/v1", QcommerceWeb.Api.V1, as: :api_v1 do
    pipe_through :api_authenticated

    # Auth
    get "/auth/me", AuthController, :me
    delete "/auth/logout", AuthController, :logout

    # Cart validation
    post "/cart/validate", CartController, :validate
    post "/orders", OrderController, :create
    get "/orders", OrderController, :index
    get "/orders/:id", OrderController, :show
    delete "/orders/:id", OrderController, :cancel
  end

  # ── Dev tools ──
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
