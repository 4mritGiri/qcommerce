# priv/repo/seeds.exs
# Entrypoint that runs all seed scripts under priv/repo/seeds/
# Inject server: false to prevent eaddrinuse when running alongside phx.server

# 1. Force server: false on Endpoint to ensure running seeds doesn't fail with eaddrinuse
Application.put_env(
  :qcommerce,
  QcommerceWeb.Endpoint,
  Keyword.put(Application.get_env(:qcommerce, QcommerceWeb.Endpoint) || [], :server, false)
)

# Start the database and all dependencies
{:ok, _} = Application.ensure_all_started(:qcommerce)

IO.puts("🌱 Starting database seed runner...")

# 2. Run Geography Seed (provinces, districts, local bodies)
IO.puts("\n🗺️  Seeding Geography data...")
Code.require_file("priv/repo/seeds/geography_seed.exs")

# 3. Run Main Seed (branches, categories, products, slides, settings, users)
IO.puts("\n🛒  Seeding main store catalog data...")
Code.require_file("priv/repo/seeds/main_seed.exs")

IO.puts("\n🎉 Database seeding completed successfully!")
