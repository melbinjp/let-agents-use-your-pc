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

# Enhanced error handling and cleanup function
cleanup_on_failure() {
    warn "Installation failed. Performing cleanup..."
    set_error_context "operation" "cleanup"
    
    # Stop services if they were started
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        systemctl stop cloudflared || true
        systemctl disable cloudflared || true
        log_system_event "service_cleanup" "cloudflared" "stopped" "Stopped during cleanup"
    fi
    
    # Remove cloudflared service if installed
    if [ -f "/etc/systemd/system/cloudflared.service" ]; then
        cloudflared service uninstall || true
        log_system_event "service_cleanup" "cloudflared" "uninstalled" "Service uninstalled during cleanup"
    fi
    
    # Remove agent user if created during this installation
    if id "$AGENT_USER" &>/dev/null && [ -f "/tmp/jules-user-created" ]; then
        userdel -r "$AGENT_USER" 2>/dev/null || true
        rm -f "/tmp/jules-user-created"
        log_system_event "user_cleanup" "$AGENT_USER" "removed" "User removed during cleanup"
    fi
    
    # Remove cloudflared config if created
    if [ -f "$CLOUDFLARED_CONFIG_FILE" ]; then
        rm -f "$CLOUDFLARED_CONFIG_FILE" || true
        log_system_event "config_cleanup" "cloudflared" "removed" "Config removed during cleanup"
    fi
    
    warn "Cleanup completed. Check $INSTALL_LOG for details."
    
    # Generate troubleshooting report
    if command -v generate_troubleshooting_report &>/dev/null; then
        generate_troubleshooting_report $E_GENERAL "Installation failed during cleanup" "installer"
    fi
}

# Load security modules and diagnostics
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load enhanced error handling
if [[ -f "$PROJECT_ROOT/diagnostics/error-handler.sh" ]]; then
    source "$PROJECT_ROOT/diagnostics/error-handler.sh"
    set_error_context "component" "linux-installer"
fi

# Load security modules
if [[ -f "$SCRIPT_DIR/ssh-key-validator.sh" ]]; then
    source "$SCRIPT_DIR/ssh-key-validator.sh"
fi

# Function to validate SSH key format (enhanced version)
validate_ssh_key() {
    local key="$1"
    
    # Use enhanced validation if available
    if command -v validate_ssh_key_comprehensive &> /dev/null; then
        if validate_ssh_key_comprehensive "$key" 2048; then
            success "SSH key format validation passed (enhanced)"
            return 0
        else
            error "SSH key validation failed (enhanced)"
            return 1
        fi
    fi
    
    # Fallback to basic validation
    # Check if key is not empty
    if [[ -z "$key" ]]; then
        error "SSH public key cannot be empty"
    fi
    
    # Check if key starts with valid key type
    if ! echo "$key" | grep -qE '^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '; then
        error "Invalid SSH key format. Key must start with a valid key type (ssh-rsa, ssh-ed25519, etc.)"
    fi
    
    # Check if key has at least 3 parts (type, key, optional comment)
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
    
    # Check OS compatibility
    if [ ! -f /etc/os-release ]; then
        error "Cannot determine OS version. This script requires a Linux distribution with /etc/os-release"
    fi
    
    . /etc/os-release
    case "$ID" in
        ubuntu|debian)
            info "Detected compatible OS: $PRETTY_NAME"
            ;;
        *)
            warn "Detected OS: $PRETTY_NAME. This script is tested on Ubuntu/Debian but may work on other distributions"
            ;;
    esac
    
    # Check for required commands
    local required_commands=("curl" "systemctl" "useradd" "apt-get")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command '$cmd' not found. Please install it and re-run this script"
        fi
    done
    
    # Check available disk space (need at least 100MB)
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 102400 ]; then
        error "Insufficient disk space. At least 100MB free space required"
    fi
    
    # Check if running on supported architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|aarch64|arm64)
            info "Detected supported architecture: $arch"
            ;;
        *)
            error "Unsupported architecture: $arch. Supported: x86_64, aarch64, arm64"
            ;;
    esac
    
    success "System requirements check passed"
}

