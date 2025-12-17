#!/bin/bash
################################################################################
# Neonize Emergency Response - Continue Installation Script
# Use this if installation was interrupted or you want to continue manually
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/neonize-emergency"

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║  Continue Installation                            ║
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
    echo ""
    echo -e "${BLUE}Activating docker group...${NC}"
    exec sg docker -c "$0"
fi

echo -e "${GREEN}✓ Docker access OK${NC}"
echo ""

# Check what needs to be done
echo -e "${BLUE}Checking installation status...${NC}"
echo ""

# Check if containers are running
if docker compose -f docker-compose.emergency.yml ps | grep -q "Up"; then
    echo -e "${GREEN}✓ Services already running${NC}"
    echo ""
    docker compose -f docker-compose.emergency.yml ps
    echo ""
    echo -e "${YELLOW}To view QR code, run:${NC}"
    echo -e "${BLUE}docker logs emergency_neonize -f${NC}"
    exit 0
fi

# Services not running, start them
echo -e "${YELLOW}Services not running. Starting now...${NC}"
echo ""

# Pull images if needed
echo -e "${BLUE}Pulling Docker images...${NC}"
docker compose -f docker-compose.emergency.yml pull

# Start services
echo -e "${BLUE}Starting services...${NC}"
docker compose -f docker-compose.emergency.yml up -d

echo ""
echo -e "${GREEN}Waiting for services to start...${NC}"
sleep 10

# Show status
echo ""
docker compose -f docker-compose.emergency.yml ps

# Check health
echo ""
echo -e "${BLUE}Checking API health...${NC}"
sleep 5

if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API is healthy${NC}"
else
    echo -e "${YELLOW}⚠ API may still be starting. Wait 30 seconds then check:${NC}"
    echo -e "${BLUE}curl http://localhost:8000/health${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📱 To connect WhatsApp:${NC}"
echo -e "   ${BLUE}docker logs emergency_neonize -f${NC}"
echo ""
echo -e "${YELLOW}🌐 Access services:${NC}"
echo -e "   API:     http://localhost:8000/docs"
echo -e "   n8n:     http://localhost:5678"
echo -e "   Grafana: http://localhost:3000"
echo ""
echo -e "${YELLOW}📋 View credentials:${NC}"
echo -e "   ${BLUE}cat $INSTALL_DIR/credentials.txt${NC}"
echo ""
