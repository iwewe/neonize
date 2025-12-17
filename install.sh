#!/bin/bash

################################################################################
# Neonize Emergency Response Chatbot - Installation Script
# Ubuntu 24.04 LTS
################################################################################
#
# Usage:
#   # Interactive mode (recommended):
#   curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh -o install.sh
#   chmod +x install.sh
#   ./install.sh
#
#   # Auto-yes mode (skip all prompts):
#   export AUTO_YES=1
#   curl -sSL https://raw.githubusercontent.com/iwewe/neonize/claude/neonize-emergency-analysis-K1wGV/install.sh | bash
#
################################################################################

set -e  # Exit on error

# Auto-yes mode (set AUTO_YES=1 to skip all prompts)
AUTO_YES=${AUTO_YES:-0}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/neonize-emergency"
REPO_URL="https://github.com/iwewe/neonize.git"
REPO_BRANCH="claude/neonize-emergency-analysis-K1wGV"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-N}"

    # Auto-yes mode
    if [[ $AUTO_YES -eq 1 ]]; then
        echo -e "${YELLOW}$prompt (y/N) [AUTO-YES]${NC}"
        return 0  # Return yes
    fi

    # Interactive mode
    read -p "$prompt (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0  # Yes
    else
        return 1  # No
    fi
}

ask_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    # Auto-yes mode with default
    if [[ $AUTO_YES -eq 1 ]] && [[ -n "$default" ]]; then
        echo -e "${YELLOW}$prompt [AUTO: $default]${NC}"
        eval "$var_name='$default'"
        return 0
    fi

    # Interactive mode
    read -p "$prompt" input
    if [[ -z "$input" ]] && [[ -n "$default" ]]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root"
        print_info "Please run as a regular user. Sudo will be used when needed."
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect OS version"
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        print_error "This script is designed for Ubuntu"
        print_info "Detected: $ID"
        exit 1
    fi

    if [[ "$VERSION_ID" != "24.04" ]] && [[ "$VERSION_ID" != "22.04" ]]; then
        print_warning "This script is tested on Ubuntu 24.04 and 22.04"
        print_info "Detected: Ubuntu $VERSION_ID"
        if ! ask_yes_no "Continue anyway?"; then
            exit 1
        fi
    fi

    print_success "Ubuntu $VERSION_ID detected"
}

check_internet() {
    print_info "Checking internet connectivity..."
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "No internet connection detected"
        exit 1
    fi
    print_success "Internet connection OK"
}

check_docker_access() {
    # Check if we can access docker without sudo
    if docker ps &> /dev/null; then
        return 0  # Docker access OK
    else
        return 1  # Docker access denied
    fi
}

fix_docker_permission() {
    print_warning "Docker permission issue detected"
    print_info "User is in docker group but needs to activate it"
    echo ""
    print_info "🔄 Auto-fixing: Activating docker group..."
    echo ""
    sleep 2

    # Save current directory and script path
    local current_dir="$(pwd)"
    local script_path="$(readlink -f "$0" 2>/dev/null || echo "$0")"

    # Use sg to switch to docker group and re-execute
    cd "$current_dir"
    exec sg docker -c "'$script_path'"
}

################################################################################
# Installation Functions
################################################################################

install_dependencies() {
    print_header "Installing System Dependencies"

    print_info "Updating package lists..."
    sudo apt-get update -qq

    print_info "Installing basic utilities..."
    sudo apt-get install -y -qq \
        curl \
        wget \
        git \
        jq \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https

    print_success "System dependencies installed"
}

install_docker() {
    print_header "Installing Docker"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
        print_warning "Docker already installed (version $DOCKER_VERSION)"

        # Check if user is in docker group
        if ! groups | grep -q docker; then
            print_info "Adding user to docker group..."
            sudo usermod -aG docker $USER
            print_warning "You need to log out and back in for docker group to take effect"
        fi

        return 0
    fi

    print_info "Installing Docker..."

    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker

    print_success "Docker installed successfully"

    # Check if we can access docker
    if ! check_docker_access; then
        print_warning "Docker group not yet active in current session"
        print_info "Will activate docker group automatically..."
    fi
}