# --- Main Script ---

# Initialize installation log
echo "Jules Endpoint Agent Installation Log - $(date)" > "$INSTALL_LOG"

# 1. Welcome and Pre-flight Checks
info "Welcome to the Jules Endpoint Agent installer (SSH Edition)."
info "This script will set up your machine as a remote SSH endpoint."
warn "Please review the security warnings in the README.md before proceeding."
warn "This will give the AI agent full sudo access to your system."
echo

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    handle_error $E_PERMISSION "This script must be run with sudo or as root. Please run as: sudo $0" "installer" "privilege-check"
fi

# Perform comprehensive system requirements check
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
        # Validate the SSH key format
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

# 3. Install Dependencies (openssh-server and cloudflared)

info "Updating package lists..."
set_error_context "operation" "package-update"
if ! apt-get update; then
    handle_error $E_NETWORK "Failed to update package lists. Please check your internet connection and package manager configuration." "package-manager" "update"
fi

info "Installing openssh-server..."
if ! apt-get install -y openssh-server; then
    error "Failed to install openssh-server. Please check your package manager configuration."
fi

# Configure SSH server for security and compatibility
info "Configuring SSH server..."

# Load SSH security hardening module if available
if [[ -f "$SCRIPT_DIR/ssh-security-hardening.sh" ]]; then
    source "$SCRIPT_DIR/ssh-security-hardening.sh"
    info "Applying comprehensive SSH security hardening..."
    if apply_comprehensive_ssh_hardening; then
        success "SSH security hardening applied successfully"
    else
        warn "SSH security hardening encountered issues, falling back to basic configuration"
        # Fall back to basic configuration
        apply_basic_ssh_config
    fi
else
    warn "SSH security hardening module not found, applying basic configuration"
    apply_basic_ssh_config
fi

# Function for basic SSH configuration (fallback)
apply_basic_ssh_config() {
    if [ ! -f "$SSHD_CONFIG_FILE.backup" ]; then
        cp "$SSHD_CONFIG_FILE" "$SSHD_CONFIG_FILE.backup"
        info "Created backup of SSH configuration at $SSHD_CONFIG_FILE.backup"
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
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
}

# Enable and start SSH service
if ! systemctl enable ssh; then
    error "Failed to enable SSH service"
fi

if ! systemctl start ssh; then
    error "Failed to start SSH service"
fi

# Verify SSH service is running
if ! systemctl is-active --quiet ssh; then
    error "SSH service failed to start properly"
fi

success "SSH server installed, configured, and started successfully"

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
info "Downloading from: $CF_URL"

if ! curl -sL -o /usr/local/bin/cloudflared "$CF_URL"; then
    error "Failed to download cloudflared. Please check your internet connection."
fi

if ! chmod +x /usr/local/bin/cloudflared; then
    error "Failed to make cloudflared executable"
fi

# Verify cloudflared installation
if ! /usr/local/bin/cloudflared --version &>/dev/null; then
    error "cloudflared installation verification failed"
fi

success "cloudflared installed successfully"

# 4. Create and Configure Agent User
info "Creating a dedicated user for the agent: '$AGENT_USER'"
if id "$AGENT_USER" &>/dev/null; then
    warn "User '$AGENT_USER' already exists. Updating configuration..."
else
    if ! useradd -m -s /bin/bash "$AGENT_USER"; then
        error "Failed to create user '$AGENT_USER'"
    fi
    # Mark that we created the user for cleanup purposes
    touch "/tmp/jules-user-created"
    success "User '$AGENT_USER' created successfully"
fi

# Configure passwordless sudo for the agent user
info "Configuring passwordless sudo access for '$AGENT_USER'..."
SUDOERS_FILE="/etc/sudoers.d/jules-endpoint-agent"
echo "$AGENT_USER ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

# Verify sudoers file syntax
if ! visudo -c -f "$SUDOERS_FILE"; then
    rm -f "$SUDOERS_FILE"
    error "Failed to configure sudo access. Sudoers file syntax error."
fi

