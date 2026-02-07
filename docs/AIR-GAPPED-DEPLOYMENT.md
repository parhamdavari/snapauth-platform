# Air-Gapped Deployment Guide

Deploy SnapAuth on servers with NO internet access (completely isolated/air-gapped environments).

## Prerequisites

- Docker Engine 20.10+ (pre-installed on air-gapped server)
- Docker Compose 2.0+ (pre-installed)
- SnapAuth release tarball (transferred via USB/courier)

## Step 1: Obtain Release Tarball

On an internet-connected machine:

```bash
# Download from GitHub Releases
wget https://github.com/.../snapauth-release-v2.0.0.tar.gz

# Verify checksum
sha256sum snapauth-release-v2.0.0.tar.gz
# Compare with VERSION.yml checksums
```

## Step 2: Transfer to Air-Gapped Server

Methods:
- **USB drive** - Copy tarball to USB, physically transfer
- **Secure courier** - For classified/sensitive environments
- **Secure file transfer** - If limited network access exists

```bash
# On USB/transfer machine
cp snapauth-release-v2.0.0.tar.gz /media/usb/

# On air-gapped server
cp /media/usb/snapauth-release-v2.0.0.tar.gz /opt/
```

## Step 3: Extract Release

```bash
cd /opt
tar xzf snapauth-release-v2.0.0.tar.gz
cd snapauth-release-v2.0.0/
```

**Release structure:**
```
snapauth-release-v2.0.0/
├── images/                          # Docker image tarballs
│   ├── snapauth-v2.0.0.tar
│   ├── bootstrap-v2.0.0.tar
│   ├── fusionauth-1.62.1.tar
│   ├── postgres-16-alpine.tar
│   └── nginx-1.25-alpine.tar
├── docker-compose.yml
├── nginx.conf
├── Makefile
├── scripts/
├── certs/
├── offline-install.sh              # Loads all images
├── VERSION.yml                      # Version manifest
└── docs/
```

## Step 4: Load Docker Images

```bash
# Load all images from tarballs (NO INTERNET REQUIRED)
./offline-install.sh
```

Output:
```
SnapAuth Offline Installation
=========================================
Found 5 image tarball(s)

Loading snapauth-v2.0.0.tar... ✓
Loading bootstrap-v2.0.0.tar... ✓
Loading fusionauth-1.62.1.tar... ✓
Loading postgres-16-alpine.tar... ✓
Loading nginx-1.25-alpine.tar... ✓

=========================================
Summary:
  Loaded: 5
  Failed: 0

✓ Offline installation complete
```

Verify images:
```bash
docker images | grep -E "snapauth|fusionauth|postgres|nginx"
```

## Step 5: Generate TLS Certificates

For air-gapped deployments, use self-signed certificates:

```bash
cd certs
./generate-self-signed.sh
```

**For production:** Use your organization's internal CA to issue certificates.

## Step 6: Deploy

```bash
# Generate secrets and start services
make up
```

This will:
1. Run bootstrap (generates secrets in `.env`)
2. Start all services (NO INTERNET ACCESS REQUIRED)

## Step 7: Verify Deployment

```bash
# Check service status
make ps

# Health check
make health

# View logs
make logs SERVICE=snapauth
```

Expected output:
```bash
$ make health
curl --fail http://localhost:8080/health
{"status":"healthy","timestamp":"2026-02-07T10:00:00Z"}
```

## Updating in Air-Gapped Environments

### Obtaining Updates

1. Download new release tarball on internet-connected machine
2. Transfer to air-gapped server (USB/courier)
3. Extract and load new images

### Applying Updates

```bash
# Backup current deployment
make backup

# Load new images
cd snapauth-release-v2.1.0/
./offline-install.sh

# Rolling update
docker compose up -d --no-deps snapauth

# Verify
make health
```

## Troubleshooting

### Issue: Images won't load

```bash
# Check Docker daemon
systemctl status docker

# Check disk space
df -h

# Manually load specific image
docker load < images/snapauth-v2.0.0.tar
```

### Issue: Services won't start

```bash
# Check logs
make logs

# Verify .env file exists
ls -la .env

# Re-run bootstrap
docker compose run --rm bootstrap
```

### Issue: Cannot connect to services

```bash
# Check network
docker network ls

# Check firewall
sudo iptables -L

# Test internal connectivity
docker compose exec snapauth curl http://fusionauth:9011/api/status
```

## Security Considerations

1. **Physical Security** - Protect USB drives during transfer
2. **Integrity Verification** - Always verify checksums
3. **Certificate Management** - Use internal CA for production
4. **Update Process** - Document and test update procedures
5. **Backup Strategy** - Regular encrypted backups

## Compliance

Air-gapped deployments satisfy:
- **NIST 800-53** - System isolation
- **PCI-DSS** - Segmentation requirements
- **ITAR/EAR** - Controlled technology environments
- **Classified environments** - Physical separation
