import Config

# =============================================================================
# Database — local PostgreSQL (your Docker container)
# NOTE: types: is set in config.exs — do NOT repeat it here
# =============================================================================
config :qcommerce, Qcommerce.Repo,
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASSWORD") || "123456",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  database: System.get_env("DATABASE_DB") || "qcommerce_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# =============================================================================
# Phoenix dev server
# =============================================================================
config :qcommerce, QcommerceWeb.Endpoint,
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4000],
  server: true,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "ObYLtl44alkzxbS+KNWiIMwpOBEaVGw63IJWnzrSMhFmyHI4mGiP262xoGd7YInd",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:qcommerce, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:qcommerce, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/qcommerce_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# =============================================================================
# Guardian — dev-only secret (non-sensitive)
# =============================================================================
config :qcommerce, Qcommerce.Auth.Guardian,
  secret_key: "dev_only_secret_not_for_production_xxxxxxxxxxxxxxxxxxxxxxxxxx"

# =============================================================================
# Oban — :inline mode in dev means jobs run synchronously in the same process.
# This makes development easier — no background worker needed to see results.
# Switch to :disabled to test the full async flow locally.
# =============================================================================
config :qcommerce, Oban, testing: :inline

config :swoosh, :api_client, false
config :logger, level: :debug
config :phoenix, :plug_init_mode, :runtime
