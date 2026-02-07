# SnapAuth Security Guide

This document describes the security architecture, configuration, and best practices for SnapAuth deployment.

## Table of Contents

- [Security Architecture](#security-architecture)
- [API Key Authentication](#api-key-authentication)
- [IP Whitelisting](#ip-whitelisting)
- [TLS/HTTPS Configuration](#tlshttps-configuration)
- [Rate Limiting](#rate-limiting)
- [Audit Logging](#audit-logging)
- [Security Headers](#security-headers)
- [Secrets Management](#secrets-management)
- [Network Isolation](#network-isolation)

## Security Architecture

SnapAuth implements defense-in-depth with multiple security layers:

```
Internet → Nginx (TLS) → SnapAuth (Auth) → FusionAuth → PostgreSQL
           Port 443      Port 8080         Port 9011    Port 5432
           ↓              ↓                 ↓            ↓
         Public      Public Interface   Internal     Internal
                     + Auth Checks      Only         Only
```

**Security Layers:**
1. **TLS Termination** (Nginx): Encrypts all traffic
2. **Rate Limiting** (Nginx + SnapAuth): Prevents abuse
3. **API Key Authentication** (SnapAuth): Protects admin endpoints
4. **IP Whitelisting** (SnapAuth): Network-level access control
5. **Network Isolation** (Docker): FusionAuth/DB not exposed externally

## API Key Authentication

### Overview

Admin endpoints require the `X-SnapAuth-API-Key` header with a valid API key.

**Protected Endpoints:**
- `POST /v1/users` - User creation
- `DELETE /v1/admin/users/{id}` - Admin force delete

**Public Endpoints** (no API key required):
- `POST /v1/auth/login` - User login (rate limited)
- `POST /v1/auth/refresh` - Token refresh
- `GET /health` - Health checks

### Generating API Keys

API keys are automatically generated during bootstrap:

```bash
make up  # Runs bootstrap, generates SNAPAUTH_ADMIN_API_KEY
```

To generate a new key manually:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Using API Keys

Include the key in the `X-SnapAuth-API-Key` header:

```bash
curl -X POST https://snapauth.example.com/v1/users \
  -H "X-SnapAuth-API-Key: YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{"username":"user@example.com","password":"SecurePass123!"}'
```

### Zero-Downtime API Key Rotation

SnapAuth supports multiple active API keys simultaneously for zero-downtime rotation:

```bash
# Step 1: Generate new key and add to list
scripts/manage-secrets.sh rotate

# Step 2: Update all clients to use new key
# (old key still works)

# Step 3: Remove old key when all clients updated
# (script will prompt you)
```

**Environment variables:**
```bash
# Single key (legacy)
SNAPAUTH_ADMIN_API_KEY=key-value

# Multiple keys (recommended for rotation)
SNAPAUTH_ADMIN_API_KEYS=old-key,new-key,another-key
```

### Security Considerations

- ✅ **Constant-time comparison** prevents timing attacks
- ✅ **Keys are never logged** (only first 8 chars for audit)
- ✅ **256-bit entropy** (32 bytes urlsafe)
- ⚠️ **Store keys securely** (secrets manager, encrypted .env)
- ⚠️ **Rotate regularly** (quarterly recommended)

## IP Whitelisting

### Overview

Admin endpoints can be restricted to specific IP addresses or CIDR ranges.

### Configuration

Set `ADMIN_ALLOWED_IPS` in `.env`:

```bash
# Single IP
ADMIN_ALLOWED_IPS=203.0.113.50

# CIDR range
ADMIN_ALLOWED_IPS=192.168.1.0/24

# Multiple (comma-separated)
ADMIN_ALLOWED_IPS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

# IPv6 support
ADMIN_ALLOWED_IPS=2001:db8::/32,192.168.1.0/24
```

**Default:** RFC 1918 private networks (10.x, 172.16.x, 192.168.x)

### Behind Reverse Proxy

When SnapAuth is behind Nginx/ALB, set `TRUST_PROXY=true`:

```bash
TRUST_PROXY=true
```

This enables X-Forwarded-For header parsing to get the real client IP.

### Testing

```bash
# Should succeed from whitelisted IP
curl -X POST https://snapauth.example.com/v1/users \
  -H "X-SnapAuth-API-Key: $API_KEY" \
  -d '{"username":"test","password":"pass"}'

# Should fail (403) from non-whitelisted IP
```

## TLS/HTTPS Configuration

### Production Deployment with Let's Encrypt

For production, use Let's Encrypt for free, auto-renewing TLS certificates:

```bash
# Install certbot
sudo apt-get install certbot

# Generate certificate (HTTP-01 challenge)
sudo certbot certonly --standalone \
  -d snapauth.example.com \
  --agree-tos \
  --email admin@example.com

# Certificates will be in: /etc/letsencrypt/live/snapauth.example.com/

# Update docker-compose.yml to mount Let's Encrypt certs
# (instead of ./certs)
```

Update `docker-compose.yml`:

```yaml
nginx:
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
    - /etc/letsencrypt/live/snapauth.example.com:/etc/nginx/certs:ro
```

### Certificate Renewal

Let's Encrypt certificates expire after 90 days. Set up auto-renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to crontab for auto-renewal
sudo crontab -e
# Add line:
0 3 * * * certbot renew --quiet && docker compose restart nginx
```

### Development with Self-Signed Certificates

For development/testing only:

```bash
cd certs
./generate-self-signed.sh
```

**⚠️ WARNING:** Self-signed certificates are NOT secure for production.

### TLS Configuration Details

SnapAuth's Nginx configuration enforces:
- **Protocols:** TLS 1.2, TLS 1.3 only (no SSL, no TLS 1.0/1.1)
- **Ciphers:** Mozilla Modern configuration (strong ciphers only)
- **HSTS:** Strict-Transport-Security header (forces HTTPS)
- **HTTP → HTTPS redirect:** All HTTP traffic redirected to HTTPS

## Rate Limiting

### Overview

Rate limiting is enforced at two levels:
1. **Nginx** (network layer)
2. **SnapAuth** (application layer)

### Configuration

```bash
# Enable/disable rate limiting
RATE_LIMIT_ENABLED=true

# Limits per minute
RATE_LIMIT_PER_MINUTE=60          # Authenticated endpoints
RATE_LIMIT_PER_MINUTE_AUTH=10     # Login/refresh (strict)
RATE_LIMIT_PER_MINUTE_ADMIN=30    # Admin operations
```

### Rate Limit Tiers

| Endpoint Type | Limit | Reason |
|--------------|-------|--------|
| `/v1/auth/login` | 10/min | Prevent brute force |
| `/v1/auth/refresh` | 10/min | Prevent token farming |
| `/v1/admin/*` | 30/min | Moderate admin ops |
| Other authenticated | 60/min | Normal operations |

### Rate Limit Responses

When limit exceeded:
```json
HTTP/1.1 429 Too Many Requests
Retry-After: 60

{
  "error": "Rate limit exceeded",
  "detail": "Too many requests. Please try again later."
}
```

## Audit Logging

### Overview

All security events are logged as structured JSON to Docker logs.

### Log Format

```json
{
  "timestamp": "2026-02-07T10:30:00.000000Z",
  "event_type": "user.created",
  "client_ip": "192.168.1.100",
  "user_agent": "curl/7.68.0",
  "user_id": "abc123",
  "success": true,
  "details": {
    "username": "user@example.com",
    "roles": ["user"]
  },
  "method": "POST",
  "path": "/v1/users"
}
```

### Event Types

- `user.created` - User account created
- `user.deleted` - User account deleted
- `user.updated` - User profile updated
- `user.login` - Successful login
- `auth.failed` - Failed login attempt

### Querying Audit Logs

```bash
# View all audit logs
docker logs snapauth-snapauth-1 | grep '"event_type"'

# Failed login attempts
docker logs snapauth-snapauth-1 | grep '"auth.failed"'

# User creation events
docker logs snapauth-snapauth-1 | grep '"user.created"'

# Events from specific IP
docker logs snapauth-snapauth-1 | grep '192.168.1.100'

# Export to file for analysis
docker logs snapauth-snapauth-1 > audit.log
cat audit.log | jq 'select(.event_type == "auth.failed")'
```

### Sensitive Data Redaction

Audit logs NEVER contain:
- Passwords
- Full JWT tokens
- Full API keys (only first 8 chars)

## Security Headers

SnapAuth adds security headers to all responses:

```http
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

Test with:

```bash
curl -I https://snapauth.example.com/health
```

## Secrets Management

### Initialization

```bash
# Initialize secrets (first time)
scripts/manage-secrets.sh init
# Generates: SNAPAUTH_ADMIN_API_KEY, DB_PASSWORD, etc.
# Encrypts .env file
```

### Rotation

```bash
# Rotate admin API key (zero-downtime)
scripts/manage-secrets.sh rotate
```

### Backup

```bash
# Create encrypted secrets backup
scripts/manage-secrets.sh backup
```

### Best Practices

1. **Never commit secrets to git**
2. **Use encrypted backups** (`BACKUP_ENCRYPTION_KEY`)
3. **Rotate keys quarterly**
4. **Use secrets manager in production** (AWS Secrets Manager, HashiCorp Vault)
5. **Audit secret access** (who has keys, when were they used)

## Network Isolation

SnapAuth uses Docker networks for defense-in-depth:

```yaml
networks:
  snapauth-internal:     # External access to SnapAuth
    internal: false      # Can reach internet
  
  fusionauth-backend:    # Completely isolated backend
    internal: true       # No external access
```

**Network Access Matrix:**

| Service | External Access | Can Access |
|---------|----------------|------------|
| Nginx | Port 80/443 | SnapAuth |
| SnapAuth | Via Nginx | FusionAuth, DB |
| FusionAuth | ❌ None | DB |
| PostgreSQL | ❌ None | - |

## Compliance

### OWASP API Security Top 10

SnapAuth addresses:

- ✅ **API1: Broken Object-Level Authorization** - `require_self_or_admin` enforces ownership
- ✅ **API2: Broken Authentication** - API key + constant-time comparison
- ✅ **API4: Unrestricted Resource Consumption** - Rate limiting
- ✅ **API5: Broken Function-Level Authorization** - Admin endpoints protected
- ✅ **API8: Security Misconfiguration** - Security headers, no default creds

### Audit Trail for Compliance

Audit logs provide:
- **Who** (user_id, client_ip)
- **What** (event_type, details)
- **When** (ISO 8601 timestamp)
- **Result** (success boolean)

Suitable for: SOC 2, HIPAA, PCI-DSS audit requirements.

## Security Checklist

Before production deployment:

- [ ] Replace self-signed certs with Let's Encrypt
- [ ] Set strong `BACKUP_ENCRYPTION_KEY`
- [ ] Restrict `ADMIN_ALLOWED_IPS` to known networks
- [ ] Enable centralized logging
- [ ] Set up automated backups (`make backup` cron job)
- [ ] Test rate limiting (`test_rate_limit_login`)
- [ ] Verify audit logs are written
- [ ] Review and rotate all default secrets
- [ ] Document incident response procedures
- [ ] Set up monitoring/alerting for failed auth attempts
