#!/bin/bash

# AI Agent Remote Hardware Access - Interactive Setup
# This script guides you through setting up secure remote access for AI agents

set -e

SKIP_CLOUDFLARE=false
SHOW_HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cloudflare)
            SKIP_CLOUDFLARE=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    cat << 'EOF'
AI Agent Remote Hardware Access Setup

This script will guide you through:
1. Generating SSH keys for your AI agent
2. Setting up Cloudflare tunnel configuration
3. Starting the secure tunnel
4. Providing connection details for your AI agent

Usage:
  ./setup.sh                    # Full interactive setup
  ./setup.sh --skip-cloudflare  # Skip Cloudflare setup (if already configured)
  ./setup.sh --help             # Show this help

Requirements:
- Docker installed and running
- Cloudflare account (free tier works)
- Internet connection

EOF
    exit 0
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}🤖 AI Agent Remote Hardware Access Setup${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✅ Docker found: $DOCKER_VERSION${NC}"
else
    echo -e "${RED}❌ Docker is required but not found. Please install Docker.${NC}"
    echo -e "${YELLOW}   Visit: https://docs.docker.com/get-docker/${NC}"
    exit 1
fi

# Check if Docker is running
if docker ps &> /dev/null; then
    echo -e "${GREEN}✅ Docker is running${NC}"
else
    echo -e "${RED}❌ Docker is not running. Please start Docker.${NC}"
    exit 1
fi

echo ""

# Step 1: Generate SSH Keys
echo -e "${CYAN}🔐 Step 1: Generating SSH Keys for AI Agent${NC}"
echo -e "${CYAN}============================================${NC}"

read -p "Enter your AI agent name (e.g., 'jules', 'claude', 'gpt'): " AGENT_NAME
if [ -z "$AGENT_NAME" ]; then
    AGENT_NAME="ai-agent"
fi

KEY_FILE="${AGENT_NAME}_key"

if [ -f "$KEY_FILE" ]; then
    read -p "SSH key '$KEY_FILE' already exists. Overwrite? (y/N): " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
        rm -f "$KEY_FILE" "${KEY_FILE}.pub"
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "${AGENT_NAME}@remote-access"
    else
        echo -e "${YELLOW}Using existing SSH key.${NC}"
    fi
else
    echo -e "${YELLOW}Generating new SSH key pair...${NC}"
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "${AGENT_NAME}@remote-access"
fi

if [ -f "${KEY_FILE}.pub" ]; then
    PUBLIC_KEY=$(cat "${KEY_FILE}.pub")
    echo -e "${GREEN}✅ SSH keys generated successfully!${NC}"
    echo -e "${GRAY}   Public key: ${KEY_FILE}.pub${NC}"
    echo -e "${GRAY}   Private key: ${KEY_FILE} (keep this secure!)${NC}"
else
    echo -e "${RED}❌ Failed to generate SSH keys${NC}"
    exit 1
fi

echo ""

# Step 2: Cloudflare Setup
if [ "$SKIP_CLOUDFLARE" = false ]; then
    echo -e "${CYAN}☁️  Step 2: Cloudflare Tunnel Setup${NC}"
    echo -e "${CYAN}===================================${NC}"
    echo ""
    echo -e "${WHITE}To create a secure tunnel, you need a Cloudflare tunnel token.${NC}"
    echo ""
    echo -e "${YELLOW}📝 Follow these steps:${NC}"
    echo -e "${GRAY}   1. Go to: https://one.dash.cloudflare.com/${NC}"
    echo -e "${GRAY}   2. Sign in (or create free account)${NC}"
    echo -e "${GRAY}   3. Navigate to: Networks → Tunnels${NC}"
    echo -e "${GRAY}   4. Click 'Create a tunnel'${NC}"
    echo -e "${GRAY}   5. Choose 'Cloudflared'${NC}"
    echo -e "${GRAY}   6. Name it: '${AGENT_NAME}-hardware-access'${NC}"
    echo -e "${GRAY}   7. Copy the token (starts with 'eyJ...')${NC}"
    echo ""
    
    read -p "Paste your Cloudflare tunnel token here: " TOKEN
    
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}❌ Token is required. Run the script again when you have it.${NC}"
        exit 1
    fi
    
    if [[ ! "$TOKEN" =~ ^eyJ ]]; then
        echo -e "${YELLOW}⚠️  Warning: Token doesn't look correct (should start with 'eyJ')${NC}"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}⏭️  Skipping Cloudflare setup (using existing configuration)${NC}"
    if [ -f ".env" ]; then
        if grep -q "CLOUDFLARE_TOKEN=" ".env"; then
            TOKEN=$(grep "CLOUDFLARE_TOKEN=" ".env" | cut -d'=' -f2)
            if [ "$TOKEN" = "YOUR_CLOUDFLARE_TOKEN_HERE" ]; then
                echo -e "${RED}❌ No valid Cloudflare token found in .env file${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ No Cloudflare token found in .env file${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ No .env file found${NC}"
        exit 1
    fi
