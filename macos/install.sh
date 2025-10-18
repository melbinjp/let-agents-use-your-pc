#!/bin/bash

# jules-endpoint-agent: install.sh (SSH Edition)
#
# This script automates the setup of the Jules Endpoint Agent on macOS.
# It configures SSH server and cloudflared to create a secure SSH endpoint
# accessible via a public URL.

# --- Configuration ---
set -euo pipefail

# --- Constants ---
AGENT_USER="jules"
CLOUDFLARED_CONFIG_DIR="/usr/local/etc/cloudflared"
CLOUDFLARED_CONFIG_FILE="$CLOUDFLARED_CONFIG_DIR/config.yml"
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
INSTALL_LOG="/tmp/jules-endpoint-install.log"

# --- Helper Functions ---
info() {
    echo "[INFO] $1" | tee -a "$INSTALL_LOG"
}

warn() {
    echo "[WARN] $1" | tee -a "$INSTALL_LOG" >&2
}

error() {
    echo "[ERROR] $1" | tee -a "$INSTALL_LOG" >&2
    cleanup_on_failure
    exit 1
}

success() {
    echo "[SUCCESS] $1" | tee -a "$INSTALL_LOG"
}

# Cleanup function for failed installations
cleanup_on_failure() {
    warn "Installation failed. Performing cleanup..."
    
    # Stop services if they were started
    if launchctl list | grep -q "com.cloudflare.cloudflared" 2>/dev/null; then
        launchctl stop com.cloudflare.cloudflared || true
        launchctl unload /Library/LaunchDaemons/com.cloudflare.cloudflared.plist || true
    fi
    
    # Remove agent user if created during this installation
    if id "$AGENT_USER" &>/dev/null && [ -f "/tmp/jules-user-created" ]; then
        dscl . -delete "/Users/$AGENT_USER" 2>/dev/null || true
        rm -f "/tmp/jules-user-created"
    fi
    
    # Remove cloudflared config if created
    if [ -f "$CLOUDFLARED_CONFIG_FILE" ]; then
        rm -f "$CLOUDFLARED_CONFIG_FILE" || true
    fi
    
    warn "Cleanup completed. Check $INSTALL_LOG for details."
}

# Function to validate SSH key format
validate_ssh_key() {
    local key="$1"
    
    # Check if key is not empty
    if [[ -z "$key" ]]; then
        error "SSH public key cannot be empty"
    fi
    
    # Check if key starts with valid key type
    if ! echo "$key" | grep -qE '^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '; then
        error "Invalid SSH key format. Key must start with a valid key type (ssh-rsa, ssh-ed25519, etc.)"
    fi
    
    # Check if key has at least 2 parts (type and key data)
    local key_parts
    key_parts=$(echo "$key" | wc -w)
    if [ "$key_parts" -lt 2 ]; then
        error "Invalid SSH key format. Key must have at least key type and key data"
    fi
    
    # Try to validate key format using ssh-keygen if available
    if command -v ssh-keygen &> /dev/null; then
        if ! echo "$key" | ssh-keygen -l -f - &>/dev/null; then
            error "SSH key validation failed. Please ensure the key is in correct format"
        fi
    fi
    
    success "SSH key format validation passed"
}

# Function to check system requirements
check_system_requirements() {
    info "Checking system requirements..."
    
    # Check macOS version
    local macos_version
    macos_version=$(sw_vers -productVersion)
    local major_version
    major_version=$(echo "$macos_version" | cut -d. -f1)
    
    if [ "$major_version" -lt 10 ]; then
        error "This script requires macOS 10.15 (Catalina) or later. Current version: $macos_version"
    fi
    
    info "Detected macOS version: $macos_version"
    
    # Check for required commands
    local required_commands=("curl" "launchctl" "dscl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found"
        fi
    done
    
    # Check available disk space (need at least 100MB)
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 102400 ]; then
        error "Insufficient disk space. At least 100MB free space required"
    fi
    
    success "System requirements check passed"
}

# Function to install Homebrew if not present
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for current session
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            # Apple Silicon Mac
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            # Intel Mac
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        success "Homebrew installed successfully"
    else
        info "Homebrew is already installed"
    fi
}

