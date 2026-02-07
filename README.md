# SnapAuth Platform

**Production-ready authentication service with enterprise security** - Deploy a complete auth stack in minutes on any server, including air-gapped environments.

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](VERSION.yml)
[![Security](https://img.shields.io/badge/security-hardened-green.svg)](docs/SECURITY.md)

## Overview

SnapAuth Platform combines SnapAuth (auth API facade) + FusionAuth (identity provider) + PostgreSQL in a secure, production-ready deployment configuration.

**Key Features:**
- 🔐 **Production Security** - API key auth, IP whitelisting, rate limiting, TLS/HTTPS
- 🏢 **Enterprise Ready** - Audit logging, backup/restore, secrets rotation
- ✈️ **Air-Gapped Deployment** - Works on completely isolated servers
- 🔌 **Network Flexibility** - Isolated or microservices integration modes
- 🚀 **Zero Configuration** - Bootstrap generates all secrets automatically
- 📦 **Containerized** - Docker-based with resource limits

## Quick Start

```bash
# 1. Clone and setup
git clone https://github.com/.../snapauth-platform.git
cd snapauth-platform
cd certs && ./generate-self-signed.sh && cd ..

# 2. Deploy
make up

# 3. Verify
make health
```

## 🔒 Security Highlights (v2.0.0)

- ✅ **API Key Authentication** - Admin endpoints protected with 256-bit keys
- ✅ **Rate Limiting** - 10/min (login), 30/min (admin), 60/min (general)
- ✅ **TLS/HTTPS** - Nginx reverse proxy with TLS 1.2/1.3
- ✅ **Network Isolation** - FusionAuth/DB not exposed externally
- ✅ **Audit Logging** - Structured JSON logs for compliance

See [SECURITY.md](docs/SECURITY.md) for details.

## ⚠️ Breaking Changes (v2.0.0)

1. `POST /v1/users` now requires `X-SnapAuth-API-Key` header
2. `DELETE /v1/users/{id}` enforces self-only access
3. Login rate limited to 10 requests/minute

See [MIGRATION.md](docs/MIGRATION.md) for upgrade guide.

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [Security Guide](docs/SECURITY.md)  
- [Air-Gapped Deployment](docs/AIR-GAPPED-DEPLOYMENT.md)
- [Network Modes](docs/NETWORK-MODES.md)

## 🌐 Ports

**Exposed:**
- `80` - HTTP (→ HTTPS redirect)
- `443` - HTTPS

**Internal Only:**
- `8080` - SnapAuth
- `9011` - FusionAuth
- `5432` - PostgreSQL

## 📋 Common Commands

```bash
make up                 # Start services
make logs               # View logs
make health             # Health check
make backup             # Backup database
make stop               # Stop services
```

## 🔗 Related

- [SnapAuth Core](https://github.com/parhamdavari/SnapAuth)
- [FusionAuth](https://fusionauth.io/)