fi

echo ""

# Step 3: Update Configuration
echo -e "${CYAN}⚙️  Step 3: Updating Configuration${NC}"
echo -e "${CYAN}==================================${NC}"

# Update .env file
cat > .env << EOF
# AI Agent Remote Hardware Access Configuration
# Generated on $(date)

# Cloudflare tunnel token
CLOUDFLARE_TOKEN=$TOKEN

# AI Agent SSH public key
JULES_SSH_PUBLIC_KEY=$PUBLIC_KEY

# SSH configuration
SSH_PORT=22
JULES_USERNAME=$AGENT_NAME
EOF

echo -e "${GREEN}✅ Configuration updated in .env file${NC}"

echo ""

# Step 4: Start the Tunnel
echo -e "${CYAN}🚀 Step 4: Starting Secure Tunnel${NC}"
echo -e "${CYAN}==================================${NC}"

echo -e "${YELLOW}Building and starting the secure tunnel...${NC}"

# Stop any existing container
docker-compose -f docker/docker-compose.yml down 2>/dev/null || true

# Start the tunnel
if docker-compose -f docker/docker-compose.yml up -d --build; then
    echo -e "${GREEN}✅ Tunnel started successfully!${NC}"
else
    echo -e "${RED}❌ Failed to start tunnel. Check Docker logs:${NC}"
    echo -e "${GRAY}   docker-compose -f docker/docker-compose.yml logs${NC}"
    exit 1
fi

# Wait for tunnel to establish
echo -e "${YELLOW}⏳ Waiting for tunnel to establish connection...${NC}"
sleep 10

echo ""

# Step 5: Get Connection Information
echo -e "${CYAN}🔗 Step 5: Connection Information for AI Agent${NC}"
echo -e "${CYAN}===============================================${NC}"

echo -e "${YELLOW}Retrieving connection details...${NC}"
if CONNECTION_INFO=$(docker exec jules-agent /app/connection-info.sh 2>/dev/null); then
    echo "$CONNECTION_INFO"
else
    echo -e "${YELLOW}⚠️  Could not retrieve connection info automatically. Tunnel may still be connecting.${NC}"
    echo -e "${GRAY}   Try running this command in a few minutes:${NC}"
    echo -e "${GRAY}   docker exec jules-agent /app/connection-info.sh${NC}"
fi

echo ""

# Step 6: AI Agent Instructions
echo -e "${CYAN}🤖 Step 6: Instructions for Your AI Agent${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

echo -e "${WHITE}📋 Provide these details to your AI agent:${NC}"
echo ""

echo -e "${YELLOW}🔑 Private SSH Key:${NC}"
echo -e "${GRAY}-------------------${NC}"
if [ -f "$KEY_FILE" ]; then
    cat "$KEY_FILE"
else
    echo -e "${RED}❌ Private key file not found: $KEY_FILE${NC}"
fi

echo ""
echo -e "${YELLOW}💬 Instructions for AI Agent:${NC}"
echo -e "${GRAY}------------------------------${NC}"
cat << EOF
To connect to your hardware remotely:

1. Save the private key above to a file (e.g., 'remote_key')
2. Set proper permissions: chmod 600 remote_key
3. Get the current tunnel hostname by running:
   docker exec jules-agent /app/connection-info.sh --hostname-only
4. Connect using: ssh -i remote_key $AGENT_NAME@[tunnel-hostname]

You will have full sudo access to the system and can:
- Access GPU and hardware resources
- Install software packages
- Run development tools
- Access files and directories
EOF

echo ""

# Step 7: Management Commands
echo -e "${CYAN}🛠️  Step 7: Management Commands${NC}"
echo -e "${CYAN}===============================${NC}"
echo ""

echo -e "${WHITE}📝 Useful commands:${NC}"
echo ""
echo -e "${YELLOW}Get connection info:${NC}"
echo -e "${GRAY}  docker exec jules-agent /app/connection-info.sh${NC}"
echo ""
echo -e "${YELLOW}Check tunnel status:${NC}"
echo -e "${GRAY}  docker-compose -f docker/docker-compose.yml ps${NC}"
echo ""
echo -e "${YELLOW}View tunnel logs:${NC}"
echo -e "${GRAY}  docker-compose -f docker/docker-compose.yml logs -f${NC}"
echo ""
echo -e "${YELLOW}Stop tunnel:${NC}"
echo -e "${GRAY}  docker-compose -f docker/docker-compose.yml down${NC}"
echo ""
echo -e "${YELLOW}Restart tunnel:${NC}"
echo -e "${GRAY}  docker-compose -f docker/docker-compose.yml restart${NC}"
echo ""

echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo -e "${GREEN}==================${NC}"
echo ""
echo -e "${WHITE}Your AI agent can now securely access your hardware remotely!${NC}"
echo -e "${GRAY}The tunnel will automatically restart if your system reboots.${NC}"
echo ""
echo -e "${GRAY}For troubleshooting, see: TROUBLESHOOTING.md${NC}"