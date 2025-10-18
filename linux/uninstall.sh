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
BACKUP_DIR="/tmp/jules-agent-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/jules-uninstall-$(date +%Y%m%d-%H%M%S).log"

# --- Helper Functions ---
info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

warn() {
    echo "[WARN] $1" >&2 | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $1" >&2 | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo "[SUCCESS] $1" | tee -a "$LOG_FILE"
}

# Create backup of configuration before removal
backup_configuration() {
    info "Creating configuration backup at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup cloudflared configuration
    if [ -d "$CLOUDFLARED_CONFIG_DIR" ]; then
        cp -r "$CLOUDFLARED_CONFIG_DIR" "$BACKUP_DIR/cloudflared" 2>/dev/null || true
        info "Backed up cloudflared configuration"
    fi
    
    # Backup user home directory (excluding large files)
    if [ -d "/home/$AGENT_USER" ]; then
        mkdir -p "$BACKUP_DIR/user-home"
        # Only backup configuration files, not large data
        find "/home/$AGENT_USER" -maxdepth 2 -name ".*" -type f -size -1M -exec cp {} "$BACKUP_DIR/user-home/" \; 2>/dev/null || true
        info "Backed up user configuration files"
    fi
    
    # Backup SSH configuration
    if [ -f "/etc/ssh/sshd_config" ]; then
        cp "/etc/ssh/sshd_config" "$BACKUP_DIR/sshd_config.bak" 2>/dev/null || true
        info "Backed up SSH configuration"
    fi
    
    # Create restoration script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Jules Agent Configuration Restore Script
# Generated during uninstallation

BACKUP_DIR="$(dirname "$0")"
AGENT_USER="jules"

echo "This script can help restore Jules Agent configuration."
echo "WARNING: This will recreate the jules user and restore configurations."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restoration cancelled."
    exit 0
fi

# Restore cloudflared configuration
if [ -d "$BACKUP_DIR/cloudflared" ]; then
    sudo mkdir -p /etc/cloudflared
    sudo cp -r "$BACKUP_DIR/cloudflared/"* /etc/cloudflared/
    echo "Restored cloudflared configuration"
fi

# Restore SSH configuration
if [ -f "$BACKUP_DIR/sshd_config.bak" ]; then
    sudo cp "$BACKUP_DIR/sshd_config.bak" /etc/ssh/sshd_config
    echo "Restored SSH configuration"
fi

echo "Manual steps may be required to complete restoration:"
echo "1. Recreate the jules user account"
echo "2. Reinstall cloudflared binary"
echo "3. Restart SSH service"
echo "4. Reconfigure tunnel authentication"
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    
    info "Configuration backup completed at $BACKUP_DIR"
    info "Use $BACKUP_DIR/restore.sh to restore configuration if needed"
}

# Verify complete removal
verify_removal() {
    info "Verifying complete removal..."
    local issues_found=0
    
    # Check if user still exists
    if id "$AGENT_USER" &>/dev/null; then
        warn "User $AGENT_USER still exists"
        ((issues_found++))
    fi
    
    # Check if cloudflared config still exists
    if [ -d "$CLOUDFLARED_CONFIG_DIR" ]; then
        warn "Cloudflared configuration directory still exists: $CLOUDFLARED_CONFIG_DIR"
        ((issues_found++))
    fi
    
    # Check if cloudflared binary still exists
    if [ -f "/usr/local/bin/cloudflared" ]; then
        warn "Cloudflared binary still exists: /usr/local/bin/cloudflared"
        ((issues_found++))
    fi
    
    # Check if services are still running
    if systemctl is-active --quiet cloudflared; then
        warn "Cloudflared service is still running"
        ((issues_found++))
    fi
    
    # Check for remaining service files
    if [ -f "/etc/systemd/system/cloudflared.service" ]; then
        warn "Cloudflared service file still exists"
        ((issues_found++))
    fi
    
    # Check for SSH configuration changes
    if grep -q "ClientAliveInterval" /etc/ssh/sshd_config 2>/dev/null; then
        info "SSH configuration still contains Jules-specific settings (this may be intentional)"
    fi
    
    if [ $issues_found -eq 0 ]; then
        success "Verification complete: All components successfully removed"
        return 0
    else
        warn "Verification found $issues_found potential issues (see above)"
        return 1
    fi
}

