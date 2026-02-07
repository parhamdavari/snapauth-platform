#!/bin/bash
# SnapAuth Restore Script
# Restores database, configuration, and secrets from backup

set -e

BACKUP_PATH="$1"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -z "$BACKUP_PATH" ]; then
  echo -e "${RED}Error:${NC} Backup path required"
  echo "Usage: $0 <backup-prefix>"
  echo "Example: $0 /opt/snapauth-backups/snapauth-20260207-120000"
  exit 1
fi

echo -e "${YELLOW}⚠  WARNING: This will overwrite current data${NC}"
echo "Backup path: $BACKUP_PATH"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Restore cancelled"
  exit 0
fi

echo -e "${GREEN}SnapAuth Restore${NC}"
echo "========================================"

# 1. Stop services
echo "Stopping services..."
docker compose down

echo -e "${GREEN}✓${NC} Services stopped"

# 2. Restore configuration
if [ -f "$BACKUP_PATH-config.tar.gz" ]; then
  echo "Restoring configuration..."
  tar xzf "$BACKUP_PATH-config.tar.gz"
  echo -e "${GREEN}✓${NC} Configuration restored"
else
  echo -e "${YELLOW}⚠${NC}  Configuration backup not found, skipping"
fi

# 3. Decrypt and restore .env if encrypted backup exists
if [ -f "$BACKUP_PATH-secrets.env.enc" ]; then
  if [ -n "$BACKUP_ENCRYPTION_KEY" ]; then
    echo "Decrypting secrets..."
    openssl enc -aes-256-cbc -d -pbkdf2 \
      -in "$BACKUP_PATH-secrets.env.enc" \
      -out .env \
      -pass pass:"$BACKUP_ENCRYPTION_KEY"
    echo -e "${GREEN}✓${NC} Secrets decrypted"
  else
    echo -e "${RED}Error:${NC} BACKUP_ENCRYPTION_KEY not set, cannot decrypt secrets"
    exit 1
  fi
fi

# 4. Start database only
echo "Starting database..."
docker compose up -d db
sleep 5

# Wait for database to be ready
echo "Waiting for database..."
until docker compose exec -T db pg_isready -U fusionauth >/dev/null 2>&1; do
  sleep 1
done
echo -e "${GREEN}✓${NC} Database ready"

# 5. Restore database
if [ -f "$BACKUP_PATH-db.sql.gz" ]; then
  echo "Restoring database..."
  gunzip < "$BACKUP_PATH-db.sql.gz" | \
    docker compose exec -T db psql -U fusionauth fusionauth
  echo -e "${GREEN}✓${NC} Database restored"
else
  echo -e "${RED}Error:${NC} Database backup not found: $BACKUP_PATH-db.sql.gz"
  exit 1
fi

# 6. Start all services
echo "Starting all services..."
docker compose up -d

echo "========================================"
echo -e "${GREEN}Restore complete!${NC}"
echo "Services are starting up..."
