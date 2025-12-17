#!/bin/bash
################################################################################
# Rebuild Neonize Container with Session Fix
# Rebuilds Docker image with updated n8n_bridge.py that stores sessions correctly
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/neonize-emergency"

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║  Rebuild Neonize Container                        ║
║  Fix: Database path → sessions directory          ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check docker access
if ! docker ps &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker permission issue detected${NC}"
    echo -e "${BLUE}Activating docker group...${NC}"
    exec sg docker -c "$0"
fi

# Check if directory exists
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${RED}✗ Installation directory not found: $INSTALL_DIR${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

echo -e "${BLUE}📋 What this script does:${NC}"
echo "1. Downloads updated n8n_bridge.py (stores sessions in /app/sessions)"
echo "2. Rebuilds Docker image with the fix"
echo "3. Restarts container with new image"
echo "4. Verifies session files are created correctly"
echo ""

echo -e "${YELLOW}⚠ Important:${NC}"
echo "  After rebuild, you will need to scan QR code again"
echo "  But sessions will now persist correctly!"
echo ""

read -p "Continue with rebuild? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}🔄 Step 1: Downloading updated files...${NC}"
echo ""

# Download updated n8n_bridge.py
echo "Downloading n8n_bridge.py..."
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/examples/n8n_bridge.py \
    -o examples/n8n_bridge.py

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Downloaded n8n_bridge.py${NC}"
else
    echo -e "${RED}✗ Failed to download n8n_bridge.py${NC}"
    exit 1
fi

# Download updated Dockerfile (if needed)
echo "Downloading Dockerfile.bridge..."
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/Dockerfile.bridge \
    -o Dockerfile.bridge

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Downloaded Dockerfile.bridge${NC}"
else
    echo -e "${RED}✗ Failed to download Dockerfile.bridge${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🛠️  Step 2: Rebuilding Docker image...${NC}"
echo ""

# Stop container
echo "Stopping container..."
docker compose -f docker-compose.emergency.yml stop neonize_bridge

# Remove old container
echo "Removing old container..."
docker compose -f docker-compose.emergency.yml rm -f neonize_bridge

# Remove old image (force rebuild)
echo "Removing old image..."
docker rmi -f neonize-emergency-neonize_bridge 2>/dev/null || true

# Rebuild image
echo "Building new image..."
docker compose -f docker-compose.emergency.yml build neonize_bridge

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Image rebuilt successfully${NC}"
else
    echo -e "${RED}✗ Failed to build image${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🚀 Step 3: Starting container...${NC}"
echo ""

# Clear old sessions (they won't work with new setup)
if [ -d "$INSTALL_DIR/sessions" ]; then
    echo "Clearing old sessions..."
    rm -rf "$INSTALL_DIR/sessions"/*
    echo -e "${GREEN}✓ Old sessions cleared${NC}"
fi

# Ensure sessions directory exists with correct permissions
mkdir -p "$INSTALL_DIR/sessions"
chmod 777 "$INSTALL_DIR/sessions"

# Start container
echo "Starting neonize_bridge..."
docker compose -f docker-compose.emergency.yml up -d neonize_bridge

echo ""
echo -e "${GREEN}⏳ Waiting for container to start (10 seconds)...${NC}"
sleep 10

echo ""
echo -e "${BLUE}✅ Step 4: Verification${NC}"
echo ""

# Check container status
if docker ps --format '{{.Names}}' | grep -q "^emergency_neonize$"; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container is NOT running${NC}"
    echo ""
    echo "Check logs:"
    echo "  docker logs emergency_neonize"
    exit 1
fi

# Check logs for database path
echo ""
echo "Checking database configuration in logs..."
DATABASE_LOG=$(docker logs emergency_neonize 2>&1 | grep "Using database" || echo "")

if [[ -n "$DATABASE_LOG" ]]; then
    echo -e "${GREEN}✓ Database configuration:${NC}"
    echo "  $DATABASE_LOG"

    if [[ "$DATABASE_LOG" == *"sessions/"* ]]; then
        echo -e "${GREEN}✓ Database path is correct (in sessions directory)${NC}"
    else
        echo -e "${YELLOW}⚠ Database path might not be in sessions directory${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not find database path in logs${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Rebuild Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📱 Next Steps:${NC}"
echo ""

echo -e "${BLUE}1. View QR code to pair WhatsApp:${NC}"
echo "   docker logs emergency_neonize -f"
echo ""

echo -e "${BLUE}2. Scan QR code with WhatsApp${NC}"
echo "   Open WhatsApp → Settings → Linked Devices → Link a Device"
echo ""

echo -e "${BLUE}3. After successful pairing, verify session files:${NC}"
echo "   ls -la $INSTALL_DIR/sessions/"
echo "   # Should see: emergency_bot.db and other session files"
echo ""

echo -e "${BLUE}4. Test persistence by restarting:${NC}"
echo "   docker restart emergency_neonize"
echo "   docker logs emergency_neonize"
echo "   # Should reconnect WITHOUT showing QR code"
echo ""

echo -e "${BLUE}5. Verify with diagnostic:${NC}"
echo "   ./diagnose.sh"
echo ""

echo -e "${CYAN}💡 What changed:${NC}"
echo "Before: Database created at /app/emergency_bot (not in mounted volume)"
echo "After:  Database created at /app/sessions/emergency_bot.db (in bind mount)"
echo ""
echo "This ensures session data persists correctly on the host filesystem!"
echo ""

# Show current container logs (last 20 lines)
echo -e "${BLUE}📋 Current container logs:${NC}"
echo ""
docker logs emergency_neonize --tail 20
echo ""

echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${CYAN}Rebuild process complete. Ready to pair!${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