install_python() {
    print_header "Installing Python & Dependencies"

    print_info "Installing Python packages..."

    # Install Python 3.12 (default on Ubuntu 24.04) or 3.11
    if command -v python3.12 &> /dev/null; then
        print_success "Python 3.12 detected"
        sudo apt-get install -y -qq python3.12-venv python3-pip 2>/dev/null || true
    elif command -v python3.11 &> /dev/null; then
        print_success "Python 3.11 detected"
        sudo apt-get install -y -qq python3.11-venv python3-pip 2>/dev/null || true
    else
        print_info "Installing Python 3.11..."
        sudo apt-get install -y -qq python3.11 python3.11-venv python3-pip
    fi

    # Also install python3-venv as fallback
    sudo apt-get install -y -qq python3-venv python3-pip 2>/dev/null || true

    print_success "Python and venv installed"
}

clone_repository() {
    print_header "Cloning Repository"

    # Remove existing directory if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "Directory $INSTALL_DIR already exists"
        if ask_yes_no "Remove and re-clone?"; then
            rm -rf "$INSTALL_DIR"
        else
            print_info "Using existing directory"
            cd "$INSTALL_DIR"
            git pull origin "$REPO_BRANCH" 2>/dev/null || true
            return 0
        fi
    fi

    print_info "Cloning repository..."
    git clone -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"

    cd "$INSTALL_DIR"

    print_success "Repository cloned to $INSTALL_DIR"
}

setup_environment() {
    print_header "Setting up Environment"

    cd "$INSTALL_DIR"

    # Check if .env exists
    if [[ -f .env ]]; then
        print_warning ".env file already exists"
        if ! ask_yes_no "Overwrite with new configuration?"; then
            print_info "Keeping existing .env file"
            return 0
        fi
    fi

    print_info "Creating .env file..."

    # Generate random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    N8N_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
    API_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
    N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)

    # Get user input
    echo ""

    # Auto-yes mode uses defaults
    if [[ $AUTO_YES -eq 1 ]]; then
        ADMIN_NUMBER="628123456789"
        SERVER_HOST="localhost"
        print_warning "Using default admin number: $ADMIN_NUMBER"
        print_warning "Using default hostname: $SERVER_HOST"
        print_info "You can change these later in .env file"
    else
        ask_input "Enter your admin WhatsApp number (e.g., 628123456789): " "" "ADMIN_NUMBER"
        ask_input "Enter your server hostname/IP (default: localhost): " "localhost" "SERVER_HOST"
    fi

    # Create .env file
    cat > .env <<EOF
# ==============================================================================
# Neonize Emergency Response - Environment Configuration
# ==============================================================================
# Generated: $(date)

# ----------------------------------------------------------------------------
# PostgreSQL Database
# ----------------------------------------------------------------------------
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# ----------------------------------------------------------------------------
# n8n Configuration
# ----------------------------------------------------------------------------
N8N_USER=admin
N8N_PASSWORD=$N8N_PASSWORD
N8N_HOST=$SERVER_HOST
N8N_WEBHOOK_URL=http://$SERVER_HOST:5678
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY

# ----------------------------------------------------------------------------
# Neonize Bridge
# ----------------------------------------------------------------------------
SESSION_NAME=emergency_bot
API_KEY=$API_KEY

# ----------------------------------------------------------------------------
# Grafana
# ----------------------------------------------------------------------------
GRAFANA_USER=admin
GRAFANA_PASSWORD=$N8N_PASSWORD

# ----------------------------------------------------------------------------
# Emergency Response Configuration
# ----------------------------------------------------------------------------
ADMIN_NUMBERS=$ADMIN_NUMBER

