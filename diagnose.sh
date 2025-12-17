#!/bin/bash
################################################################################
# Neonize Emergency Bot - Diagnostic Script
# Pure bash + curl, no git needed
################################################################################

set +e  # Don't exit on error

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
║  Neonize Emergency Bot - Diagnostic Tool         ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Collecting diagnostic information..."
echo ""

# Function to print section header
print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
    fi
}

# =============================================================================
# 1. SYSTEM INFO
# =============================================================================
print_section "1. System Information"

echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Date: $(date)"
echo "Uptime: $(uptime -p)"

# =============================================================================
# 2. DOCKER STATUS
# =============================================================================
print_section "2. Docker Status"

# Check docker installed
if command -v docker &> /dev/null; then
    print_result 0 "Docker installed"
    echo "   Version: $(docker --version)"
else
    print_result 1 "Docker NOT installed"
    exit 1
fi

# Check docker running
if docker ps &> /dev/null; then
    print_result 0 "Docker accessible (no sudo needed)"
else
    print_result 1 "Docker permission denied (need newgrp docker)"
    echo ""
    echo -e "${YELLOW}FIX: Run this command first:${NC}"
    echo -e "${CYAN}newgrp docker${NC}"
    exit 1
fi

# =============================================================================
# 3. CONTAINERS STATUS
# =============================================================================
print_section "3. Containers Status"

cd "$INSTALL_DIR" 2>/dev/null || {
    print_result 1 "Installation directory not found: $INSTALL_DIR"
    exit 1
}

echo ""
docker compose -f docker-compose.emergency.yml ps
echo ""

# Check each container
CONTAINERS=(
    "emergency_postgres:PostgreSQL Database"
    "emergency_n8n:n8n Workflow"
    "emergency_neonize:Neonize Bot"
    "emergency_grafana:Grafana Dashboard"
    "emergency_redis:Redis Cache"
)

for container_info in "${CONTAINERS[@]}"; do
    IFS=: read -r container_name description <<< "$container_info"
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        status=$(docker inspect --format='{{.State.Status}}' "$container_name")
        if [ "$status" = "running" ]; then
            print_result 0 "$description ($container_name)"
        else
            print_result 1 "$description ($container_name) - Status: $status"
        fi
    else
        print_result 1 "$description ($container_name) - NOT RUNNING"
    fi
done

# =============================================================================
# 4. NEONIZE BOT DETAILED STATUS
# =============================================================================
print_section "4. Neonize Bot Detailed Status"

if docker ps --format '{{.Names}}' | grep -q "^emergency_neonize$"; then
    echo "Container Status: RUNNING"
    echo ""

    # Check uptime
    uptime=$(docker inspect --format='{{.State.StartedAt}}' emergency_neonize)
    echo "Started At: $uptime"
    echo ""

    # Check logs for connection status
    echo "Checking logs for connection status..."
    echo ""

    if docker logs emergency_neonize 2>&1 | grep -q "Successfully paired"; then
        print_result 0 "Bot successfully paired"
    else
        print_result 1 "Bot NOT paired yet"
    fi

    if docker logs emergency_neonize 2>&1 | grep -q "Successfully authenticated"; then
        print_result 0 "Bot successfully authenticated"
    else
        print_result 1 "Bot NOT authenticated"
    fi

    if docker logs emergency_neonize 2>&1 | grep -q "Login event: success"; then
        print_result 0 "Login successful"
    else
        print_result 1 "Login NOT successful"
    fi

    # Check for errors
    echo ""
    echo "Recent errors in logs:"
    docker logs emergency_neonize --tail 50 2>&1 | grep -i "error" | tail -5

    # Check for warnings
    echo ""
    echo "Recent warnings in logs:"
    docker logs emergency_neonize --tail 50 2>&1 | grep -i "warning" | tail -5

else
    print_result 1 "Container NOT RUNNING"
fi

# =============================================================================
# 5. API HEALTH CHECK
# =============================================================================
print_section "5. API Health Check"

