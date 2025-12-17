#!/bin/bash
################################################################################
# Fix Session Persistence Issue
# Changes from Docker named volume to host bind mount
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
║  Fix Session Persistence Issue                    ║
║  Docker Volume → Host Bind Mount                  ║
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

echo -e "${BLUE}🔍 Analyzing current configuration...${NC}"
echo ""

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "^emergency_neonize$"; then
    echo -e "${GREEN}✓ Container is running${NC}"
    CONTAINER_RUNNING=1
else
    echo -e "${YELLOW}⚠ Container is not running${NC}"
    CONTAINER_RUNNING=0
fi

# Check current volume type
VOLUME_INFO=$(docker compose -f docker-compose.emergency.yml config | grep -A 2 "volumes:" | grep "neonize_sessions" || echo "")

if [[ -n "$VOLUME_INFO" ]]; then
    echo -e "${RED}✗ Using Docker named volume (this is the problem!)${NC}"
    echo "   Current: neonize_sessions:/app/sessions"
    echo "   Should be: ./sessions:/app/sessions"
    NEEDS_FIX=1
else
    echo -e "${GREEN}✓ Already using bind mount${NC}"
    NEEDS_FIX=0
fi

echo ""

if [[ $NEEDS_FIX -eq 0 ]]; then
    echo -e "${GREEN}No fix needed! Configuration is already correct.${NC}"
    echo ""
    echo -e "${YELLOW}If sessions are still not persisting, check:${NC}"
    echo "1. Directory permissions: ls -la $INSTALL_DIR/sessions/"
    echo "2. Container logs: docker logs emergency_neonize"
    echo "3. Check if neonize is writing to /app/sessions inside container"
    exit 0
fi

# ==============================================================================
# BACKUP EXISTING SESSIONS FROM DOCKER VOLUME
# ==============================================================================
echo -e "${BLUE}📦 Backing up existing session data from Docker volume...${NC}"
echo ""

# Create temporary container to access volume
TMP_CONTAINER="temp_session_backup_$$"

if docker volume ls | grep -q "neonize_sessions"; then
    echo "Found Docker volume: neonize_sessions"

    # Create temp container with volume mounted
    docker run -d --name "$TMP_CONTAINER" \
        -v neonize_sessions:/source \
        -v "$INSTALL_DIR/sessions":/dest \
        alpine sleep 60

    # Copy files from volume to host
    echo "Copying session files..."
    docker exec "$TMP_CONTAINER" sh -c "cp -r /source/* /dest/ 2>/dev/null || true"

    # Check what was copied
    COPIED_FILES=$(docker exec "$TMP_CONTAINER" sh -c "ls -A /source 2>/dev/null | wc -l")

    if [[ $COPIED_FILES -gt 0 ]]; then
        echo -e "${GREEN}✓ Copied $COPIED_FILES files from Docker volume${NC}"
        docker exec "$TMP_CONTAINER" sh -c "ls -lah /source"
    else
        echo -e "${YELLOW}⚠ No files found in Docker volume (volume was empty)${NC}"
    fi

    # Cleanup
    docker stop "$TMP_CONTAINER" >/dev/null 2>&1
    docker rm "$TMP_CONTAINER" >/dev/null 2>&1

    echo ""
else
    echo -e "${YELLOW}⚠ Docker volume 'neonize_sessions' not found (probably empty)${NC}"
    echo ""
fi

# ==============================================================================
# UPDATE DOCKER COMPOSE CONFIGURATION
# ==============================================================================
echo -e "${BLUE}🔧 Updating docker-compose.emergency.yml...${NC}"
echo ""

# Backup original file
cp docker-compose.emergency.yml docker-compose.emergency.yml.backup
echo -e "${GREEN}✓ Backed up to docker-compose.emergency.yml.backup${NC}"

# Replace named volume with bind mount
sed -i 's|      - neonize_sessions:/app/sessions|      - ./sessions:/app/sessions|' docker-compose.emergency.yml