# --- Main Script ---

# Handle uninstall flag
if [[ "${1:-}" == "--uninstall" ]]; then
    info "Starting Jules Endpoint Agent uninstallation..."
    
    # Stop and remove cloudflared service
    if launchctl list | grep -q "com.cloudflare.cloudflared" 2>/dev/null; then
        info "Stopping cloudflared service..."
        launchctl stop com.cloudflare.cloudflared || true
        launchctl unload /Library/LaunchDaemons/com.cloudflare.cloudflared.plist || true
        rm -f /Library/LaunchDaemons/com.cloudflare.cloudflared.plist || true
    fi
    
    # Disable Remote Login if we enabled it
    info "Note: Remote Login (SSH) was left enabled. Disable manually in System Preferences if not needed."
    
    # Remove jules user
    if id "$AGENT_USER" &>/dev/null; then
        info "Removing user '$AGENT_USER'..."
        dscl . -delete "/Users/$AGENT_USER" || true
    fi
    
    # Remove cloudflared configuration
    if [ -d "$CLOUDFLARED_CONFIG_DIR" ]; then
        info "Removing cloudflared configuration..."
        rm -rf "$CLOUDFLARED_CONFIG_DIR" || true
    fi
    
    # Restore SSH configuration backup if exists
    if [ -f "$SSHD_CONFIG_FILE.backup" ]; then
        info "Restoring SSH configuration backup..."
        cp "$SSHD_CONFIG_FILE.backup" "$SSHD_CONFIG_FILE"
        rm -f "$SSHD_CONFIG_FILE.backup"
    fi
    
    success "Jules Endpoint Agent uninstalled successfully!"
    exit 0
fi

# Initialize installation log
echo "Jules Endpoint Agent Installation Log - $(date)" > "$INSTALL_LOG"

# 1. Welcome and Pre-flight Checks
info "Welcome to the Jules Endpoint Agent installer for macOS (SSH Edition)."
info "This script will set up your machine as a remote SSH endpoint."
warn "Please review the security warnings in the README.md before proceeding."
warn "This will give the AI agent full sudo access to your system."
echo

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo or as root. Please run as: sudo $0"
fi

# Perform system requirements check
check_system_requirements

# 2. Gather User Input for SSH Key
info "I need the public SSH key for the AI agent that will connect to this endpoint."
warn "The key should be a single line (e.g., 'ssh-rsa AAAA...' or 'ssh-ed25519 AAAA...')."
echo "Example: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... user@host"
echo

# Allow multiple attempts for SSH key input
local attempts=0
local max_attempts=3
while [ $attempts -lt $max_attempts ]; do
    read -p "Paste the agent's public SSH key: " JULES_SSH_PUBLIC_KEY
    
    if [[ -n "$JULES_SSH_PUBLIC_KEY" ]]; then
        if validate_ssh_key "$JULES_SSH_PUBLIC_KEY"; then
            break
        fi
    else
        warn "SSH public key cannot be empty."
    fi
    
    attempts=$((attempts + 1))
    if [ $attempts -lt $max_attempts ]; then
        warn "Invalid SSH key format. Please try again ($((max_attempts - attempts)) attempts remaining)."
    else
        error "Maximum attempts reached. Please ensure you have a valid SSH public key and re-run the script."
    fi
done

# 3. Enable and Configure SSH Server
info "Configuring SSH server (Remote Login)..."

# Enable Remote Login (SSH server) on macOS
info "Enabling Remote Login..."
systemsetup -setremotelogin on

# Backup original SSH configuration
if [ ! -f "$SSHD_CONFIG_FILE.backup" ]; then
    cp "$SSHD_CONFIG_FILE" "$SSHD_CONFIG_FILE.backup"
    info "Created backup of SSH configuration"
fi

# Apply secure SSH configuration
cat >> "$SSHD_CONFIG_FILE" << 'EOF'

# Jules Endpoint Agent SSH Configuration
# Added by jules-endpoint-agent installer
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
Subsystem sftp /usr/libexec/sftp-server
EOF

