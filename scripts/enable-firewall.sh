#!/bin/bash
set -euo pipefail

# ========================================
# Enable UFW Firewall for SnapAuth Platform
# ========================================
# This script configures the firewall to block internal service ports
# while allowing only necessary external access (SSH, HTTP, HTTPS)

echo "=========================================="
echo "SnapAuth Platform Firewall Configuration"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root"
  exit 1
fi

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
  echo "Installing UFW..."
  apt-get update
  apt-get install -y ufw
fi

echo "Current UFW status:"
ufw status verbose
echo ""

echo "Configuring firewall rules..."

# Reset UFW to clean state
echo "y" | ufw reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (critical - don't lock yourself out!)
ufw allow 22/tcp comment 'SSH access'

# Allow HTTP and HTTPS for web traffic
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Explicitly deny internal service ports (for documentation)
ufw deny 9011/tcp comment 'Block FusionAuth (internal only)'
ufw deny 5432/tcp comment 'Block PostgreSQL (internal only)'
ufw deny 8080/tcp comment 'Block SnapAuth API (internal only)'

# Enable UFW
echo "Enabling firewall..."
echo "y" | ufw enable

echo ""
echo "=========================================="
echo "Firewall Configuration Complete"
echo "=========================================="
echo ""
echo "Current rules:"
ufw status verbose
echo ""
echo "✓ Firewall enabled successfully"
echo "✓ SSH (22), HTTP (80), HTTPS (443) allowed"
echo "✓ Internal ports (8080, 9011, 5432) blocked"
echo ""
echo "Verification:"
echo "  - Test external access to nginx: curl https://auth.machmilling.com/health"
echo "  - Verify ports blocked from external: timeout 3 bash -c 'exec 3<>/dev/tcp/185.7.212.250/9011' (should fail)"
