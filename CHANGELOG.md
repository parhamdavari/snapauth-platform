# Changelog

All notable changes to SnapAuth Platform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-02-07

### 🔒 Security Enhancements (Breaking Changes)

#### Added
- **API Key Authentication**: Admin endpoints now require `X-SnapAuth-API-Key` header with 256-bit keys
  - Constant-time comparison prevents timing attacks
  - Zero-downtime rotation via comma-separated `SNAPAUTH_ADMIN_API_KEYS`
  - Keys auto-generated during bootstrap
  - Only first 8 characters logged for audit purposes
- **IP Whitelisting**: Admin endpoints restricted by IP address/CIDR ranges
  - Support for both IPv4 and IPv6
  - CIDR notation: `192.168.1.0/24`, `10.0.0.0/8`
  - X-Forwarded-For header parsing when `TRUST_PROXY=true`
  - Defaults to RFC 1918 private networks
- **Rate Limiting**: Prevents brute force and abuse
  - Login/refresh: 10 requests/minute per IP
  - Admin endpoints: 30 requests/minute
  - General endpoints: 60 requests/minute
  - Configurable via environment variables
  - Returns 429 with `Retry-After` header
- **TLS/HTTPS**: Nginx reverse proxy with strong encryption
  - TLS 1.2 and 1.3 only (no SSL, no TLS 1.0/1.1)
  - Mozilla Modern cipher suite
  - HSTS header (force HTTPS)
  - HTTP → HTTPS automatic redirect
  - Self-signed cert generation for development
  - Let's Encrypt integration documented
- **Security Headers**: Added to all responses
  - `X-Frame-Options: DENY`
  - `X-Content-Type-Options: nosniff`
  - `X-XSS-Protection: 1; mode=block`
  - `Content-Security-Policy: default-src 'none'`
  - `Strict-Transport-Security: max-age=31536000`
- **Audit Logging**: Structured JSON logs for compliance
  - All security events logged (user creation, deletion, auth failures)
  - ISO 8601 timestamps
  - Client IP, user agent, user ID captured
  - Sensitive data redacted (passwords, full tokens never logged)
  - Queryable via Docker logs
- **Authorization Enforcement**: Fixed broken access controls
  - `DELETE /v1/users/{id}` now self-only (users can only delete themselves)
  - New endpoint: `DELETE /v1/admin/users/{id}` for admin force delete
  - `POST /v1/users` requires admin API key
  - Self-or-admin access pattern for updates

#### Changed
- **Breaking**: `POST /v1/users` now requires `X-SnapAuth-API-Key` header
- **Breaking**: `DELETE /v1/users/{id}` enforces self-only access (403 if not owner)
- **Breaking**: Login endpoint rate limited to 10/minute per IP
- **Breaking**: Production deployments use HTTPS (port 443) instead of HTTP (port 8080)
- **Breaking**: FusionAuth (port 9011) and PostgreSQL (port 5432) no longer exposed externally

#### Security Fixes
- Fixed unauthenticated user creation vulnerability
- Fixed timing attack vulnerability in API key comparison
- Removed JWT token content from logs (was logging first 20 chars)
- Fixed cross-user deletion vulnerability

### 🏗️ Architecture Improvements

#### Added
- **Network Isolation**: Defense-in-depth network architecture
  - `fusionauth-backend` network with `internal: true` (completely isolated)
  - `snapauth-internal` network for external access via Nginx
  - FusionAuth and PostgreSQL not accessible from outside
  - Only ports 80/443 exposed externally
- **Nginx Reverse Proxy**: Production-grade HTTP server
  - TLS termination
  - Load balancing ready
  - Security headers injection
  - Rate limiting at network layer
  - Access logging
- **Resource Limits**: Prevent resource exhaustion
  - SnapAuth: 1 CPU, 512MB memory
  - FusionAuth: 2 CPUs, 1GB memory, 512MB heap
  - PostgreSQL: 2 CPUs, 2GB memory, 256MB shared buffers
  - Reservations set for guaranteed baseline