# Restart SSH service to apply configuration
info "Restarting SSH service..."
launchctl stop com.openssh.sshd
launchctl start com.openssh.sshd

success "SSH server configured and restarted successfully"

# 4. Install cloudflared via Homebrew
info "Installing cloudflared..."

# Install Homebrew if not present
install_homebrew

# Install cloudflared
if ! command -v cloudflared &> /dev/null; then
    info "Installing cloudflared via Homebrew..."
    brew install cloudflared
    success "cloudflared installed successfully"
else
    info "cloudflared is already installed"
fi

# 5. Create and Configure Agent User
info "Creating a dedicated user for the agent: '$AGENT_USER'"

# Check if user already exists
if id "$AGENT_USER" &>/dev/null; then
    warn "User '$AGENT_USER' already exists. Updating configuration..."
else
    # Create user using dscl
    local next_uid
    next_uid=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
    next_uid=$((next_uid + 1))
    
    # Ensure UID is in valid range (501-599 for regular users on macOS)
    if [ "$next_uid" -lt 501 ]; then
        next_uid=501
    fi
    
    dscl . -create "/Users/$AGENT_USER"
    dscl . -create "/Users/$AGENT_USER" UserShell /bin/bash
    dscl . -create "/Users/$AGENT_USER" RealName "Jules AI Agent"
    dscl . -create "/Users/$AGENT_USER" UniqueID "$next_uid"
    dscl . -create "/Users/$AGENT_USER" PrimaryGroupID 20
    dscl . -create "/Users/$AGENT_USER" NFSHomeDirectory "/Users/$AGENT_USER"
    
    # Create home directory
    mkdir -p "/Users/$AGENT_USER"
    chown "$AGENT_USER:staff" "/Users/$AGENT_USER"
    
    # Mark that we created the user for cleanup purposes
    touch "/tmp/jules-user-created"
    success "User '$AGENT_USER' created successfully"
fi

# Add user to admin group for sudo access
info "Adding '$AGENT_USER' to admin group for sudo access..."
dscl . -append /Groups/admin GroupMembership "$AGENT_USER"
success "User '$AGENT_USER' added to admin group"

# Configure SSH access for the agent user
info "Configuring SSH access for '$AGENT_USER'..."
AGENT_HOME="/Users/$AGENT_USER"
SSH_DIR="$AGENT_HOME/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"

# Create SSH directory with proper permissions
mkdir -p "$SSH_DIR"
chown "$AGENT_USER:staff" "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Add SSH public key
echo "$JULES_SSH_PUBLIC_KEY" > "$AUTH_KEYS_FILE"
chown "$AGENT_USER:staff" "$AUTH_KEYS_FILE"
chmod 600 "$AUTH_KEYS_FILE"

success "SSH key added and permissions set correctly"

# 6. Configure and Install Cloudflare Tunnel
info "--- Cloudflare Tunnel Setup ---"
info "You will now be asked to log in to your Cloudflare account."
info "A browser window will open. Please authorize the tunnel."
warn "If you don't have a Cloudflare account, create one at https://dash.cloudflare.com/sign-up"
echo
read -p "Press Enter to continue with Cloudflare authentication..."

# Authenticate with Cloudflare
info "Initiating Cloudflare authentication..."
if ! cloudflared tunnel login; then
    error "Failed to authenticate with Cloudflare. Please ensure you have a Cloudflare account and try again."
fi

success "Cloudflare authentication successful"

# Generate unique tunnel name
TUNNEL_NAME="jules-ssh-macos-$(openssl rand -hex 4)"
info "Creating a new tunnel named: $TUNNEL_NAME"

# Create the tunnel
info "Creating Cloudflare tunnel..."
TUNNEL_CREATE_OUTPUT=$(cloudflared tunnel create "$TUNNEL_NAME" 2>&1) || {
    error "Failed to create Cloudflare tunnel. Output: $TUNNEL_CREATE_OUTPUT"
}

# Extract tunnel UUID
TUNNEL_UUID=$(echo "$TUNNEL_CREATE_OUTPUT" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1)