# --- Main Script ---

# Initialize logging
info "Jules Endpoint Agent Uninstaller started at $(date)"
info "Log file: $LOG_FILE"

# 1. Welcome and Pre-flight Checks
info "Welcome to the Jules Endpoint Agent uninstaller."
warn "This script will permanently remove the agent and its configurations."

# Offer backup option
read -p "Create configuration backup before removal? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    CREATE_BACKUP=true
else
    CREATE_BACKUP=false
fi

read -p "Are you sure you want to continue with uninstallation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Uninstallation cancelled."
    exit 0
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo or as root. Please run as: sudo $0"
fi

# Create backup if requested
if [ "$CREATE_BACKUP" = true ]; then
    backup_configuration
fi

# 2. Stop and Disable Services
info "Stopping and disabling services..."

# Stop cloudflared service
if systemctl is-active --quiet cloudflared; then
    info "Stopping cloudflared service..."
    systemctl stop cloudflared
    success "Cloudflared service stopped"
else
    info "Cloudflared service is not running"
fi

# Disable cloudflared service
if systemctl is-enabled --quiet cloudflared 2>/dev/null; then
    info "Disabling cloudflared service..."
    systemctl disable cloudflared
    success "Cloudflared service disabled"
else
    info "Cloudflared service is not enabled"
fi

# Terminate any running cloudflared processes
info "Terminating any remaining cloudflared processes..."
pkill -f cloudflared || true

# Kill any SSH sessions for the agent user
if id "$AGENT_USER" &>/dev/null; then
    info "Terminating active SSH sessions for user $AGENT_USER..."
    pkill -u "$AGENT_USER" || true
    # Wait a moment for graceful termination
    sleep 2
    # Force kill if still running
    pkill -9 -u "$AGENT_USER" || true
fi

# Remove service files
info "Removing service files..."
rm -f /etc/systemd/system/cloudflared.service
rm -f /etc/systemd/system/jules-endpoint.service  # Legacy service file
systemctl daemon-reload
success "Services stopped and disabled"

# 3. Delete Cloudflare Tunnel and Configuration
info "Processing Cloudflare tunnel configuration..."

if [ -f "$CLOUDFLARED_CONFIG_FILE" ]; then
    info "Reading tunnel configuration from $CLOUDFLARED_CONFIG_FILE..."
    
    # Extract tunnel UUID and name
    TUNNEL_UUID=$(grep -oP 'tunnel: \K[a-f0-9-]+' "$CLOUDFLARED_CONFIG_FILE" 2>/dev/null || true)
    TUNNEL_NAME=$(grep -oP 'tunnel: \K[a-zA-Z0-9-]+' "$CLOUDFLARED_CONFIG_FILE" 2>/dev/null || true)

    if [ -n "$TUNNEL_UUID" ]; then
        info "Found tunnel UUID: $TUNNEL_UUID"
        
        # Try to delete the tunnel
        if command -v cloudflared >/dev/null 2>&1; then
            info "Attempting to delete Cloudflare tunnel..."
            if cloudflared tunnel delete "$TUNNEL_UUID" 2>/dev/null; then
                success "Tunnel deleted successfully from Cloudflare"
            else
                warn "Failed to delete tunnel from Cloudflare. Possible reasons:"
                warn "  - Not logged in to cloudflared (run 'cloudflared tunnel login')"
                warn "  - Tunnel already deleted"
                warn "  - Network connectivity issues"
                warn "You may need to delete it manually from the Cloudflare dashboard."
            fi
        else
            warn "cloudflared binary not found, cannot delete tunnel remotely"
            warn "Please delete tunnel $TUNNEL_UUID manually from Cloudflare dashboard"
        fi
    else
        warn "Could not extract tunnel UUID from configuration file"
    fi

    info "Removing cloudflared configuration directory..."
    rm -rf "$CLOUDFLARED_CONFIG_DIR"
    success "Local cloudflared configuration removed"
else
    info "No cloudflared configuration file found, skipping tunnel deletion"
fi

# Remove any cloudflared credentials files in user directories
info "Cleaning up cloudflared credentials..."
find /home -name ".cloudflared" -type d -exec rm -rf {} + 2>/dev/null || true
find /root -name ".cloudflared" -type d -exec rm -rf {} + 2>/dev/null || true

