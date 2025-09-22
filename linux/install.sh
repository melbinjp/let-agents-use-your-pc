#!/bin/bash

# jules-endpoint-agent: install.sh (SSH Edition)
#
# This script automates the setup of the Jules Endpoint Agent.
# It installs openssh-server and cloudflared, configures them to work
# together, and creates a secure SSH endpoint accessible via a public URL.

# --- Configuration ---
set -euo pipefail

# --- Constants ---
AGENT_USER="jules"
CLOUDFLARED_CONFIG_DIR="/etc/cloudflared"
CLOUDFLARED_CONFIG_FILE="$CLOUDFLARED_CONFIG_DIR/config.yml"

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script ---

# 1. Welcome and Pre-flight Checks
info "Welcome to the Jules Endpoint Agent installer (SSH Edition)."
info "This script will set up your machine as a remote SSH endpoint."
warn "Please review the security warnings in the README.md before proceeding."
echo

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo or as root. Please run as: sudo $0"
fi

# Check for dependencies
if ! command -v curl &> /dev/null; then
    error "'curl' is required. Please install it and re-run this script."
fi

# 2. Gather User Input for SSH Key
info "I need the public SSH key for the AI agent that will connect to this endpoint."
warn "The key should be a single line (e.g., 'ssh-rsa AAAA...')."
read -p "Paste the agent's public SSH key: " JULES_SSH_PUBLIC_KEY
if [[ -z "$JULES_SSH_PUBLIC_KEY" ]]; then
    error "The SSH public key cannot be empty."
fi

# 3. Install Dependencies (openssh-server and cloudflared)

info "Updating package lists..."
apt-get update

info "Installing openssh-server..."
apt-get install -y openssh-server
systemctl enable ssh
systemctl start ssh

info "openssh-server installed and enabled."

# Download and install cloudflared
info "Downloading and installing cloudflared..."
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac
CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-$OS-$ARCH"
curl -sL -o /usr/local/bin/cloudflared "$CF_URL"
chmod +x /usr/local/bin/cloudflared
info "cloudflared installed successfully."

# 4. Create and Configure Agent User
info "Creating a dedicated user for the agent: '$AGENT_USER'"
if id "$AGENT_USER" &>/dev/null; then
    warn "User '$AGENT_USER' already exists. Skipping user creation."
else
    useradd -m -s /bin/bash "$AGENT_USER"
    info "User '$AGENT_USER' created."
fi

info "Configuring SSH access for '$AGENT_USER'..."
AGENT_HOME=$(eval echo ~$AGENT_USER)
SSH_DIR="$AGENT_HOME/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
echo "$JULES_SSH_PUBLIC_KEY" > "$AUTH_KEYS_FILE"

chown -R "$AGENT_USER:$AGENT_USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTH_KEYS_FILE"

info "SSH key added and permissions set."

# 5. Configure and Install Cloudflare Tunnel
info "--- Cloudflare Tunnel Setup ---"
info "You will now be asked to log in to your Cloudflare account."
info "A browser window may open. Please authorize the tunnel."
read -p "Press Enter to continue..."

cloudflared tunnel login

TUNNEL_NAME="jules-ssh-endpoint-$(openssl rand -hex 4)"
info "Creating a new tunnel named: $TUNNEL_NAME"

# Create the tunnel and capture the UUID
TUNNEL_UUID=$(cloudflared tunnel create "$TUNNEL_NAME" 2>/dev/null) || error "Failed to create Cloudflare tunnel. Please check your Cloudflare account and try again."
info "Tunnel '$TUNNEL_NAME' with UUID $TUNNEL_UUID created."

info "Configuring the tunnel to point to the local SSH service..."
mkdir -p "$CLOUDFLARED_CONFIG_DIR"
cat > "$CLOUDFLARED_CONFIG_FILE" << EOF
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: "*"
    service: ssh://localhost:22
  - service: http_status:404
EOF

info "Installing cloudflared as a service..."
cloudflared service install
systemctl start cloudflared
info "cloudflared service started."

# 6. Final Instructions
TUNNEL_HOSTNAME=$(cloudflared tunnel info $TUNNEL_NAME | grep -o 'https://[^ ]*' | sed 's/https:\/\///')
info "--- SETUP COMPLETE ---"
echo
info "Your Jules Endpoint Agent is now running!"
info "  Agent User: $AGENT_USER"
warn "  Your public SSH endpoint is: $TUNNEL_HOSTNAME"
info "Provide this hostname to your AI agent. It should connect using the following command:"
info "  ssh $AGENT_USER@$TUNNEL_HOSTNAME"
info "The agent must use the private key corresponding to the public key you provided."
