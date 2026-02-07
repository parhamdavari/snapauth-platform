#!/bin/bash
# SnapAuth Backup Script
# Creates encrypted backups of database, configuration, and secrets

set -e

BACKUP_DIR="${BACKUP_DIR:-/opt/snapauth-backups}"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_PREFIX="snapauth-$BACKUP_DATE"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}SnapAuth Backup${NC}"
echo "========================================"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# 1. Backup PostgreSQL database
echo "Backing up PostgreSQL database..."
docker compose exec -T db pg_dump -U fusionauth fusionauth | \
  gzip > "$BACKUP_DIR/$BACKUP_PREFIX-db.sql.gz"

echo -e "${GREEN}✓${NC} Database backed up: $BACKUP_PREFIX-db.sql.gz"

# 2. Backup configuration files
echo "Backing up configuration..."
tar czf "$BACKUP_DIR/$BACKUP_PREFIX-config.tar.gz" \
  .env \
  kickstart/ \
  docker-compose.yml \
  2>/dev/null || true

echo -e "${GREEN}✓${NC} Configuration backed up: $BACKUP_PREFIX-config.tar.gz"

# 3. Encrypt .env file separately for secure storage
if [ -n "$BACKUP_ENCRYPTION_KEY" ]; then
  echo "Encrypting secrets..."
  openssl enc -aes-256-cbc -salt -pbkdf2 \
    -in .env \
    -out "$BACKUP_DIR/$BACKUP_PREFIX-secrets.env.enc" \
    -pass pass:"$BACKUP_ENCRYPTION_KEY"
  echo -e "${GREEN}✓${NC} Secrets encrypted: $BACKUP_PREFIX-secrets.env.enc"
else
  echo -e "${YELLOW}⚠${NC}  BACKUP_ENCRYPTION_KEY not set - .env not encrypted separately"
fi

# 4. Create backup manifest
cat > "$BACKUP_DIR/$BACKUP_PREFIX-MANIFEST.txt" << EOF
SnapAuth Backup Manifest
========================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Backup ID: $BACKUP_PREFIX

Files:
  - $BACKUP_PREFIX-db.sql.gz ($(stat -f%z "$BACKUP_DIR/$BACKUP_PREFIX-db.sql.gz" 2>/dev/null || stat -c%s "$BACKUP_DIR/$BACKUP_PREFIX-db.sql.gz") bytes)
  - $BACKUP_PREFIX-config.tar.gz ($(stat -f%z "$BACKUP_DIR/$BACKUP_PREFIX-config.tar.gz" 2>/dev/null || stat -c%s "$BACKUP_DIR/$BACKUP_PREFIX-config.tar.gz") bytes)

Encryption: $([ -n "$BACKUP_ENCRYPTION_KEY" ] && echo "Enabled" || echo "Disabled")
EOF

echo -e "${GREEN}✓${NC} Manifest created: $BACKUP_PREFIX-MANIFEST.txt"

# 5. Cleanup old backups (keep last 30 days)
echo "Cleaning up old backups (keeping last 30 days)..."
find "$BACKUP_DIR" -name "snapauth-*" -type f -mtime +30 -delete 2>/dev/null || true

echo "========================================"
echo -e "${GREEN}Backup complete!${NC}"
echo "Location: $BACKUP_DIR"
echo "Prefix: $BACKUP_PREFIX"