# 4. Delete Agent User
info "Processing agent user account..."

if id "$AGENT_USER" &>/dev/null; then
    info "Removing user '$AGENT_USER' and associated data..."
    
    # Ensure all processes are terminated (already done above, but double-check)
    pkill -u "$AGENT_USER" || true
    sleep 1
    pkill -9 -u "$AGENT_USER" || true
    
    # Remove user from sudo group if present
    if groups "$AGENT_USER" | grep -q sudo; then
        deluser "$AGENT_USER" sudo 2>/dev/null || true
        info "Removed $AGENT_USER from sudo group"
    fi
    
    # Remove user and home directory
    if userdel -r "$AGENT_USER" 2>/dev/null; then
        success "User '$AGENT_USER' and home directory deleted successfully"
    else
        warn "Failed to delete user with home directory, trying without -r flag..."
        if userdel "$AGENT_USER" 2>/dev/null; then
            success "User '$AGENT_USER' deleted (home directory may remain)"
            # Manually remove home directory if it exists
            if [ -d "/home/$AGENT_USER" ]; then
                rm -rf "/home/$AGENT_USER"
                info "Manually removed home directory"
            fi
        else
            warn "Failed to delete user '$AGENT_USER'. Manual cleanup may be required."
        fi
    fi
    
    # Remove any remaining user-related files
    find /tmp -user "$AGENT_USER" -delete 2>/dev/null || true
    find /var/tmp -user "$AGENT_USER" -delete 2>/dev/null || true
    
else
    info "User '$AGENT_USER' not found, skipping user deletion"
fi

# 5. Remove Binaries and Additional Cleanup
info "Removing installed binaries and additional components..."

# Remove cloudflared binary
if [ -f "/usr/local/bin/cloudflared" ]; then
    rm -f /usr/local/bin/cloudflared
    success "Removed cloudflared binary"
else
    info "cloudflared binary not found in /usr/local/bin"
fi

# Remove shell2http (legacy from older versions)
if [ -f "/usr/local/bin/shell2http" ]; then
    rm -f /usr/local/bin/shell2http
    info "Removed legacy shell2http binary"
fi

# Remove any Jules-specific scripts or configurations
rm -f /usr/local/bin/jules-* 2>/dev/null || true

# Clean up temporary files
info "Cleaning up temporary files..."
rm -f /tmp/jules-* 2>/dev/null || true
rm -f /tmp/cloudflared-* 2>/dev/null || true

# Remove log files (but preserve our current log)
find /var/log -name "*jules*" -not -name "$(basename "$LOG_FILE")" -delete 2>/dev/null || true

# Clean up SSH authorized_keys entries (if any remain)
info "Cleaning up SSH configurations..."
if [ -f "/root/.ssh/authorized_keys" ]; then
    # Remove any keys with jules-related comments
    sed -i '/jules\|Jules/d' /root/.ssh/authorized_keys 2>/dev/null || true
fi

# 6. Final System Cleanup
info "Performing final system cleanup..."

# Reload systemd after all service file removals
systemctl daemon-reload

# Update package cache if we installed packages
if command -v apt-get >/dev/null 2>&1; then
    apt-get autoremove -y 2>/dev/null || true
fi

# 7. Verification
info "Performing removal verification..."
if verify_removal; then
    echo ""
    success "=== UNINSTALLATION COMPLETE ==="
    success "The Jules Endpoint Agent has been successfully removed from your system."
    echo ""
    if [ "$CREATE_BACKUP" = true ]; then
        info "Configuration backup available at: $BACKUP_DIR"
        info "Use the restore script if you need to recover: $BACKUP_DIR/restore.sh"
    fi
    info "Uninstallation log saved to: $LOG_FILE"
    echo ""
else
    echo ""
    warn "=== UNINSTALLATION COMPLETED WITH WARNINGS ==="
    warn "Some components may not have been fully removed (see verification output above)."
    warn "Manual cleanup may be required for complete removal."
    echo ""
    if [ "$CREATE_BACKUP" = true ]; then
        info "Configuration backup available at: $BACKUP_DIR"
    fi
    info "Uninstallation log saved to: $LOG_FILE"
    echo ""
    exit 1
fi
