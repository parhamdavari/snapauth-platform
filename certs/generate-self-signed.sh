#!/bin/bash
# Generate self-signed TLS certificate for development/testing
# For production, use Let's Encrypt or your organization's CA

set -e

CERT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAYS_VALID=365
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORG="SnapAuth"
CN="${CERT_CN:-localhost}"

echo "Generating self-signed certificate for development..."
echo "Common Name (CN): $CN"
echo "Valid for: $DAYS_VALID days"
echo ""

# Generate private key
openssl genrsa -out "$CERT_DIR/server.key" 2048

# Generate certificate signing request (CSR)
openssl req -new -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/CN=$CN"

# Generate self-signed certificate
openssl x509 -req -days $DAYS_VALID \
    -in "$CERT_DIR/server.csr" \
    -signkey "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.crt" \
    -extfile <(printf "subjectAltName=DNS:localhost,DNS:snapauth,IP:127.0.0.1")

# Set appropriate permissions
chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"

# Clean up CSR
rm -f "$CERT_DIR/server.csr"

echo ""
echo "✓ Certificate generated successfully!"
echo ""
echo "Files created:"
echo "  - $CERT_DIR/server.key (private key)"
echo "  - $CERT_DIR/server.crt (certificate)"
echo ""
echo "⚠️  WARNING: This is a self-signed certificate for DEVELOPMENT ONLY"
echo "   For production, use Let's Encrypt or your organization's CA"
echo ""
echo "To view certificate details:"
echo "  openssl x509 -in $CERT_DIR/server.crt -text -noout"