#### Changed
- Default deployment mode now **isolated** (FusionAuth/DB internal-only)
- Microservices integration now **opt-in** via `MODE=microservices`
- Docker Compose networks redesigned for security-first approach

### 🚀 Operational Features

#### Added
- **Backup and Restore**: Automated disaster recovery
  - `make backup` - Creates encrypted database dumps and config backups
  - `make restore` - Complete restoration from backup
  - Encrypted secrets backup with AES-256-CBC
  - 30-day automatic backup retention
  - Timestamp-based backup naming
- **Secrets Management**: Secure credential handling
  - `scripts/manage-secrets.sh init` - Initialize encrypted secrets
  - `scripts/manage-secrets.sh rotate` - Zero-downtime API key rotation
  - `scripts/manage-secrets.sh backup` - Encrypted secrets backup
  - `.env` file encryption support
- **Air-Gapped Deployment**: Offline installation support
  - Pre-built release tarballs with bundled Docker images
  - `offline-install.sh` - Load images without internet access
  - `VERSION.yml` - Version manifest with checksums
  - Works on completely isolated servers
- **Deployment Modes**: Flexible network configuration
  - `make up` - Isolated mode (default, maximum security)
  - `make up MODE=microservices` - Shared-services integration
  - `docker-compose.microservices.yml` - Optional override file
- **Health Checks**: Comprehensive monitoring
  - `make health` - Check all services
  - `/health` endpoint for liveness probes
  - FusionAuth status verification
- **TLS Certificate Management**: Easy HTTPS setup
  - `certs/generate-self-signed.sh` - Development certificates
  - Let's Encrypt integration documented
  - Auto-renewal procedures documented

#### Changed
- Makefile reorganized with clear targets (up, down, logs, backup, restore, health)
- Bootstrap now generates admin API key automatically
- PostgreSQL configuration optimized for production workloads

### 📚 Documentation

