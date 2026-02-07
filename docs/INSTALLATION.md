# Installation Guide

Quick start and detailed installation instructions for SnapAuth Platform.

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/.../snapauth-platform.git
cd snapauth-platform

# 2. Generate TLS certificates (development)
cd certs && ./generate-self-signed.sh && cd ..

# 3. Deploy
make up

# 4. Verify
make health
```

SnapAuth is now running at `https://localhost` (or `http://localhost:8080`)

## System Requirements

### Minimum (Small Deployment)
- **CPU:** 4 cores
- **Memory:** 4GB RAM
- **Disk:** 20GB
- **Users:** < 100

### Recommended (Medium Deployment)
- **CPU:** 8 cores
- **Memory:** 8GB RAM
- **Disk:** 50GB SSD
- **Users:** 100 - 10,000

### Large Deployment
- **CPU:** 16+ cores
- **Memory:** 16GB+ RAM
- **Disk:** 100GB+ SSD
- **Users:** 10,000+

### Software
- Docker Engine 20.10+
- Docker Compose 2.0+
- OpenSSL (for certificate generation)
- curl (for health checks)

## Installation Methods

### Method 1: Standard (Internet Access)

```bash
git clone https://github.com/.../snapauth-platform.git
cd snapauth-platform
make up
```

Images pulled from registries:
- `snapauth:v2.0.0`
- `snapauth-bootstrap:v2.0.0`
- `fusionauth/fusionauth-app:1.62.1`
- `postgres:16-alpine`
- `nginx:1.25-alpine`

### Method 2: Air-Gapped (No Internet)

See [AIR-GAPPED-DEPLOYMENT.md](AIR-GAPPED-DEPLOYMENT.md)

```bash
# Transfer release tarball to server
# Then:
tar xzf snapauth-release-v2.0.0.tar.gz
cd snapauth-release-v2.0.0/
./offline-install.sh
make up
```

### Method 3: From Source

```bash
# Build images locally
cd snapauth/
docker build -t snapauth:v2.0.0 .

cd ../scripts/
docker build -f Dockerfile.bootstrap -t snapauth-bootstrap:v2.0.0 .

# Then deploy
cd ../snapauth-platform/
make up
```

## Post-Installation

### 1. Access Credentials

Bootstrap generates credentials in `.env`:

```bash
# View generated credentials
cat .env | grep ADMIN
```

- **FusionAuth Admin:** Username in `FUSIONAUTH_ADMIN_USERNAME`, password in `FUSIONAUTH_ADMIN_PASSWORD`
- **SnapAuth Admin API Key:** In `SNAPAUTH_ADMIN_API_KEY`

### 2. Health Checks

```bash
make health
```

Expected output:
```json
{"status":"healthy","timestamp":"2026-02-07T..."}
{"status":"healthy","issuer":"http://fusionauth:9011",...}
```

### 3. Create First User

```bash
curl -X POST https://localhost/v1/users \
  -H "X-SnapAuth-API-Key: YOUR_ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user@example.com",
    "password": "SecurePassword123!"
  }'
```

### 4. Test Login

```bash
curl -X POST https://localhost/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user@example.com",
    "password": "SecurePassword123!"
  }'
```

## Configuration

### Environment Variables

See `.env.example` for all available options.

Key variables:
- `SNAPAUTH_ADMIN_API_KEY` - Admin operations
- `ADMIN_ALLOWED_IPS` - IP whitelist
- `RATE_LIMIT_ENABLED` - Rate limiting toggle
- `TRUST_PROXY` - X-Forwarded-For parsing

### Resource Limits

Adjust in `docker-compose.yml`:

```yaml
snapauth:
  deploy:
    resources:
      limits:
        cpus: '2.0'      # Increase for high load
        memory: 1G
```

### TLS Certificates

**Development:**
```bash
cd certs && ./generate-self-signed.sh
```

**Production:**
```bash
# Use Let's Encrypt
sudo certbot certonly --standalone -d snapauth.example.com
```

## Deployment Modes

### Isolated Mode (Default)
```bash
make up
```

Only port 443 exposed. Maximum security.

### Microservices Mode
```bash
docker network create shared-services
make up MODE=microservices
```

SnapAuth joins shared-services network for inter-service communication.

See [NETWORK-MODES.md](NETWORK-MODES.md) for details.

## Backup and Recovery

### Create Backup

```bash
make backup
```

Creates:
- Database dump (gzipped)
- Configuration tarball
- Encrypted secrets

### Restore from Backup

```bash
make restore BACKUP_PATH=/opt/snapauth-backups/snapauth-20260207-120000
```

## Upgrading

### Minor Version (e.g., 2.0.0 → 2.1.0)

```bash
# Backup first
make backup

# Pull new images
docker compose pull

# Rolling update
docker compose up -d

# Verify
make health
```

### Major Version (e.g., 2.x → 3.x)

See `MIGRATION.md` for breaking changes and migration steps.

## Monitoring

### Service Status

```bash
make ps
```

### Logs

```bash
# All services
make logs

# Specific service
make logs SERVICE=snapauth

# Follow logs
docker compose logs -f snapauth
```

### Metrics

```bash
# Container stats
docker stats

# Resource usage
docker compose ps --format json | jq '.[]'
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
make logs

# Verify Docker
docker info

# Check disk space
df -h
```

### Health Check Fails

```bash
# Check service status
make ps

# Test directly
curl http://localhost:8080/health

# Check network
docker network inspect snapauth-platform_snapauth-internal
```

### Can't Access FusionAuth Admin

FusionAuth is internal-only. Access via SnapAuth API or:

```bash
# Temporary admin access (development only)
docker compose exec fusionauth curl http://localhost:9011/admin
```

## Uninstall

```bash
# Stop and remove all data
make clean

# Remove images
docker rmi snapauth:v2.0.0 snapauth-bootstrap:v2.0.0

# Remove networks
docker network prune
```

## Support

- Documentation: `/docs`
- Issues: GitHub Issues
- Security: See SECURITY.md