# Check port 8000 listening
if ss -tlnp 2>/dev/null | grep -q ":8000 "; then
    print_result 0 "Port 8000 is listening"
else
    print_result 1 "Port 8000 is NOT listening"
fi

# Test health endpoint
echo ""
echo "Testing health endpoint..."
response=$(curl -s http://localhost:8000/health 2>&1)
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>&1)

echo "HTTP Status Code: $http_code"
echo "Response:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

# Parse response
if echo "$response" | grep -q '"neonize_connected":true'; then
    print_result 0 "Neonize connected: TRUE"
elif echo "$response" | grep -q '"neonize_connected":false'; then
    print_result 1 "Neonize connected: FALSE"
else
    print_result 1 "Cannot determine connection status"
fi

# =============================================================================
# 6. ENVIRONMENT CONFIGURATION
# =============================================================================
print_section "6. Environment Configuration"

if [ -f "$INSTALL_DIR/.env" ]; then
    print_result 0 ".env file exists"
    echo ""
    echo "Admin numbers configured:"
    grep "ADMIN_NUMBERS" "$INSTALL_DIR/.env" | sed 's/ADMIN_NUMBERS=/  /'
    echo ""
    echo "Session name:"
    grep "SESSION_NAME" "$INSTALL_DIR/.env" | sed 's/SESSION_NAME=/  /'
else
    print_result 1 ".env file NOT found"
fi

# =============================================================================
# 7. DATABASE STATUS
# =============================================================================
print_section "7. Database Status"

if docker ps --format '{{.Names}}' | grep -q "^emergency_postgres$"; then
    print_result 0 "PostgreSQL container running"

    # Test database connection
    if docker exec emergency_postgres pg_isready -U emergency &>/dev/null; then
        print_result 0 "Database accepting connections"

        # Check tables
        echo ""
        echo "Database tables:"
        docker exec emergency_postgres psql -U emergency -d emergency_db -c "\dt" 2>/dev/null | grep "public" | awk '{print "  - "$2}'

    else
        print_result 1 "Database NOT accepting connections"
    fi
else
    print_result 1 "PostgreSQL container NOT running"
fi

# =============================================================================
# 8. NETWORK CONNECTIVITY
# =============================================================================
print_section "8. Network Connectivity"

# Check if bot can reach WhatsApp
echo "Checking network connectivity..."
echo ""

if ping -c 2 web.whatsapp.com &>/dev/null; then
    print_result 0 "Can reach web.whatsapp.com"
else
    print_result 1 "Cannot reach web.whatsapp.com"
fi

if curl -s https://web.whatsapp.com &>/dev/null; then
    print_result 0 "HTTPS connection to WhatsApp OK"
else
    print_result 1 "HTTPS connection to WhatsApp FAILED"
fi

# =============================================================================
# 9. SESSION FILES & VOLUME CONFIGURATION
# =============================================================================
print_section "9. Session Files & Volume Configuration"

# Check host directory
if [ -d "$INSTALL_DIR/sessions" ]; then
    print_result 0 "Sessions directory exists on host"

    session_count=$(find "$INSTALL_DIR/sessions" -type f 2>/dev/null | wc -l)
    echo "   Files in host sessions: $session_count"
    echo "   Directory: $INSTALL_DIR/sessions/"
    echo "   Permissions: $(stat -c '%a' "$INSTALL_DIR/sessions")"

    if [ $session_count -gt 0 ]; then
        print_result 0 "Session files found on host"
        echo ""
        echo "   Files:"
        ls -lh "$INSTALL_DIR/sessions/" | tail -n +2 | awk '{print "     "$9" ("$5")"}'
    else
        print_result 1 "No session files on host"
    fi
else
    print_result 1 "Sessions directory NOT found on host"
fi

echo ""