# Emergency keywords (comma separated)
EMERGENCY_KEYWORDS=banjir,gempa,kebakaran,longsor,tsunami,darurat,help,tolong

# ----------------------------------------------------------------------------
# Monitoring (Optional)
# ----------------------------------------------------------------------------
# SENTRY_DSN=
# PROMETHEUS_ENABLED=true
EOF

    print_success ".env file created"

    # Save credentials to a file
    cat > credentials.txt <<EOF
==============================================================================
NEONIZE EMERGENCY RESPONSE - CREDENTIALS
==============================================================================
Generated: $(date)

IMPORTANT: Save these credentials securely and delete this file!

PostgreSQL:
  Database: emergency_db
  User: emergency
  Password: $POSTGRES_PASSWORD

n8n:
  URL: http://$SERVER_HOST:5678
  Username: admin
  Password: $N8N_PASSWORD

Neonize API:
  URL: http://$SERVER_HOST:8000
  API Key: $API_KEY
  Docs: http://$SERVER_HOST:8000/docs

Grafana:
  URL: http://$SERVER_HOST:3000
  Username: admin
  Password: $N8N_PASSWORD

Admin WhatsApp: $ADMIN_NUMBER

==============================================================================
DELETE THIS FILE AFTER SAVING THE CREDENTIALS!
==============================================================================
EOF

    chmod 600 credentials.txt

    print_success "Credentials saved to credentials.txt"
    print_warning "SAVE credentials.txt SECURELY then delete it!"
}

install_python_packages() {
    print_header "Installing Python Packages"

    cd "$INSTALL_DIR"

    print_info "Creating Python virtual environment..."
    python3 -m venv venv

    print_info "Installing packages..."
    source venv/bin/activate
    pip install --quiet --upgrade pip
    pip install --quiet -r requirements-emergency.txt

    print_success "Python packages installed in virtual environment"
}

setup_docker_compose() {
    print_header "Setting up Docker Services"

    cd "$INSTALL_DIR"

    # Check docker access before running docker commands
    if ! check_docker_access; then
        fix_docker_permission "$@"
        return 1
    fi

    # Create sessions directory with correct permissions
    print_info "Creating sessions directory..."
    mkdir -p "$INSTALL_DIR/sessions"
    chmod 777 "$INSTALL_DIR/sessions"
    print_success "Sessions directory created"

    # Create logs directory
    print_info "Creating logs directory..."
    mkdir -p "$INSTALL_DIR/logs"
    chmod 777 "$INSTALL_DIR/logs"
    print_success "Logs directory created"

    print_info "Pulling Docker images..."
    docker compose -f docker-compose.emergency.yml pull

    print_success "Docker images ready"
}

start_services() {
    print_header "Starting Services"

    cd "$INSTALL_DIR"

    # Check docker access before running docker commands
    if ! check_docker_access; then
        fix_docker_permission "$@"
        return 1
    fi

    print_info "Starting Docker containers..."
    docker compose -f docker-compose.emergency.yml up -d

    print_info "Waiting for services to be ready..."
    sleep 10

    # Check service health
    print_info "Checking service status..."

    # Check PostgreSQL
    if docker compose -f docker-compose.emergency.yml ps | grep -q "emergency_postgres.*Up"; then
        print_success "PostgreSQL is running"
    else
        print_error "PostgreSQL failed to start"
        docker compose -f docker-compose.emergency.yml logs postgres
    fi

    # Check n8n
    if docker compose -f docker-compose.emergency.yml ps | grep -q "emergency_n8n.*Up"; then
        print_success "n8n is running"
    else
        print_warning "n8n may still be starting..."
    fi

    # Check Neonize Bridge
    if docker compose -f docker-compose.emergency.yml ps | grep -q "emergency_neonize.*Up"; then
        print_success "Neonize Bridge is running"
    else
        print_warning "Neonize Bridge may still be starting..."
    fi

    print_success "Services started"
}

