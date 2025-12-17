#!/bin/bash
################################################################################
# Neonize Emergency Response - Quick Install Script
# One-liner: curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/quick-install.sh | bash
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║  Neonize Emergency Response Chatbot              ║
║  Quick Install for Ubuntu 24.04                  ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Mode: Auto-Yes (all prompts will use defaults)${NC}"
echo ""

# Download full installer
echo -e "${YELLOW}Downloading full installer...${NC}"
curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh -o /tmp/neonize-install.sh

# Make executable
chmod +x /tmp/neonize-install.sh

# Run installer with AUTO_YES mode
echo -e "${GREEN}Starting installation...${NC}"
export AUTO_YES=1
exec /tmp/neonize-install.sh