#### Added
- `docs/SECURITY.md` - Comprehensive security guide (429 lines)
  - API key authentication and rotation
  - IP whitelisting configuration
  - TLS/HTTPS setup (self-signed and Let's Encrypt)
  - Rate limiting configuration
  - Audit logging guide
  - Security headers reference
  - Secrets management best practices
  - Network isolation architecture
  - OWASP API Security Top 10 compliance
  - Production security checklist
- `docs/AIR-GAPPED-DEPLOYMENT.md` - Offline installation guide (220 lines)
  - Step-by-step air-gapped deployment
  - Image tarball transfer procedures
  - Offline updates and patching
  - Troubleshooting isolated environments
  - Compliance considerations (NIST, PCI-DSS, ITAR)
- `docs/NETWORK-MODES.md` - Network architecture guide (199 lines)
  - Isolated mode (default)
  - Microservices integration mode
  - Security comparison
  - Network verification
  - Mode switching procedures
- `docs/INSTALLATION.md` - Complete installation guide (327 lines)
  - Quick start
  - System requirements
  - Installation methods (standard, air-gapped, from source)
  - Post-installation configuration
  - Resource limits tuning
  - Backup and recovery
  - Upgrading procedures
  - Monitoring and troubleshooting
- `docs/MIGRATION.md` - v1.x to v2.0.0 upgrade guide
  - Breaking changes explained
  - Step-by-step migration procedure
  - Client application updates
  - Rollback instructions
  - Common issues and fixes
- `CHANGELOG.md` - This file
- `.env.example` - Comprehensive environment variable template (140+ lines)
  - All configuration options documented
  - Security settings explained
  - Production-ready defaults
  - Examples for common scenarios

#### Changed
- `README.md` - Updated with v2.0.0 features
  - Security highlights section
  - Breaking changes warning
  - Links to all documentation
  - Updated quick start
  - Port assignments clarified
- Repository documentation structure improved

### 🛠️ Developer Experience

#### Added
- `docker-compose.microservices.yml` - Optional microservices integration
- `docker-compose.observability.yml` - Optional monitoring stack (Prometheus, Grafana)
- `docker-compose.dev.yml` - Optional source builds for development
- `.gitignore` - Added backups/, releases/, .env.enc, certificates

#### Changed
- Bootstrap script enhanced with better error messages
- Makefile supports multiple deployment modes
- Clear separation between production and development workflows

### 🐛 Bug Fixes

#### Security
- Fixed: POST /v1/users had no authentication (anyone could create users)
- Fixed: DELETE /v1/users allowed cross-user deletion (broken authorization)
- Fixed: API key comparison vulnerable to timing attacks
- Fixed: JWT tokens logged in plaintext
- Fixed: No protection against brute force attacks

#### Operational
- Fixed: Services could consume unlimited resources
- Fixed: No disaster recovery mechanism
- Fixed: Secrets stored in plaintext

### 📦 Dependencies

#### Added
- nginx:1.25-alpine - Reverse proxy for TLS termination
- slowapi==0.1.9 - Rate limiting library

#### Changed
- Python packages updated in SnapAuth service (see SnapAuth changelog)

### 🔄 Infrastructure

#### Changed
- Default network mode: isolated (FusionAuth/DB internal-only)
- Image distribution: pre-built tarballs for air-gapped deployment
- Deployment strategy: release-based instead of git-submodule-based

### ⚠️ Breaking Changes Summary

1. **API Authentication**: Admin endpoints require `X-SnapAuth-API-Key` header
2. **Access Control**: DELETE /v1/users/{id} is self-only (403 if not owner)
3. **Rate Limits**: Login limited to 10/minute (returns 429 when exceeded)
4. **Network Ports**: HTTPS (443) instead of HTTP (8080) in production
5. **Network Access**: FusionAuth (9011) and PostgreSQL (5432) internal-only
6. **Environment Variables**: New required variables (see .env.example)

See [MIGRATION.md](docs/MIGRATION.md) for detailed upgrade instructions.

### 🎯 Compliance

This release addresses:
- **OWASP API Security Top 10** - Critical findings resolved (API1, API2, API4, API5, API8)
- **SOC 2** - Audit logging, access controls, encryption
- **HIPAA** - Audit trails, data protection, access logging
- **PCI-DSS** - Network segmentation, encryption, logging
- **NIST 800-53** - System isolation, access control, audit records

### 📊 Metrics

- **Lines of code added**: ~3,500 (security modules, scripts, documentation)
- **Security modules**: 6 new modules (api_key, ip_whitelist, dependencies, rate_limit, middleware, audit)
- **Documentation**: 1,400+ lines across 5 comprehensive guides
- **Configuration examples**: 140+ lines in .env.example
- **Test coverage**: Security test suite added

---

## [1.0.0] - 2025-01-15

### Added
- Initial release of SnapAuth Platform
- Docker Compose deployment
- FusionAuth integration
- PostgreSQL database
- Bootstrap configuration
- Basic health checks
- Makefile automation

### Security
- Basic JWT authentication
- Database password generation

---

## Release Notes

### v2.0.0 Highlights

**Production-Ready Security:**
SnapAuth Platform v2.0.0 transforms the authentication service from a development prototype into an enterprise-grade, production-ready deployment with comprehensive security hardening.

**Key Improvements:**
- 🔐 **Defense in Depth**: Multiple security layers (TLS, API keys, rate limiting, network isolation)
- 🏢 **Enterprise Features**: Audit logging, backup/restore, secrets rotation
- ✈️ **Air-Gapped Ready**: Works on completely isolated servers
- 📊 **Compliance Ready**: Addresses OWASP API Top 10, SOC 2, HIPAA, PCI-DSS requirements

**Target Deployments:**
- Organizations deploying on isolated/air-gapped servers
- Environments requiring strong security posture
- Production authentication services
- Regulated industries (healthcare, finance, government)

**Migration Priority:**
**High Priority** - This release fixes critical security vulnerabilities. Upgrade as soon as possible.

See [MIGRATION.md](docs/MIGRATION.md) for upgrade instructions.

---

[2.0.0]: https://github.com/.../compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/.../releases/tag/v1.0.0
