#!/bin/sh
# entrypoint.dev.sh for local development
set -e

# Ensure dependencies are fetched
echo "Resolving dependencies..."
mix deps.get

# Wait for postgres to be ready, then run ecto.create and ecto.migrate
echo "Checking and running database setup/migrations..."
max_attempts=30
attempt=1

until (mix ecto.create && mix ecto.migrate) || [ $attempt -eq $max_attempts ]; do
  echo "Database setup failed (attempt $attempt/$max_attempts), retrying in 2 seconds..."
  attempt=$((attempt + 1))
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "Database setup failed after $max_attempts attempts. Exiting."
  exit 1
fi

echo "Database setup completed! Starting Phoenix development server..."
exec "$@"
