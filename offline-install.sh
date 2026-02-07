#!/bin/bash
# SnapAuth Offline Installation Script
# Loads Docker images from tarballs for air-gapped deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="${SCRIPT_DIR}/images"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}SnapAuth Offline Installation${NC}"
echo "========================================="

# Check if images directory exists
if [ ! -d "$IMAGES_DIR" ]; then
    echo -e "${RED}Error: Images directory not found: $IMAGES_DIR${NC}"
    echo "Expected structure:"
    echo "  snapauth-release-vX.X.X/"
    echo "  ├── images/"
    echo "  │   ├── snapauth-vX.X.X.tar"
    echo "  │   ├── bootstrap-vX.X.X.tar"
    echo "  │   ├── fusionauth-X.XX.X.tar"
    echo "  │   └── postgres-16-alpine.tar"
    echo "  └── offline-install.sh"
    exit 1
fi

# Count image files
IMAGE_COUNT=$(find "$IMAGES_DIR" -name "*.tar" | wc -l)

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo -e "${RED}Error: No image tarballs found in $IMAGES_DIR${NC}"
    exit 1
fi

echo "Found $IMAGE_COUNT image tarball(s)"
echo ""

# Load each image
LOADED=0
FAILED=0

for image_file in "$IMAGES_DIR"/*.tar; do
    if [ -f "$image_file" ]; then
        image_name=$(basename "$image_file")
        echo -n "Loading $image_name... "
        
        if docker load < "$image_file" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            LOADED=$((LOADED + 1))
        else
            echo -e "${RED}✗ FAILED${NC}"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "========================================="
echo "Summary:"
echo "  Loaded: $LOADED"
echo "  Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    echo -e "${YELLOW}Warning: Some images failed to load${NC}"
fi

# Verify images
echo ""
echo "Verifying loaded images..."

docker images | grep -E "snapauth|fusionauth|postgres" || echo -e "${YELLOW}No SnapAuth images found${NC}"

echo ""
echo -e "${GREEN}✓ Offline installation complete${NC}"
echo ""
echo "Next steps:"
echo "  1. Review VERSION.yml for component versions"
echo "  2. Run: make up"
echo "  3. Verify deployment: make health"