# Remove neonize_sessions from volumes section
sed -i '/^  neonize_sessions:$/,/^    driver: local$/d' docker-compose.emergency.yml

echo -e "${GREEN}✓ Updated volume configuration${NC}"
echo "   Changed: neonize_sessions:/app/sessions"
echo "   To:      ./sessions:/app/sessions"
echo ""

# Show the changes
echo "New configuration:"
grep -A 3 "volumes:" docker-compose.emergency.yml | grep -A 2 "Session data"
echo ""

# ==============================================================================
# ENSURE HOST DIRECTORY EXISTS WITH CORRECT PERMISSIONS
# ==============================================================================
echo -e "${BLUE}📁 Setting up host sessions directory...${NC}"
echo ""

mkdir -p "$INSTALL_DIR/sessions"
chmod 777 "$INSTALL_DIR/sessions"

echo -e "${GREEN}✓ Directory ready: $INSTALL_DIR/sessions/${NC}"
echo "   Permissions: $(stat -c '%a' "$INSTALL_DIR/sessions")"
echo ""

# ==============================================================================
# RESTART SERVICES
# ==============================================================================
echo -e "${BLUE}🔄 Restarting services with new configuration...${NC}"
echo ""

# Stop containers
echo "Stopping containers..."
docker compose -f docker-compose.emergency.yml down

echo ""
echo "Starting containers with bind mount..."
docker compose -f docker-compose.emergency.yml up -d

echo ""
echo -e "${GREEN}⏳ Waiting for services to start (15 seconds)...${NC}"
sleep 15

# ==============================================================================
# VERIFY FIX
# ==============================================================================
echo ""
echo -e "${BLUE}✅ Verification${NC}"
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

# Check mount
MOUNT_INFO=$(docker inspect emergency_neonize | grep -A 5 "Mounts" | grep "Source")
echo "Mount configuration:"
echo "$MOUNT_INFO" | grep sessions || echo "  (checking...)"

# Verify it's a bind mount, not a volume
if docker inspect emergency_neonize | grep -A 10 "Mounts" | grep -q "\"Type\": \"bind\""; then
    echo -e "${GREEN}✓ Using bind mount (correct!)${NC}"
else
    echo -e "${RED}✗ Still using volume (incorrect)${NC}"
fi

echo ""

# ==============================================================================
# NEXT STEPS
# ==============================================================================
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Fix Applied Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📱 Next Steps:${NC}"
echo ""
echo -e "${BLUE}1. Check if session files exist:${NC}"
echo -e "   ls -la $INSTALL_DIR/sessions/"
echo ""
echo -e "${BLUE}2. View QR code to pair (if needed):${NC}"
echo -e "   docker logs emergency_neonize -f"
echo ""
echo -e "${BLUE}3. After pairing, verify session files are created:${NC}"
echo -e "   ls -la $INSTALL_DIR/sessions/"
echo -e "   # Should see files like: device.json, session.dat, etc."
echo ""
echo -e "${BLUE}4. Test persistence by restarting:${NC}"
echo -e "   docker restart emergency_neonize"
echo -e "   # Should NOT show QR code again if sessions persisted"
echo ""
echo -e "${BLUE}5. Run diagnostic:${NC}"
echo -e "   ./diagnose.sh"
echo ""
echo -e "${CYAN}💡 Tip: Session files should now persist in:${NC}"
echo -e "   $INSTALL_DIR/sessions/"
echo ""

# Show current session files if any
SESSION_COUNT=$(ls -A "$INSTALL_DIR/sessions/" 2>/dev/null | wc -l)
if [[ $SESSION_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✓ Found $SESSION_COUNT files in sessions directory:${NC}"
    ls -lh "$INSTALL_DIR/sessions/"
else
    echo -e "${YELLOW}⚠ Sessions directory is currently empty${NC}"
    echo "   This is normal if you haven't paired yet"
    echo "   After scanning QR code, files will appear here"
fi

echo ""
