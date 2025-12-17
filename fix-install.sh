#!/bin/bash
################################################################################
# Neonize Emergency Response - Fix & Continue Installation
# Pure curl, no git required
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/neonize-emergency"
BASE_URL="https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV"

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║  Fix & Continue Installation                      ║
║  Pure curl - No git required                      ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if directory exists
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${RED}✗ Installation directory not found: $INSTALL_DIR${NC}"
    echo -e "${YELLOW}Please run the main installer first.${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

echo -e "${GREEN}✓ Found installation directory${NC}"
echo ""

# Check docker access
if ! docker ps &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker permission issue detected${NC}"
    echo -e "${BLUE}Activating docker group...${NC}"
    exec sg docker -c "$0"
fi

echo -e "${GREEN}✓ Docker access OK${NC}"
echo ""

# Download updated files
echo -e "${BLUE}📥 Downloading updated files...${NC}"
echo ""

FILES=(
    "Dockerfile.bridge"
    "docker-compose.emergency.yml"
    "examples/n8n_bridge.py"
    ".env.example"
    "init-db.sql"
)

for file in "${FILES[@]}"; do
    echo -e "${YELLOW}  → $file${NC}"

    # Create directory if needed
    dir=$(dirname "$file")
    if [[ "$dir" != "." ]]; then
        mkdir -p "$dir"
    fi

    # Download file
    if curl -sSL "${BASE_URL}/${file}" -o "$file"; then
        echo -e "${GREEN}    ✓ Downloaded${NC}"
    else
        echo -e "${RED}    ✗ Failed to download${NC}"
    fi
done

echo ""
echo -e "${GREEN}✓ All files downloaded${NC}"
echo ""

# Stop existing containers if any
echo -e "${BLUE}🛑 Stopping existing containers...${NC}"
docker compose -f docker-compose.emergency.yml down 2>/dev/null || true
echo ""

# Remove old images to force rebuild
echo -e "${BLUE}🗑️  Removing old neonize_bridge image...${NC}"
docker rmi emergency-neonize_bridge 2>/dev/null || true
docker rmi neonize-emergency-neonize_bridge 2>/dev/null || true
echo ""

# Pull/Build images
echo -e "${BLUE}🐳 Building Docker images...${NC}"
docker compose -f docker-compose.emergency.yml build --no-cache neonize_bridge
echo ""

echo -e "${BLUE}📥 Pulling other images...${NC}"
docker compose -f docker-compose.emergency.yml pull
echo ""

# Start services
echo -e "${BLUE}🚀 Starting services...${NC}"
docker compose -f docker-compose.emergency.yml up -d
echo ""

echo -e "${GREEN}⏳ Waiting for services to start...${NC}"
sleep 15

# Check status
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
echo ""
docker compose -f docker-compose.emergency.yml ps
echo ""

# Check API health
echo -e "${BLUE}🏥 Checking API health...${NC}"
sleep 5

if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API is healthy${NC}"
else
    echo -e "${YELLOW}⚠ API may still be starting...${NC}"
    echo -e "${BLUE}  Check with: curl http://localhost:8000/health${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📱 Next Steps:${NC}"
echo ""
echo -e "${BLUE}1. View QR Code to connect WhatsApp:${NC}"
echo -e "   docker logs emergency_neonize -f"
echo ""
echo -e "${BLUE}2. Access services:${NC}"
echo -e "   • API Docs:  http://localhost:8000/docs"
echo -e "   • n8n:       http://localhost:5678"
echo -e "   • Grafana:   http://localhost:3000"
echo ""
echo -e "${BLUE}3. View credentials:${NC}"
echo -e "   cat $INSTALL_DIR/credentials.txt"
echo ""
echo -e "${BLUE}4. Check logs:${NC}"
echo -e "   docker compose -f docker-compose.emergency.yml logs -f"
echo ""
