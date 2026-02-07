# Network Deployment Modes

SnapAuth supports two deployment modes for different network architectures.

## Mode 1: Isolated (Default)

**Use when:** Deploying SnapAuth as a standalone service.

**Architecture:**
```
Internet → Nginx (443) → SnapAuth (8080) → FusionAuth (9011) → PostgreSQL (5432)
           │              │                  ↓                   ↓
         Public        Public           INTERNAL ONLY      INTERNAL ONLY
                                     (not accessible)    (not accessible)
```

**Networks:**
- `snapauth-internal` - External access to SnapAuth (via Nginx)
- `fusionauth-backend` - Isolated internal network (FusionAuth + DB)

**Deployment:**
```bash
make up                    # Default: isolated mode
make up MODE=isolated      # Explicit
```

**Exposed Ports:**
- `80` (HTTP → HTTPS redirect)
- `443` (HTTPS)

**Not Exposed:**
- `8080` (SnapAuth) - Access via Nginx only
- `9011` (FusionAuth) - Internal only
- `5432` (PostgreSQL) - Internal only

## Mode 2: Microservices Integration

**Use when:** Integrating SnapAuth with existing microservices architecture.

**Architecture:**
```
Shared Services Network (shared-services)
├── SnapAuth (joins network)
├── Your App Service
├── Another Service
└── ...

SnapAuth also on:
├── snapauth-internal (Nginx access)
└── fusionauth-backend (FusionAuth/DB access)
```

**Networks:**
- `snapauth-internal` - External access
- `fusionauth-backend` - Internal (FusionAuth + DB)
- `shared-services` - **Added:** Communicate with other services

**Deployment:**
```bash
# Create shared-services network first (if not exists)
docker network create shared-services

# Deploy in microservices mode
make up MODE=microservices
```

**Override file:** `docker-compose.microservices.yml`

## Network Isolation Matrix

| Service | Isolated Mode | Microservices Mode |
|---------|--------------|-------------------|
| Nginx | Public (80/443) | Public (80/443) |
| SnapAuth | Via Nginx only | Via Nginx + shared-services |
| FusionAuth | Internal only | Internal only |
| PostgreSQL | Internal only | Internal only |

## Security Comparison

### Isolated Mode (Recommended)
✅ Maximum security  
✅ Zero external dependencies  
✅ Smallest attack surface  
✅ Easiest to audit  

Use for: Standalone auth services, security-critical deployments

### Microservices Mode
✅ Integration with existing infrastructure  
✅ Service-to-service communication  
⚠️ Larger attack surface  
⚠️ Requires network security policies  

Use for: Microservices architectures, service meshes

## Network Security

### Isolated Mode

**Traffic Flow:**
```
Client
  ↓ HTTPS
Nginx (TLS termination)
  ↓ HTTP (internal)
SnapAuth (API key + IP whitelist + rate limit)
  ↓ HTTP (internal network)
FusionAuth (not accessible externally)
  ↓ TCP (internal network)
PostgreSQL (not accessible externally)
```

**Defense Layers:**
1. TLS encryption (Nginx)
2. Application auth (SnapAuth)
3. Network isolation (Docker networks)

### Microservices Mode

**Additional Access:**
```
Other Service (on shared-services)
  ↓ HTTP (internal network)
SnapAuth (API key required)
```

**Best Practices:**
1. Require API keys for all shared-services traffic
2. Implement mutual TLS (mTLS) on shared-services network
3. Use network policies to restrict which services can access SnapAuth
4. Monitor cross-service traffic

## Switching Modes

### From Isolated to Microservices

```bash
# 1. Create shared network
docker network create shared-services

# 2. Restart in microservices mode
make stop
make up MODE=microservices

# 3. Verify
docker network inspect shared-services
# Should show snapauth service
```

### From Microservices to Isolated

```bash
# 1. Stop services
make stop

# 2. Restart in isolated mode
make up

# 3. Optionally remove shared network
docker network rm shared-services  # If no other services use it
```

## Configuration

Mode is controlled by `MODE` environment variable in Makefile.

**Default:** isolated

**Change default:**
```makefile
# In Makefile
MODE ?= microservices  # Change default
```

## Verification

### Check Networks

```bash
# List networks
docker network ls

# Inspect network
docker network inspect snapauth-platform_snapauth-internal

# See which services are on network
docker network inspect shared-services
```

### Test Connectivity

```bash
# From another service on shared-services
docker run --rm --network shared-services curlimages/curl \
  curl http://snapauth:8080/health

# Should work in microservices mode
# Should fail in isolated mode
```
