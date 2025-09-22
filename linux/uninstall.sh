#!/bin/bash

# jules-endpoint-agent: uninstall.sh
#
# This script completely removes the Jules Endpoint Agent and its configurations.

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
info "Welcome to the Jules Endpoint Agent uninstaller."
warn "This script will permanently remove the agent and its configurations."
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Uninstallation cancelled."
    exit 0
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo or as root. Please run as: sudo $0"
fi

# 2. Stop and Disable Services
info "Stopping and disabling cloudflared service..."
if systemctl is-active --quiet cloudflared; then
    systemctl stop cloudflared
fi
if systemctl is-enabled --quiet cloudflared; then
    systemctl disable cloudflared
fi
# Remove the service file if it exists
rm -f /etc/systemd/system/cloudflared.service
systemctl daemon-reload
info "cloudflared service stopped and disabled."

# 3. Delete Cloudflare Tunnel and Configuration
if [ -f "$CLOUDFLARED_CONFIG_FILE" ]; then
    info "Reading tunnel configuration from $CLOUDFLARED_CONFIG_FILE..."
    TUNNEL_UUID=$(grep -oP 'tunnel: \K\w+-\w+-\w+-\w+-\w+' "$CLOUDFLARED_CONFIG_FILE" || true)

    if [ -n "$TUNNEL_UUID" ]; then
        info "Deleting Cloudflare tunnel with UUID: $TUNNEL_UUID"
        # The user must be logged in to cloudflared for this to work.
        if ! cloudflared tunnel delete "$TUNNEL_UUID"; then
            warn "Failed to delete tunnel. You may need to run 'cloudflared tunnel login' first, or delete it manually from the Cloudflare dashboard."
        else
            info "Tunnel deleted successfully."
        fi
    else
        warn "Could not find a tunnel UUID in the config file."
    fi

    info "Removing cloudflared configuration directory..."
    rm -rf "$CLOUDFLARED_CONFIG_DIR"
else
    warn "cloudflared config file not found. Skipping tunnel deletion."
fi

# 4. Delete Agent User
info "Deleting agent user: '$AGENT_USER'"
if id "$AGENT_USER" &>/dev/null; then
    # kill all processes running by the user before deleting
    pkill -u "$AGENT_USER" || true
    userdel -r "$AGENT_USER"
    info "User '$AGENT_USER' and their home directory have been deleted."
else
    warn "User '$AGENT_USER' not found. Skipping deletion."
fi

# 5. Remove Binaries
info "Removing installed binaries..."
rm -f /usr/local/bin/cloudflared
# Also remove shell2http in case this is an old installation
rm -f /usr/local/bin/shell2http

# 6. Remove old service files (for cleanup from previous versions)
rm -f /etc/systemd/system/jules-endpoint.service
systemctl daemon-reload

info "--- UNINSTALLATION COMPLETE ---"
info "The Jules Endpoint Agent has been removed from your system."
