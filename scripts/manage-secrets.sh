#!/bin/bash
# SnapAuth Secrets Management Script
# Handles initialization, rotation, and backup of secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
    cat << EOF
SnapAuth Secrets Management

Usage: $0 <command>

Commands:
  init      Initialize secrets (run bootstrap, encrypt .env)
  rotate    Rotate admin API key (zero-downtime)
  backup    Create encrypted secrets backup
  help      Show this help message

Examples:
  $0 init                    # First-time setup
  $0 rotate                  # Rotate API key
  $0 backup                  # Backup secrets
EOF
}

cmd_init() {
    echo -e "${GREEN}Initializing SnapAuth secrets...${NC}"
    
    # Run bootstrap to generate secrets
    cd "$PLATFORM_DIR"
    docker run --rm -v "$PLATFORM_DIR:/workspace" snapauth-bootstrap:v2.0.0
    
    # Prompt for encryption key
    read -r -sp "Enter encryption key for secrets (will be needed for restore): " ENCRYPTION_KEY
    echo
    
    if [ -z "$ENCRYPTION_KEY" ]; then
        echo -e "${YELLOW}Warning: No encryption key provided, skipping encryption${NC}"
        return
    fi
    
    # Encrypt .env file
    openssl enc -aes-256-cbc -salt -pbkdf2 \
        -in .env \
        -out .env.enc \
        -pass pass:"$ENCRYPTION_KEY"
    
    chmod 600 .env.enc
    
    echo -e "${GREEN}✓ Secrets initialized and encrypted${NC}"
    echo -e "${YELLOW}⚠  Store the encryption key securely!${NC}"
}

cmd_rotate() {
    echo -e "${GREEN}Rotating Admin API Key${NC}"
    echo "================================"
    
    cd "$PLATFORM_DIR"
    
    # Check if .env exists
    if [ ! -f .env ]; then
        echo -e "${RED}Error: .env file not found. Run 'init' first.${NC}"
        exit 1
    fi
    
    # Generate new API key
    NEW_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    
    # Get current key(s)
    CURRENT_KEY=$(grep "^SNAPAUTH_ADMIN_API_KEY=" .env | cut -d= -f2)
    CURRENT_KEYS=$(grep "^SNAPAUTH_ADMIN_API_KEYS=" .env | cut -d= -f2 || echo "")
    
    # Append new key to SNAPAUTH_ADMIN_API_KEYS (for zero-downtime rotation)
    if [ -n "$CURRENT_KEYS" ]; then
        # Already have multiple keys, append
        NEW_KEYS="$CURRENT_KEYS,$NEW_KEY"
    else
        # First rotation, use current key + new key
        NEW_KEYS="$CURRENT_KEY,$NEW_KEY"
    fi
    
    # Update .env
    sed -i.bak "s|^SNAPAUTH_ADMIN_API_KEYS=.*|SNAPAUTH_ADMIN_API_KEYS=$NEW_KEYS|" .env
    
    # Add SNAPAUTH_ADMIN_API_KEYS if it doesn't exist
    if ! grep -q "^SNAPAUTH_ADMIN_API_KEYS=" .env; then
        echo "SNAPAUTH_ADMIN_API_KEYS=$NEW_KEYS" >> .env
    fi
    
    echo -e "${GREEN}✓ New API key generated and added${NC}"
    echo ""
    echo "New API key: $NEW_KEY"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Update your clients to use the new API key"
    echo "2. Verify all clients are using the new key"
    echo "3. Run this script again with 'cleanup' to remove old keys"
    echo ""
    
    # Restart SnapAuth to pick up new keys
    echo "Restarting SnapAuth service..."
    docker compose restart snapauth
    
    echo -e "${GREEN}✓ Service restarted with new keys active${NC}"
    
    # Prompt to remove old key
    echo ""
    read -r -p "Remove old API key now? (yes/no): " REMOVE_OLD
    if [ "$REMOVE_OLD" = "yes" ]; then
        # Keep only the new key
        sed -i "s|^SNAPAUTH_ADMIN_API_KEYS=.*|SNAPAUTH_ADMIN_API_KEYS=$NEW_KEY|" .env
        sed -i "s|^SNAPAUTH_ADMIN_API_KEY=.*|SNAPAUTH_ADMIN_API_KEY=$NEW_KEY|" .env
        
        docker compose restart snapauth
        
        echo -e "${GREEN}✓ Old keys removed${NC}"
    else
        echo -e "${YELLOW}⚠  Old keys still active. Remove manually when ready.${NC}"
    fi
}

cmd_backup() {
    echo -e "${GREEN}Backing up secrets...${NC}"
    
    cd "$PLATFORM_DIR"
    
    BACKUP_DIR="${BACKUP_DIR:-/opt/snapauth-backups}"
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
    
    # Prompt for encryption key
    read -r -sp "Enter encryption key: " ENCRYPTION_KEY
    echo
    
    if [ -z "$ENCRYPTION_KEY" ]; then
        echo -e "${RED}Error: Encryption key required${NC}"
        exit 1
    fi
    
    # Create encrypted tarball of secrets
    tar czf - .env kickstart/ | \
        openssl enc -aes-256-cbc -salt -pbkdf2 \
            -pass pass:"$ENCRYPTION_KEY" \
            -out "$BACKUP_DIR/secrets-$BACKUP_DATE.tar.gz.enc"
    
    chmod 600 "$BACKUP_DIR/secrets-$BACKUP_DATE.tar.gz.enc"
    
    echo -e "${GREEN}✓ Secrets backed up${NC}"
    echo "Location: $BACKUP_DIR/secrets-$BACKUP_DATE.tar.gz.enc"
}

# Main command dispatcher
case "${1:-help}" in
    init)
        cmd_init
        ;;
    rotate)
        cmd_rotate
        ;;
    backup)
        cmd_backup
        ;;
    help|*)
        show_help
        ;;
esac
