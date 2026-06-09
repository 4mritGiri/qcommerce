#!/bin/sh
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()    { printf "${YELLOW}[INFO]  %s${NC}\n" "$1"; }
success() { printf "${GREEN}[OK]    %s${NC}\n" "$1"; }
error()   { printf "${RED}[ERROR] %s${NC}\n" "$1"; }

info "Resolving dependencies..."
if mix deps.get; then
  success "Dependencies resolved."
else
  error "Failed to resolve dependencies."
  exit 1
fi

# Auto-generate SECRET_KEY_BASE if not set
if [ -z "$SECRET_KEY_BASE" ]; then
  warn "SECRET_KEY_BASE not set, generating one for dev..."
  export SECRET_KEY_BASE=$(mix phx.gen.secret)
  success "SECRET_KEY_BASE generated: $SECRET_KEY_BASE"
  warn "Add this to your .env to make it permanent."
fi

info "Waiting for database and running setup..."
attempt=1
max_attempts=30

while [ $attempt -le $max_attempts ]; do
  if mix ecto.create && mix ecto.migrate; then
    success "Database setup completed!"
    break
  fi

  if [ $attempt -eq $max_attempts ]; then
    error "Database setup failed after $max_attempts attempts. Exiting."
    exit 1
  fi

  printf "${YELLOW}[WARN]  Database setup failed (attempt %s/%s), retrying in 2 seconds...${NC}\n" "$attempt" "$max_attempts"
  attempt=$((attempt + 1))
  sleep 2
done

success "Starting Phoenix development server..."
exec "$@"
