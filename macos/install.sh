#!/bin/bash

# jules-endpoint-agent: install.sh
#
# This script automates the setup of the Jules Endpoint Agent on macOS.
# It installs cloudflared and configures it to provide secure,
# remote SSH access via a Cloudflare Tunnel.

# --- Configuration ---
# Exit on any error, treat unset variables as errors, and fail pipelines on first error.
set -euo pipefail

# --- Constants ---
AGENT_CONFIG_DIR="/usr/local/etc/jules-endpoint-agent"
AGENT_RUNNER_SCRIPT="$AGENT_CONFIG_DIR/runner.sh"
# No credentials file needed for SSH key-based auth.

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

# TODO / HELP WANTED: Implement uninstallation logic.
# This script should accept an `--uninstall` flag that performs the following actions:
# - Stop and unload the 'com.cloudflare.cloudflared' launchd service.
# - Delete the launchd service file.
# - Delete the installation directory ('/usr/local/etc/jules-endpoint-agent').
# - Delete the '/usr/local/bin/cloudflared' binary.
# - Delete the Cloudflare tunnel.

# 1. Welcome and Pre-flight Checks
info "Welcome to the Jules Endpoint Agent installer for SSH."
info "This script will set up your machine as a remote execution endpoint."
warn "Please review the security warnings in the README.md before proceeding."
echo

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo or as root. Please run as: sudo $0"
fi

# Check for dependencies
if ! command -v curl &> /dev/null || ! command -v git &> /dev/null; then
    error "Both 'curl' and 'git' are required. Please install them and re-run this script."
fi

# Check for a running SSH server (Remote Login in System Settings)
if ! sudo systemsetup -getremotelogin | grep -q "On"; then
    error "Remote Login (SSH) is not enabled. Please enable it in System Settings > General > Sharing and re-run the script."
fi
info "Verified that Remote Login (SSH) is enabled."

# 2. Detect OS and Architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac

info "Detected OS: $OS, Architecture: $ARCH"

# 3. Download and Install Binaries

# Create temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT
cd "$TMP_DIR"

# Download and install cloudflared
info "Downloading cloudflared..."
CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-$OS-$ARCH"
curl -sL -o /usr/local/bin/cloudflared "$CF_URL"
chmod +x /usr/local/bin/cloudflared
info "cloudflared installed successfully."

# 4. Create Configuration Files and Runner Script

info "Creating configuration directory: $AGENT_CONFIG_DIR"
mkdir -p "$AGENT_CONFIG_DIR"

# Copy the runner.sh script from the common directory
info "Installing runner script to $AGENT_RUNNER_SCRIPT"
cp ../common/runner.sh "$AGENT_RUNNER_SCRIPT"
chmod +x "$AGENT_RUNNER_SCRIPT"

# 5. Configure Cloudflare Tunnel
info "--- Cloudflare Tunnel Setup ---"
info "You will now be asked to log in to your Cloudflare account."
info "A browser window will open. Please authorize the tunnel."
read -p "Press Enter to continue..."

cloudflared tunnel login

TUNNEL_NAME="jules-ssh-endpoint-$(openssl rand -hex 4)"
info "Creating a new tunnel named: $TUNNEL_NAME"
# The tunnel command may fail if the user already has a tunnel with that name.
# This is unlikely but we should handle it gracefully.
if ! cloudflared tunnel create "$TUNNEL_NAME"; then
    error "Failed to create Cloudflare tunnel. Please check your Cloudflare account and try again."
fi
TUNNEL_UUID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')

info "Configuring the tunnel to point to the local SSH service..."
# Note: On macOS, cloudflared configuration is typically stored in ~/Library/Application Support/cloudflared
# However, since we run as root, it will be in /var/root. For consistency with Linux, we use /etc/cloudflared
CF_CONFIG_DIR="/etc/cloudflared"
mkdir -p "$CF_CONFIG_DIR"
cat > "$CF_CONFIG_DIR/config.yml" << EOF
tunnel: $TUNNEL_UUID
credentials-file: $HOME/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: $TUNNEL_NAME.trycloudflare.com
    service: ssh://localhost:22
  - service: http_status:404
EOF

info "Installing cloudflared as a service..."
cloudflared service install
launchctl start com.cloudflare.cloudflared

info "--- SETUP COMPLETE ---"
echo
info "Your Jules Endpoint Agent is now running!"
warn "Your SSH endpoint is: ssh -p 22 <YOUR_USER>@$TUNNEL_NAME.trycloudflare.com"
info "To allow the agent to connect, you must add its public SSH key to your ~/.ssh/authorized_keys file."
info "The runner script is available at $AGENT_RUNNER_SCRIPT if you need to inspect it."