success "Passwordless sudo access configured for '$AGENT_USER'"

info "Configuring SSH access for '$AGENT_USER'..."
AGENT_HOME=$(eval echo ~$AGENT_USER)
SSH_DIR="$AGENT_HOME/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"

# Create SSH directory with proper permissions
if ! mkdir -p "$SSH_DIR"; then
    error "Failed to create SSH directory for user '$AGENT_USER'"
fi

# Add SSH public key
if ! echo "$JULES_SSH_PUBLIC_KEY" > "$AUTH_KEYS_FILE"; then
    error "Failed to write SSH public key to authorized_keys file"
fi

# Set proper ownership and permissions
if ! chown -R "$AGENT_USER:$AGENT_USER" "$SSH_DIR"; then
    error "Failed to set ownership of SSH directory"
fi

if ! chmod 700 "$SSH_DIR"; then
    error "Failed to set permissions on SSH directory"
fi

if ! chmod 600 "$AUTH_KEYS_FILE"; then
    error "Failed to set permissions on authorized_keys file"
fi

# Verify SSH key was added correctly
if ! grep -q "$(echo "$JULES_SSH_PUBLIC_KEY" | awk '{print $2}')" "$AUTH_KEYS_FILE"; then
    error "SSH key verification failed. Key may not have been added correctly."
fi

success "SSH key added and permissions set correctly"

# 5. Configure and Install Cloudflare Tunnel
info "--- Cloudflare Tunnel Setup ---"
info "You will now be asked to log in to your Cloudflare account."
info "A browser window may open. Please authorize the tunnel."
warn "If you don't have a Cloudflare account, create one at https://dash.cloudflare.com/sign-up"
echo
read -p "Press Enter to continue with Cloudflare authentication..."

# Attempt Cloudflare login with error handling
info "Initiating Cloudflare authentication..."
if ! cloudflared tunnel login; then
    error "Failed to authenticate with Cloudflare. Please ensure you have a Cloudflare account and try again."
fi

success "Cloudflare authentication successful"

# Generate unique tunnel name
TUNNEL_NAME="jules-ssh-endpoint-$(openssl rand -hex 4)"
info "Creating a new tunnel named: $TUNNEL_NAME"

# Create the tunnel and capture the UUID with better error handling
info "Creating Cloudflare tunnel..."
TUNNEL_CREATE_OUTPUT=$(cloudflared tunnel create "$TUNNEL_NAME" 2>&1) || {
    error "Failed to create Cloudflare tunnel. Output: $TUNNEL_CREATE_OUTPUT"
}

# Extract tunnel UUID from output
TUNNEL_UUID=$(echo "$TUNNEL_CREATE_OUTPUT" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1)

if [[ -z "$TUNNEL_UUID" ]]; then
    error "Failed to extract tunnel UUID from creation output: $TUNNEL_CREATE_OUTPUT"
fi

success "Tunnel '$TUNNEL_NAME' created with UUID: $TUNNEL_UUID"

# Create cloudflared configuration directory
info "Configuring the tunnel to point to the local SSH service..."
if ! mkdir -p "$CLOUDFLARED_CONFIG_DIR"; then
    error "Failed to create cloudflared configuration directory"
fi

# Create tunnel configuration file
cat > "$CLOUDFLARED_CONFIG_FILE" << EOF
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: "*"
    service: ssh://localhost:22
  - service: http_status:404
EOF

# Verify configuration file was created
if [ ! -f "$CLOUDFLARED_CONFIG_FILE" ]; then
    error "Failed to create cloudflared configuration file"
fi

# Verify credentials file exists
CREDENTIALS_FILE="/root/.cloudflared/$TUNNEL_UUID.json"
if [ ! -f "$CREDENTIALS_FILE" ]; then
    error "Cloudflare credentials file not found at $CREDENTIALS_FILE"
fi

success "Tunnel configuration created successfully"

# Install and start cloudflared service
info "Installing cloudflared as a system service..."
if ! cloudflared service install; then
    error "Failed to install cloudflared service"
fi

info "Starting cloudflared service..."
if ! systemctl start cloudflared; then
    error "Failed to start cloudflared service"