display_qr_instructions() {
    print_header "WhatsApp Connection Setup"

    echo -e "${YELLOW}"
    echo "To connect your WhatsApp account, you need to scan a QR code."
    echo ""
    echo "Follow these steps:"
    echo ""
    echo "1. Wait 30 seconds for the bot to initialize..."
    echo ""
    echo "2. View the QR code by running:"
    echo "   ${GREEN}docker logs emergency_neonize -f${YELLOW}"
    echo ""
    echo "3. In WhatsApp on your phone:"
    echo "   - Open WhatsApp"
    echo "   - Tap menu (⋮) → Linked Devices"
    echo "   - Tap 'Link a Device'"
    echo "   - Scan the QR code from the terminal"
    echo ""
    echo "4. Press Ctrl+C to exit log view after scanning"
    echo -e "${NC}"

    # Skip interactive prompt in auto-yes mode
    if [[ $AUTO_YES -eq 1 ]]; then
        print_info "Auto-yes mode: Skipping QR code display"
        print_info "Run this command to see QR code: docker logs emergency_neonize -f"
        return 0
    fi

    read -p "Press Enter to view QR code logs..." -r
    echo ""

    print_info "Showing QR code logs (press Ctrl+C to exit)..."
    sleep 2
    docker logs emergency_neonize -f --tail 50 || true
}

display_final_info() {
    print_header "Installation Complete!"

    echo -e "${GREEN}"
    echo "Neonize Emergency Response Chatbot has been installed successfully!"
    echo -e "${NC}"
    echo ""
    echo "📁 Installation Directory: ${BLUE}$INSTALL_DIR${NC}"
    echo ""
    echo "🌐 Service URLs:"
    echo "   • API Docs:  ${BLUE}http://$(hostname -I | awk '{print $1}'):8000/docs${NC}"
    echo "   • n8n:       ${BLUE}http://$(hostname -I | awk '{print $1}'):5678${NC}"
    echo "   • Grafana:   ${BLUE}http://$(hostname -I | awk '{print $1}'):3000${NC}"
    echo ""
    echo "🔑 Credentials saved in: ${YELLOW}$INSTALL_DIR/credentials.txt${NC}"
    echo "   ${RED}SAVE IT SECURELY THEN DELETE IT!${NC}"
    echo ""
    echo "📖 Documentation:"
    echo "   • Analysis:         $INSTALL_DIR/ANALISIS_CHATBOT_KEBENCANAAN.md"
    echo "   • Deployment:       $INSTALL_DIR/DEPLOYMENT_GUIDE.md"
    echo "   • Session Fixes:    $INSTALL_DIR/SESSION_PERSISTENCE_FIX.md"
    echo "   • Event Fixes:      $INSTALL_DIR/EVENT_HANDLER_FIX.md"
    echo "   • Message Fixes:    $INSTALL_DIR/MESSAGE_HANDLER_FIXES.md"
    echo ""
    echo "✅ Verified Fixes Applied:"
    echo "   • Docker bind mount (sessions persist to host)"
    echo "   • Database path (stored in sessions/ directory)"
    echo "   • Event handlers (proper registration)"
    echo "   • Message handling (PushName & JSON safe)"
    echo ""
    echo "🔧 Useful Commands:"
    echo ""
    echo "   Check health status:"
    echo "   ${BLUE}curl http://localhost:8000/health | python3 -m json.tool${NC}"
    echo ""
    echo "   View logs:"
    echo "   ${BLUE}cd $INSTALL_DIR${NC}"
    echo "   ${BLUE}docker compose -f docker-compose.emergency.yml logs -f${NC}"
    echo ""
    echo "   Check sessions directory:"
    echo "   ${BLUE}ls -la $INSTALL_DIR/sessions/${NC}"
    echo "   ${YELLOW}(Should show .db files after QR scan)${NC}"
    echo ""
    echo "   Run diagnostics:"
    echo "   ${BLUE}cd $INSTALL_DIR${NC}"
    echo "   ${BLUE}./diagnose.sh${NC}"
    echo ""
    echo "   Check status:"
    echo "   ${BLUE}docker compose -f docker-compose.emergency.yml ps${NC}"
    echo ""
    echo "   Restart services:"
    echo "   ${BLUE}docker compose -f docker-compose.emergency.yml restart${NC}"
    echo ""
    echo "   Stop services:"
    echo "   ${BLUE}docker compose -f docker-compose.emergency.yml down${NC}"
    echo ""
    echo "   View QR code again:"
    echo "   ${BLUE}docker logs emergency_neonize -f${NC}"
    echo ""
    echo "⚠️  Expected Warnings (Normal):"
    echo "   • 'n8n webhook returned 404' - Workflow not configured yet"
    echo "   • 'Got 515 code, reconnecting' - Normal WhatsApp reconnection"
    echo ""
    echo "✅ Test the bot by sending a message to the connected WhatsApp number:"
    echo "   ${YELLOW}\"Ada banjir di daerah saya\"${NC}"
    echo ""
    echo -e "${GREEN}Happy coding! 🚀${NC}"
    echo ""
}

