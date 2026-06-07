#!/bin/sh
# entrypoint.sh for Phoenix release deployment with Ecto migrations
set -e

echo "Running migrations..."
max_attempts=30
attempt=1

# Run the compiled release migration task
until /app/bin/migrate || [ $attempt -eq $max_attempts ]; do
  echo "Database migration failed (attempt $attempt/$max_attempts), retrying in 2 seconds..."
  attempt=$((attempt + 1))
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "Migration failed after $max_attempts attempts. Exiting."
  exit 1
fi

echo "Migrations completed successfully! Starting Phoenix server..."

# Execute the CMD passed to Docker (by default /app/bin/server)
exec "$@"