if [[ -z "$TUNNEL_UUID" ]]; then
    error "Failed to extract tunnel UUID from creation output: $TUNNEL_CREATE_OUTPUT"
fi

success "Tunnel '$TUNNEL_NAME' created with UUID: $TUNNEL_UUID"

# Create cloudflared configuration
info "Configuring the tunnel to point to the local SSH service..."
mkdir -p "$CLOUDFLARED_CONFIG_DIR"

cat > "$CLOUDFLARED_CONFIG_FILE" << EOF
tunnel: $TUNNEL_UUID
credentials-file: /Users/$(whoami)/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: "*"
    service: ssh://localhost:22
  - service: http_status:404
EOF

success "Tunnel configuration created successfully"

# Install cloudflared as a launchd service
info "Installing cloudflared as a system service..."
if ! cloudflared service install; then
    error "Failed to install cloudflared service"
fi

info "Starting cloudflared service..."
launchctl start com.cloudflare.cloudflared

# Wait for service to start and verify
sleep 3
if ! launchctl list | grep -q "com.cloudflare.cloudflared"; then
    error "cloudflared service failed to start"
fi

success "cloudflared service installed and started successfully"

# 7. Generate Connection Information
info "Generating connection information..."

# Wait for tunnel to establish
info "Waiting for tunnel to establish connection..."
sleep 10

# Get connection information
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTION_INFO_SCRIPT="$SCRIPT_DIR/connection-info.sh"

if [ -f "$CONNECTION_INFO_SCRIPT" ]; then
    info "Using connection information generator..."
    if bash "$CONNECTION_INFO_SCRIPT"; then
        success "Connection information generated successfully"
    else
        warn "Connection info generator encountered issues, but installation may still be successful"
    fi
else
    # Fallback connection info
    warn "Connection info script not found. Generating basic connection information..."
    
    TUNNEL_HOSTNAME=""
    if command -v cloudflared &> /dev/null; then
        TUNNEL_HOSTNAME=$(cloudflared tunnel info "$TUNNEL_UUID" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
    fi
    
    if [ -n "$TUNNEL_HOSTNAME" ]; then
        success "--- INSTALLATION COMPLETE ---"
        echo
        success "Your Jules Endpoint Agent is now running on macOS!"
        info "  Agent User: $AGENT_USER"
        info "  Tunnel UUID: $TUNNEL_UUID"
        info "  Tunnel Name: $TUNNEL_NAME"
        success "  SSH Hostname: $TUNNEL_HOSTNAME"
        echo
        info "=== Copy-Pasteable Configuration for Jules ==="
        echo
        echo "Host jules-endpoint"
        echo "    HostName $TUNNEL_HOSTNAME"
        echo "    User $AGENT_USER"
        echo "    Port 22"
        echo "    IdentitiesOnly yes"
        echo "    StrictHostKeyChecking no"
        echo "    UserKnownHostsFile /dev/null"
        echo
        success "Quick Connect Command: ssh $AGENT_USER@$TUNNEL_HOSTNAME"
        echo
        info "=== End Configuration ==="
    else
        warn "Could not automatically determine tunnel hostname."
        info "You can get connection details by running:"
        info "  cloudflared tunnel info $TUNNEL_UUID"
    fi
fi

# Final status and instructions
echo
success "Installation completed successfully!"
info "Installation log saved to: $INSTALL_LOG"
echo
info "Service Status:"
info "  SSH Service (Remote Login): Enabled"
info "  Cloudflared Service: $(launchctl list | grep -q 'com.cloudflare.cloudflared' && echo 'Running' || echo 'Not Running')"
echo
info "To regenerate connection information at any time, run:"
info "  sudo bash $SCRIPT_DIR/connection-info.sh"
echo
info "To check service logs:"
info "  log show --predicate 'process == \"sshd\"' --last 1h"
info "  log show --predicate 'process == \"cloudflared\"' --last 1h"
echo
warn "Remember: The '$AGENT_USER' user has full sudo privileges for AI agent access."
echo
info "To uninstall, run: sudo $0 --uninstall"

# Clean up temporary files
rm -f "/tmp/jules-user-created" 2>/dev/null || true
