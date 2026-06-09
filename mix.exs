defmodule Qcommerce.MixProject do
  use Mix.Project

  def project do
    [
      app: :qcommerce,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Qcommerce.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # -----------------------------------------------------------------------
      # Phoenix core — untouched from generated output
      # -----------------------------------------------------------------------
      {:phoenix, "~> 1.8.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # -----------------------------------------------------------------------
      # PostGIS — GEOGRAPHY column support (rider/branch/address locations)
      # -----------------------------------------------------------------------
      {:geo_postgis, "~> 3.5"},

      # -----------------------------------------------------------------------
      # Auth — JWT tokens + password hashing
      # -----------------------------------------------------------------------
      {:guardian, "~> 2.3"},
      {:bcrypt_elixir, "~> 3.0"},

      # -----------------------------------------------------------------------
      # Background jobs — Oban (PostgreSQL-backed, handles outbox processing,
      # balance checkpointing, partition provisioning, scheduled reports)
      # -----------------------------------------------------------------------
      {:oban, "~> 2.17"},

      # -----------------------------------------------------------------------
      # UUID — UUIDv5 deterministic idempotency keys
      # -----------------------------------------------------------------------
      {:uuid, "~> 1.1"},

      # -----------------------------------------------------------------------
      # Rate limiting — Hammer 7.x
      #
      # v7 changed the API completely from v6:
      #   - No global config :hammer backend needed in config.exs
      #   - Each rate limiter is its own module: `use Hammer, backend: :ets`
      #   - No poolboy dependency, no ETS pool config
      #   - Cleaner, per-context rate limiters (API limiter, auth limiter, etc.)
      # -----------------------------------------------------------------------
      {:hammer, "~> 7.0"},

      # -----------------------------------------------------------------------
      # CORS — for the React Native mobile client
      # -----------------------------------------------------------------------
      {:cors_plug, "~> 3.0"},

      # -----------------------------------------------------------------------
      # Dev / Test
      # -----------------------------------------------------------------------
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind qcommerce", "esbuild qcommerce"],
      "assets.deploy": [
        "tailwind qcommerce --minify",
        "esbuild qcommerce --minify",
        "phx.digest"
      ],
      # Docker Compose shortcuts
      "docker.dev": ["cmd docker compose up"],
      "docker.dev.build": ["cmd docker compose up --build"],
      "docker.dev.down": ["cmd docker compose down"],
      "docker.prod": ["cmd docker compose -f compose.prod.yaml up --build -d"],
      "docker.prod.down": ["cmd docker compose -f compose.prod.yaml down"],
      "docker.down.all": [
        "cmd docker compose -f compose.prod.yaml down && docker compose -f compose.yaml down"
      ],
      "docker.logs.dev": ["cmd docker compose -f compose.yaml logs -f"],
      "docker.logs.prod": ["cmd docker compose -f compose.prod.yaml logs -f"],
      "docker.restart.dev": ["cmd docker compose -f compose.yaml restart"],
      "docker.restart.prod": ["cmd docker compose -f compose.prod.yaml restart"]
    ]
  end
end