fi

# Wait for service to start and verify it's running
sleep 3
if ! systemctl is-active --quiet cloudflared; then
    error "cloudflared service failed to start. Check 'journalctl -u cloudflared' for details."
fi

success "cloudflared service installed and started successfully"

# Install tunnel reliability monitoring service
info "Installing tunnel reliability monitoring service..."
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Copy tunnel reliability service file
if [ -f "$SCRIPT_DIR/tunnel-reliability.service" ]; then
    cp "$SCRIPT_DIR/tunnel-reliability.service" /etc/systemd/system/
    
    # Update service file with correct path
    sed -i "s|/opt/jules-endpoint|$PROJECT_ROOT|g" /etc/systemd/system/tunnel-reliability.service
    
    # Reload systemd and enable the service
    systemctl daemon-reload
    
    if systemctl enable tunnel-reliability; then
        info "Starting tunnel reliability monitoring service..."
        if systemctl start tunnel-reliability; then
            success "Tunnel reliability monitoring service installed and started"
        else
            warn "Tunnel reliability monitoring service failed to start, but installation continues"
        fi
    else
        warn "Failed to enable tunnel reliability monitoring service, but installation continues"
    fi
else
    warn "Tunnel reliability service file not found, skipping monitoring setup"
fi

# 6. Generate Connection Information
info "Generating connection information..."

# Wait for tunnel to fully establish
info "Waiting for tunnel to establish connection..."
sleep 10

# Get script directory for connection info generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTION_INFO_SCRIPT="$SCRIPT_DIR/connection-info.sh"

# Generate connection information
if [ -f "$CONNECTION_INFO_SCRIPT" ]; then
    info "Using connection information generator..."
    if bash "$CONNECTION_INFO_SCRIPT"; then
        success "Connection information generated successfully"
    else
        warn "Connection info generator encountered issues, but installation may still be successful"
    fi
else
    # Fallback to basic connection info if script not found
    warn "Connection info script not found at $CONNECTION_INFO_SCRIPT"
    info "Attempting to extract tunnel hostname manually..."
    
    # Try multiple methods to get tunnel hostname
    TUNNEL_HOSTNAME=""
    
    # Method 1: Use cloudflared tunnel info
    if command -v cloudflared &> /dev/null; then
        TUNNEL_HOSTNAME=$(cloudflared tunnel info "$TUNNEL_UUID" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
    fi
    
    # Method 2: Check service logs if first method failed
    if [ -z "$TUNNEL_HOSTNAME" ] && systemctl is-active --quiet cloudflared; then
        TUNNEL_HOSTNAME=$(journalctl -u cloudflared --no-pager -n 50 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | tail -1 || echo "")
    fi
    
    if [ -n "$TUNNEL_HOSTNAME" ]; then
        success "--- INSTALLATION COMPLETE ---"
        echo
        success "Your Jules Endpoint Agent is now running!"
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
        info "The installation appears successful, but connection information could not be generated."
        info "You can run the following command later to get connection details:"
        info "  sudo bash $SCRIPT_DIR/connection-info.sh"
        echo
        info "Or check the tunnel status with:"
        info "  sudo cloudflared tunnel info $TUNNEL_UUID"
    fi
fi

# Final status and instructions
echo
success "Installation completed successfully!"
info "Installation log saved to: $INSTALL_LOG"
echo
info "Service Status:"
info "  SSH Service: $(systemctl is-active ssh 2>/dev/null || echo 'unknown')"
info "  Cloudflared Service: $(systemctl is-active cloudflared 2>/dev/null || echo 'unknown')"
echo
info "To regenerate connection information at any time, run:"
info "  sudo bash $SCRIPT_DIR/connection-info.sh"
echo
info "To check service logs:"
info "  sudo journalctl -u ssh -f"
info "  sudo journalctl -u cloudflared -f"
echo
warn "Remember: The '$AGENT_USER' user has full sudo privileges for AI agent access."

# Clean up temporary files
rm -f "/tmp/jules-user-created" 2>/dev/null || true