create_systemd_service() {
    print_header "Creating Systemd Service (Optional)"

    if ! ask_yes_no "Do you want to auto-start services on boot?"; then
        print_info "Skipping systemd service creation"
        return 0
    fi

    print_info "Creating systemd service..."

    sudo tee /etc/systemd/system/neonize-emergency.service > /dev/null <<EOF
[Unit]
Description=Neonize Emergency Response Chatbot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose -f docker-compose.emergency.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.emergency.yml down
User=$USER

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable neonize-emergency.service

    print_success "Systemd service created and enabled"
    print_info "Services will auto-start on boot"
}

setup_firewall() {
    print_header "Firewall Configuration (Optional)"

    if ! command -v ufw &> /dev/null; then
        print_info "UFW not installed, skipping firewall setup"
        return 0
    fi

    if ! ask_yes_no "Do you want to configure UFW firewall?"; then
        print_info "Skipping firewall configuration"
        return 0
    fi

    print_info "Configuring UFW..."

    # Enable UFW if not already enabled
    sudo ufw --force enable

    # Allow SSH
    sudo ufw allow ssh

    # Allow service ports
    sudo ufw allow 8000/tcp comment 'Neonize API'
    sudo ufw allow 5678/tcp comment 'n8n'
    sudo ufw allow 3000/tcp comment 'Grafana'

    print_success "Firewall configured"
    print_info "Allowed ports: 22 (SSH), 8000 (API), 5678 (n8n), 3000 (Grafana)"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    clear

    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║   Neonize Emergency Response Chatbot                     ║
    ║   Installation Script for Ubuntu 24.04                   ║
    ║                                                           ║
    ║   This will install:                                     ║
    ║   • Docker & Docker Compose                              ║
    ║   • Python 3.11+ & dependencies                          ║
    ║   • PostgreSQL, n8n, Grafana                            ║
    ║   • Neonize WhatsApp Bot                                ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
EOF

    echo ""
    print_warning "This script will install system packages and Docker."
    print_info "Installation directory: $INSTALL_DIR"
    echo ""

    if ! ask_yes_no "Continue with installation?"; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Pre-flight checks
    check_root
    check_ubuntu
    check_internet

    # Installation steps
    install_dependencies
    install_docker
    install_python
    clone_repository
    setup_environment
    install_python_packages
    setup_docker_compose
    start_services

    # Optional steps
    create_systemd_service
    setup_firewall

    # Final steps
    display_qr_instructions
    display_final_info

    # Cleanup
    print_info "Installation script completed"
}

################################################################################
# Error Handling
################################################################################

trap 'print_error "Installation failed at line $LINENO. Check the error above."; exit 1' ERR

################################################################################
# Run Main
################################################################################

main "$@"
