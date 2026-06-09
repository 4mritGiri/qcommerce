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
warn()    { printf "${YELLOW}[WARN]  %s${NC}\n" "$1"; }

info "Starting migration process..."
attempt=1
max_attempts=30

while [ $attempt -le $max_attempts ]; do
 if /app/bin/qcommerce eval "Qcommerce.Release.migrate"; then
    success "Migrations completed successfully!"
    break
  fi

  if [ $attempt -eq $max_attempts ]; then
    error "Migration failed after $max_attempts attempts. Exiting."
    exit 1
  fi

  warn "Migration failed (attempt $attempt/$max_attempts), retrying in 2 seconds..."
  attempt=$((attempt + 1))
  sleep 2
done

success "Starting Phoenix server..."
exec "$@"