# Check volume mount type
if docker ps --format '{{.Names}}' | grep -q "^emergency_neonize$"; then
    echo "Checking volume mount configuration..."

    # Check if it's a bind mount or named volume
    MOUNT_TYPE=$(docker inspect emergency_neonize | grep -A 10 "Mounts" | grep -o '"Type": "[^"]*"' | head -1 | cut -d'"' -f4)
    MOUNT_SOURCE=$(docker inspect emergency_neonize | grep -A 10 "Mounts" | grep "sessions" -A 2 | grep "Source" | cut -d'"' -f4)

    echo "   Mount type: $MOUNT_TYPE"
    echo "   Source: $MOUNT_SOURCE"

    if [ "$MOUNT_TYPE" = "bind" ]; then
        print_result 0 "Using bind mount (CORRECT - sessions persist to host)"
    else
        print_result 1 "Using named volume (WRONG - sessions in Docker volume, not host)"
        echo ""
        echo -e "${RED}   ⚠ This is the problem!${NC}"
        echo "   Sessions are saved in Docker volume, not on host filesystem"
        echo ""
        echo -e "${YELLOW}   FIX: Run this command:${NC}"
        echo -e "   ${CYAN}./fix-sessions.sh${NC}"
    fi

    # Check inside container
    echo ""
    echo "Checking inside container..."
    CONTAINER_SESSION_COUNT=$(docker exec emergency_neonize sh -c "ls -A /app/sessions 2>/dev/null | wc -l" 2>/dev/null || echo "0")
    echo "   Files in container /app/sessions: $CONTAINER_SESSION_COUNT"

    if [ "$CONTAINER_SESSION_COUNT" -gt 0 ]; then
        print_result 0 "Session files exist inside container"
        docker exec emergency_neonize sh -c "ls -lh /app/sessions 2>/dev/null" | tail -n +2 | awk '{print "     "$9" ("$5")"}'
    else
        print_result 1 "No session files inside container"
    fi
fi

# =============================================================================
# 10. RECENT LOGS
# =============================================================================
print_section "10. Recent Bot Logs (Last 20 lines)"

echo ""
docker logs emergency_neonize --tail 20 2>&1

# =============================================================================
# 11. DISK SPACE
# =============================================================================
print_section "11. Disk Space"

echo ""
df -h "$INSTALL_DIR" | tail -1 | awk '{print "Available space: "$4" ("$5" used)"}'

# =============================================================================
# 12. RECOMMENDATIONS
# =============================================================================
print_section "12. Diagnostic Summary & Recommendations"

echo ""

