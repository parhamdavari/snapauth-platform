# Migration Guide: v1.x to v2.0.0

This guide helps you migrate from SnapAuth Platform v1.x to v2.0.0.

## Overview

v2.0.0 introduces **significant security hardening** and production features. This is a **major version** with breaking changes.

**Migration time estimate:** 30-60 minutes

## Breaking Changes

### 1. API Key Authentication Required

**Change:** `POST /v1/users` now requires `X-SnapAuth-API-Key` header.

**Before (v1.x):**
```bash
curl -X POST http://localhost:8080/v1/users \
  -H "Content-Type: application/json" \
  -d '{"username":"user@example.com","password":"SecurePass123!"}'
```

**After (v2.0.0):**
```bash
curl -X POST https://localhost/v1/users \
  -H "X-SnapAuth-API-Key: YOUR_ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"username":"user@example.com","password":"SecurePass123!"}'
```

**Migration steps:**
1. Retrieve admin API key from `.env` file: `grep SNAPAUTH_ADMIN_API_KEY .env`
2. Update all user creation scripts/apps to include `X-SnapAuth-API-Key` header
3. Test user creation with new header before removing old scripts

### 2. Self-Only Delete Enforcement

**Change:** `DELETE /v1/users/{id}` now enforces self-only access (users can only delete themselves).

**Before (v1.x):**
```bash
# Any authenticated user could delete any user
DELETE /v1/users/other-user-id
Authorization: Bearer <token>
# Would succeed
```

**After (v2.0.0):**
```bash
# Users can only delete themselves
DELETE /v1/users/other-user-id
Authorization: Bearer <token>
# Returns 403 Forbidden (unless user ID matches token)

# Admin force delete requires API key
DELETE /v1/admin/users/any-user-id
X-SnapAuth-API-Key: <admin-api-key>
# Succeeds
```

**Migration steps:**
1. Update admin scripts to use new endpoint: `DELETE /v1/admin/users/{id}` with API key
2. Update client applications to use self-delete only: `DELETE /v1/users/{current_user_id}`
3. Review and update any automation that relied on cross-user deletion

### 3. Rate Limiting

**Change:** Login endpoint limited to 10 requests/minute per IP.

**Before (v1.x):**
```bash
# Unlimited login attempts
```

**After (v2.0.0):**
```bash
# 10 attempts/minute per IP
# 11th request returns:
HTTP/1.1 429 Too Many Requests
Retry-After: 60
{"error":"Rate limit exceeded"}
```

**Migration steps:**
1. Update login retry logic to handle 429 responses
2. Implement exponential backoff in client applications
3. If legitimate high-frequency login is needed, configure IP whitelist

### 4. TLS/HTTPS Required in Production

**Change:** Production deployments now use HTTPS (port 443) instead of HTTP (port 8080).

**Before (v1.x):**
```bash
# Direct access to SnapAuth
http://localhost:8080/v1/auth/login
```

**After (v2.0.0):**
```bash
# Access via Nginx reverse proxy
https://localhost/v1/auth/login
# HTTP port 80 redirects to HTTPS
```

**Migration steps:**
1. Generate TLS certificates: `cd certs && ./generate-self-signed.sh`
2. Update all API base URLs from `http://host:8080` to `https://host`
3. For production, use Let's Encrypt (see [SECURITY.md](SECURITY.md))

### 5. Network Isolation Changes

**Change:** FusionAuth (port 9011) and PostgreSQL (port 5432) are no longer exposed externally.

**Before (v1.x):**
```yaml
# FusionAuth accessible externally
fusionauth:
  ports:
    - "9011:9011"
```

**After (v2.0.0):**
```yaml
# FusionAuth internal only
fusionauth:
  networks:
    - fusionauth-backend  # internal: true
  # No ports exposed
```

**Migration steps:**
1. Remove any external connections to FusionAuth port 9011
2. Use SnapAuth API endpoints instead: `https://snapauth/v1/*`
3. For admin access, use FusionAuth admin panel via Docker exec (dev only)

## New Environment Variables

Add these to your `.env` file:

```bash
# Security (required)
SNAPAUTH_ADMIN_API_KEY=<generated-by-bootstrap>

# IP Whitelist (optional, defaults to RFC 1918 private networks)
ADMIN_ALLOWED_IPS=192.168.1.0/24,10.0.0.0/8

# Proxy Configuration (required if behind reverse proxy/ALB)
TRUST_PROXY=true

# Rate Limiting (optional, enabled by default)
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_PER_MINUTE_ADMIN=30
RATE_LIMIT_PER_MINUTE_AUTH=10
```

## Migration Steps

### Step 1: Backup Current Deployment

```bash
# Backup database
docker compose exec db pg_dump -U fusionauth fusionauth | gzip > backup-v1.sql.gz

# Backup configuration
tar czf backup-v1-config.tar.gz .env kickstart/ docker-compose.yml
```

### Step 2: Stop Services

```bash
make stop
# Or: docker compose down
```

### Step 3: Update Repository

```bash
# Pull latest changes
git fetch origin
git checkout v2.0.0

# Or: Extract v2.0.0 release tarball
tar xzf snapauth-release-v2.0.0.tar.gz
```

### Step 4: Migrate Environment File

```bash
# Backup existing .env
cp .env .env.v1.backup

# Bootstrap will generate new secrets
# Your existing database credentials will be preserved
make up
# This runs bootstrap, which:
# - Generates SNAPAUTH_ADMIN_API_KEY (new)
# - Preserves existing DB_PASSWORD
# - Adds security defaults (ADMIN_ALLOWED_IPS, etc.)
```

### Step 5: Generate TLS Certificates

**Development:**
```bash
cd certs
./generate-self-signed.sh
cd ..
```

**Production:**
```bash
# Use Let's Encrypt
sudo certbot certonly --standalone -d snapauth.example.com
# Then update docker-compose.yml to mount /etc/letsencrypt/
```

### Step 6: Update Client Applications

Update all client applications to:

1. **Use HTTPS base URL:**
   ```diff
   - BASE_URL = "http://auth-server:8080"
   + BASE_URL = "https://auth-server"
   ```

2. **Add API key for user creation:**
   ```diff
   - headers = {"Content-Type": "application/json"}
   + headers = {
   +     "Content-Type": "application/json",
   +     "X-SnapAuth-API-Key": os.getenv("SNAPAUTH_ADMIN_API_KEY")
   + }
   ```

3. **Handle rate limits:**
   ```python
   import time

   def login_with_retry(username, password, max_retries=3):
       for attempt in range(max_retries):
           response = requests.post(f"{BASE_URL}/v1/auth/login", json={
               "username": username,
               "password": password
           })

           if response.status_code == 429:
               retry_after = int(response.headers.get("Retry-After", 60))
               time.sleep(retry_after)
               continue

           return response
   ```

4. **Update delete operations:**
   ```diff
   - # Old: Delete any user
   - DELETE /v1/users/{user_id}
   + # New: Self-delete only
   + DELETE /v1/users/{current_user_id}
   +
   + # Or use admin endpoint with API key
   + DELETE /v1/admin/users/{user_id}
   + X-SnapAuth-API-Key: <admin-key>
   ```

### Step 7: Start Services

```bash
make up
```

### Step 8: Verify Migration

```bash
# 1. Check services are healthy
make health

# Expected output:
# {"status":"healthy"}
# {"status":"healthy","issuer":"http://fusionauth:9011"}

# 2. Retrieve admin API key
cat .env | grep SNAPAUTH_ADMIN_API_KEY

# 3. Test user creation (should require API key)
curl -X POST https://localhost/v1/users \
  -H "X-SnapAuth-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"username":"test@example.com","password":"Test123!@#"}' \
  --insecure  # For self-signed certs in dev

# 4. Test login (should work)
curl -X POST https://localhost/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test@example.com","password":"Test123!@#"}' \
  --insecure

# 5. Test rate limiting (should get 429 after 10 attempts)
for i in {1..15}; do
  curl -X POST https://localhost/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test","password":"wrong"}' \
    --insecure
done
# Last requests should return 429
```

