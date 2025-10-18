#!/bin/bash

# jules-endpoint-agent: connection-info.sh
#
# This script generates connection information for Jules to access the SSH endpoint.
# It extracts tunnel hostname from Cloudflare and creates formatted configuration blocks.

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

success() {
    echo "[SUCCESS] $1"
}

# Function to extract tunnel UUID from config file
extract_tunnel_uuid() {
    if [ ! -f "$CLOUDFLARED_CONFIG_FILE" ]; then
        error "Cloudflare config file not found at $CLOUDFLARED_CONFIG_FILE"
    fi
    
    local tunnel_uuid
    tunnel_uuid=$(grep "^tunnel:" "$CLOUDFLARED_CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    
    if [ -z "$tunnel_uuid" ]; then
        error "Could not extract tunnel UUID from config file"
    fi
    
    echo "$tunnel_uuid"
}

# Function to get tunnel name from UUID
get_tunnel_name() {
    local tunnel_uuid="$1"
    local tunnel_name
    
    # Try to get tunnel name using cloudflared tunnel info
    if command -v cloudflared &> /dev/null; then
        tunnel_name=$(cloudflared tunnel info "$tunnel_uuid" 2>/dev/null | grep "Name:" | awk '{print $2}' || echo "")
    fi
    
    if [ -z "$tunnel_name" ]; then
        # Fallback: use UUID as name
        tunnel_name="$tunnel_uuid"
    fi
    
    echo "$tunnel_name"
}

# Function to extract tunnel hostname from Cloudflare
extract_tunnel_hostname() {
    local tunnel_uuid="$1"
    local hostname=""
    local max_attempts=5
    local attempt=1
    
    info "Extracting tunnel hostname for UUID: $tunnel_uuid"
    
    # Method 1: Try using cloudflared tunnel info command with retries
    if command -v cloudflared &> /dev/null; then
        info "Attempting to get hostname using cloudflared tunnel info..."
        while [ $attempt -le $max_attempts ]; do
            hostname=$(cloudflared tunnel info "$tunnel_uuid" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
            
            if [ -n "$hostname" ]; then
                success "Found hostname using tunnel info (attempt $attempt): $hostname"
                echo "$hostname"
                return 0
            fi
            
            if [ $attempt -lt $max_attempts ]; then
                info "Attempt $attempt failed, retrying in 2 seconds..."
                sleep 2
            fi
            attempt=$((attempt + 1))
        done
    fi
    
    # Method 2: Try using cloudflared tunnel list command
    if command -v cloudflared &> /dev/null; then
        info "Attempting to get hostname using cloudflared tunnel list..."
        hostname=$(cloudflared tunnel list 2>/dev/null | grep "$tunnel_uuid" | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
        
        if [ -n "$hostname" ]; then
            success "Found hostname using tunnel list: $hostname"
            echo "$hostname"
            return 0
        fi
    fi
    
    # Method 3: Check if tunnel is running and try to extract from logs
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        info "Checking cloudflared service logs for hostname..."
        # Try different log patterns
        hostname=$(journalctl -u cloudflared --no-pager -n 200 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | tail -1 || echo "")
        
        if [ -n "$hostname" ]; then
            success "Found hostname in service logs: $hostname"
            echo "$hostname"
            return 0
        fi
        
        # Try alternative log patterns
        hostname=$(journalctl -u cloudflared --no-pager -n 200 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | sed 's/https:\/\///' | tail -1 || echo "")
        
        if [ -n "$hostname" ]; then
            success "Found hostname in service logs (alternative pattern): $hostname"
            echo "$hostname"
            return 0
        fi
    fi
    
    # Method 4: Try to find hostname in cloudflared credentials directory
    local creds_dir="/root/.cloudflared"
    if [ -d "$creds_dir" ]; then
        info "Searching for hostname in cloudflared credentials directory..."
        # Look for any .json files that might contain hostname information
        for creds_file in "$creds_dir"/*.json; do
            if [ -f "$creds_file" ]; then
                hostname=$(grep -oE '[a-z0-9-]+\.trycloudflare\.com' "$creds_file" 2>/dev/null | head -1 || echo "")
                if [ -n "$hostname" ]; then
                    success "Found hostname in credentials file: $hostname"
                    echo "$hostname"
                    return 0
                fi
            fi
        done
    fi
    
    # Method 5: Try to get hostname from tunnel route command
    if command -v cloudflared &> /dev/null; then
        info "Attempting to get hostname using cloudflared tunnel route dns..."
        hostname=$(cloudflared tunnel route dns "$tunnel_uuid" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
        
        if [ -n "$hostname" ]; then
            success "Found hostname using tunnel route: $hostname"
            echo "$hostname"
            return 0
        fi
    fi
    
    error "Could not extract tunnel hostname after trying all methods. Please ensure the tunnel is running and try again."
}

# Function to validate connection information
validate_connection_info() {
    local hostname="$1"
    local username="$2"
    
    info "Validating connection information..."
    
    # Validate hostname format
    if ! echo "$hostname" | grep -qE '^[a-z0-9-]+\.(trycloudflare\.com|[a-z0-9.-]+)$'$'; then
        error "Invalid hostname format: $hostname"
    fi
    
    # Validate username
    if [ -z "$username" ]; then
        error "Username cannot be empty"
    fi
    
    # Check if user exists on system
    if ! id "$username" &>/dev/null; then
        warn "User '$username' does not exist on this system"
    fi
    
    # Check if SSH service is running
    if ! systemctl is-active --quiet ssh 2>/dev/null && ! systemctl is-active --quiet sshd 2>/dev/null; then
        warn "SSH service does not appear to be running"
    fi
    
    # Check if cloudflared service is running
    if ! systemctl is-active --quiet cloudflared 2>/dev/null; then
        warn "Cloudflared service does not appear to be running"
    fi
    
    success "Connection information validation completed"
}

# Function to generate SSH connection command
generate_ssh_command() {
    local hostname="$1"
    local username="$2"
    
    echo "ssh $username@$hostname"
}

# Function to generate formatted configuration block
generate_config_block() {
    local hostname="$1"
    local username="$2"
    local tunnel_uuid="$3"
    local tunnel_name="$4"
    
    cat << EOF
=== Jules Endpoint Agent - Connection Information ===

SSH Connection Details:
  Hostname: $hostname
  Username: $username
  Port: 22 (default)
  Authentication: SSH public key only

Quick Connect Command:
  ssh $username@$hostname

Tunnel Information:
  Tunnel UUID: $tunnel_uuid
  Tunnel Name: $tunnel_name
  Protocol: SSH over Cloudflare Tunnel

Security Notes:
  - This endpoint requires SSH public key authentication
  - The user '$username' has full sudo privileges
  - All traffic is encrypted through Cloudflare's network
  - No direct network ports are exposed on the host machine

Connection Test:
  To test the connection, run: ssh -o ConnectTimeout=10 $username@$hostname 'echo "Connection successful"'

=== End Connection Information ===
EOF
}

# Function to generate copy-pasteable configuration for Jules
generate_jules_config() {
    local hostname="$1"
    local username="$2"
    
    cat << EOF

=== Copy-Pasteable Configuration for Jules ===

Host jules-endpoint
    HostName $hostname
    User $username
    Port 22
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Connection Command: ssh jules-endpoint

Or direct command: ssh $username@$hostname

=== End Jules Configuration ===
EOF
}

# Main function
main() {
    info "Jules Endpoint Agent - Connection Information Generator"
    info "===================================================="
    
    # Check if running as root (needed to access cloudflared config)
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run with sudo or as root to access cloudflared configuration"
    fi
    
    # Extract tunnel UUID from config
    local tunnel_uuid
    tunnel_uuid=$(extract_tunnel_uuid)
    info "Found tunnel UUID: $tunnel_uuid"
    
    # Get tunnel name
    local tunnel_name
    tunnel_name=$(get_tunnel_name "$tunnel_uuid")
    info "Tunnel name: $tunnel_name"
    
    # Extract tunnel hostname
    local hostname
    hostname=$(extract_tunnel_hostname "$tunnel_uuid")
    
    # Validate connection information
    validate_connection_info "$hostname" "$AGENT_USER"
    
    # Generate and display connection information
    echo
    generate_config_block "$hostname" "$AGENT_USER" "$tunnel_uuid" "$tunnel_name"
    
    # Generate Jules-specific configuration
    generate_jules_config "$hostname" "$AGENT_USER"
    
    # Generate simple SSH command
    echo
    success "Connection information generated successfully!"
    info "Jules can connect using: $(generate_ssh_command "$hostname" "$AGENT_USER")"
    
    return 0
}

# Handle command line arguments
case "${1:-}" in
    --hostname-only)
        tunnel_uuid=$(extract_tunnel_uuid)
        extract_tunnel_hostname "$tunnel_uuid"
        ;;
    --ssh-command-only)
        tunnel_uuid=$(extract_tunnel_uuid)
        hostname=$(extract_tunnel_hostname "$tunnel_uuid")
        generate_ssh_command "$hostname" "$AGENT_USER"
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo "Generate connection information for Jules Endpoint Agent"
        echo
        echo "Options:"
        echo "  --hostname-only      Output only the tunnel hostname"
        echo "  --ssh-command-only   Output only the SSH connection command"
        echo "  --help, -h          Show this help message"
        echo
        echo "Default: Generate complete connection information block"
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1. Use --help for usage information."
        ;;
esac