# Determine main issue
bot_paired=$(docker logs emergency_neonize 2>&1 | grep -q "Successfully paired" && echo "yes" || echo "no")
bot_authenticated=$(docker logs emergency_neonize 2>&1 | grep -q "Successfully authenticated" && echo "yes" || echo "no")
api_connected=$(curl -s http://localhost:8000/health 2>&1 | grep -q '"neonize_connected":true' && echo "yes" || echo "no")
mount_type=$(docker inspect emergency_neonize 2>/dev/null | grep -A 10 "Mounts" | grep -o '"Type": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
session_files_host=$(find "$INSTALL_DIR/sessions" -type f 2>/dev/null | wc -l)

echo -e "${YELLOW}Status Summary:${NC}"
echo "  Bot Paired: $bot_paired"
echo "  Bot Authenticated: $bot_authenticated"
echo "  API Reports Connected: $api_connected"
echo "  Volume Mount Type: $mount_type"
echo "  Session Files on Host: $session_files_host"
echo ""

# Check for volume mount issue first (most critical)
if [ "$mount_type" != "bind" ] && [ "$mount_type" != "unknown" ]; then
    echo -e "${RED}CRITICAL ISSUE: Wrong volume mount configuration${NC}"
    echo ""
    echo "Your sessions are being saved to a Docker volume instead of the host filesystem."
    echo "This causes session persistence problems and requires re-scanning QR code."
    echo ""
    echo -e "${YELLOW}FIX:${NC}"
    echo "1. Run the fix script:"
    echo -e "   ${CYAN}cd $INSTALL_DIR${NC}"
    echo -e "   ${CYAN}./fix-sessions.sh${NC}"
    echo ""
    echo "This will:"
    echo "  - Copy any existing sessions from Docker volume to host"
    echo "  - Update docker-compose to use bind mount"
    echo "  - Restart services with correct configuration"
    echo ""

elif [ "$bot_paired" = "no" ]; then
    echo -e "${RED}ISSUE: Bot not paired${NC}"
    echo ""
    echo -e "${YELLOW}FIX:${NC}"
    echo "1. View QR code:"
    echo -e "   ${CYAN}docker logs emergency_neonize -f${NC}"
    echo ""
    echo "2. Scan with WhatsApp on phone"
    echo "   - Open WhatsApp"
    echo "   - Tap menu (⋮) → Linked Devices"
    echo "   - Tap 'Link a Device'"
    echo "   - Scan the QR code"

elif [ "$bot_authenticated" = "no" ]; then
    echo -e "${RED}ISSUE: Bot paired but not authenticated${NC}"
    echo ""
    echo -e "${YELLOW}FIX:${NC}"
    echo "1. Restart bot container:"
    echo -e "   ${CYAN}cd $INSTALL_DIR${NC}"
    echo -e "   ${CYAN}docker compose -f docker-compose.emergency.yml restart neonize_bridge${NC}"
    echo ""
    echo "2. If still fails, clear session and re-pair:"
    echo -e "   ${CYAN}docker compose -f docker-compose.emergency.yml down${NC}"
    echo -e "   ${CYAN}rm -rf sessions/*${NC}"
    echo -e "   ${CYAN}docker compose -f docker-compose.emergency.yml up -d${NC}"

elif [ "$api_connected" = "no" ] && [ "$bot_authenticated" = "yes" ]; then
    echo -e "${YELLOW}ISSUE: Bot authenticated but API reports disconnected${NC}"
    echo ""
    echo "This is a timing/sync issue. Bot is actually working."
    echo ""
    echo -e "${YELLOW}FIX:${NC}"
    echo "1. Wait 60 seconds for full sync"
    echo ""
    echo "2. Test by sending message to bot:"
    echo "   Send 'halo' to the WhatsApp number you scanned"
    echo ""
    echo "3. Check if bot replies. If yes, bot is working!"
    echo "   (Ignore the health check status)"

else
    echo -e "${GREEN}✓ Bot appears to be working correctly!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Test bot by sending message:"
    echo "   Send 'halo' to your bot's WhatsApp number"
    echo ""
    echo "2. Access services:"
    echo "   - API: http://localhost:8000/docs"
    echo "   - n8n: http://localhost:5678"
    echo "   - Grafana: http://localhost:3000"
fi

# =============================================================================
# 13. QUICK FIX COMMANDS
# =============================================================================
print_section "13. Quick Fix Commands"

echo ""
echo -e "${CYAN}# Restart bot only:${NC}"
echo "cd $INSTALL_DIR"
echo "docker compose -f docker-compose.emergency.yml restart neonize_bridge"
echo ""

echo -e "${CYAN}# Restart all services:${NC}"
echo "cd $INSTALL_DIR"
echo "docker compose -f docker-compose.emergency.yml restart"
echo ""

echo -e "${CYAN}# Full restart (clear sessions):${NC}"
echo "cd $INSTALL_DIR"
echo "docker compose -f docker-compose.emergency.yml down"
echo "rm -rf sessions/*"
echo "docker compose -f docker-compose.emergency.yml up -d"
echo ""

echo -e "${CYAN}# View logs:${NC}"
echo "docker logs emergency_neonize -f"
echo ""

echo -e "${CYAN}# Check health:${NC}"
echo "curl http://localhost:8000/health | python3 -m json.tool"
echo ""

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}Diagnostic Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Copy the output above and share for troubleshooting."
echo ""