### Step 9: Update Firewall Rules

```bash
# Close old ports (if previously exposed)
sudo ufw delete allow 8080/tcp
sudo ufw delete allow 9011/tcp
sudo ufw delete allow 5432/tcp

# Allow new ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Step 10: Update Monitoring/Alerts

Update monitoring to check:
- `https://snapauth/health` instead of `http://snapauth:8080/health`
- Audit logs for security events: `docker logs snapauth-snapauth-1 | grep '"event_type"'`
- Rate limit violations: `grep '429' nginx logs`

## Rollback Procedure

If migration fails, rollback to v1.x:

```bash
# 1. Stop v2.0.0
make stop

# 2. Restore v1.x configuration
cp .env.v1.backup .env
# Extract v1.x files from backup

# 3. Restore database
gunzip < backup-v1.sql.gz | docker compose exec -T db psql -U fusionauth fusionauth

# 4. Start v1.x
make up
```

## Post-Migration Checklist

- [ ] All services healthy (`make health`)
- [ ] Admin API key stored securely
- [ ] User creation works with API key
- [ ] Login works and respects rate limits
- [ ] HTTPS/TLS configured correctly
- [ ] Client applications updated and tested
- [ ] Firewall rules updated
- [ ] Monitoring updated
- [ ] Backup/restore tested (`make backup && make restore`)
- [ ] Documentation updated (API docs, runbooks)

## Microservices Mode Migration

If using microservices integration:

**Before (v1.x):**
```bash
# All services on shared-services by default
```

**After (v2.0.0):**
```bash
# Isolated by default, opt-in to microservices mode
docker network create shared-services
make up MODE=microservices
```

Update any services that communicate with SnapAuth to:
1. Use HTTPS instead of HTTP
2. Include API key for admin operations
3. Handle rate limits appropriately

## Air-Gapped Deployment Migration

For air-gapped environments, see [AIR-GAPPED-DEPLOYMENT.md](AIR-GAPPED-DEPLOYMENT.md).

Key changes:
- Images now bundled in release tarballs
- Offline installation script: `./offline-install.sh`
- No external image pulls required

## Common Issues

### Issue: "Invalid API key" when creating users

**Cause:** Missing or incorrect API key header.

**Fix:**
```bash
# Get API key from .env
API_KEY=$(grep SNAPAUTH_ADMIN_API_KEY .env | cut -d= -f2)

# Include in requests
curl -H "X-SnapAuth-API-Key: $API_KEY" ...
```

### Issue: "429 Too Many Requests" on login

**Cause:** Rate limiting active (10/min).

**Fix:**
- Implement retry logic with exponential backoff
- Or disable rate limiting: `RATE_LIMIT_ENABLED=false` in `.env` (not recommended for production)

### Issue: "Forbidden" when deleting users

**Cause:** Self-only delete enforcement.

**Fix:**
- Use `DELETE /v1/users/{current_user_id}` for self-delete
- Use `DELETE /v1/admin/users/{any_user_id}` with API key for admin delete

### Issue: Cannot connect to FusionAuth on port 9011

**Cause:** FusionAuth is now internal-only.

**Fix:**
- Use SnapAuth API endpoints instead
- For admin access: `docker compose exec fusionauth curl http://localhost:9011/...`

### Issue: TLS certificate errors

**Cause:** Self-signed certificates in development.

**Fix:**
- For testing: Use `--insecure` flag with curl
- For production: Use Let's Encrypt certificates (see [SECURITY.md](SECURITY.md))

## Support

For issues during migration:
- Check logs: `make logs`
- Review health status: `make health`
- See [INSTALLATION.md](INSTALLATION.md) for deployment troubleshooting
- See [SECURITY.md](SECURITY.md) for security configuration

## Version Compatibility

| Version | Compatible | Notes |
|---------|-----------|-------|
| v1.0.x → v2.0.0 | Yes | Follow this guide |
| v0.x → v2.0.0 | No | Migrate to v1.0 first, then v2.0 |
| v2.0.0 → v2.1.x | Yes | Minor version, backward compatible |
