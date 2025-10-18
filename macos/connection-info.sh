#!/bin/bash

# jules-endpoint-agent: connection-info.sh (macOS Edition)
#
# This script generates connection information for Jules to access the SSH endpoint
# on macOS. It extracts tunnel hostname and creates formatted configuration blocks.

set -euo pipefail

# --- Constants ---
AGENT_USER="jules"
CLOUDFLARED_CONFIG_DIR="$HOME/.cloudflared"

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

# Function to extract tunnel hostname from Cloudflare
extract_tunnel_hostname() {
    local hostname=""
    
    info "Extracting tunnel hostname..."
    
    # Method 1: Try using cloudflared tunnel list command
    if command -v cloudflared &> /dev/null; then
        info "Attempting to get hostname using cloudflared tunnel list..."
        hostname=$(cloudflared tunnel list 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
        
        if [ -n "$hostname" ]; then
            success "Found hostname using tunnel list: $hostname"
            echo "$hostname"
            return 0
        fi
    fi
    
    # Method 2: Check cloudflared configuration directory
    if [ -d "$CLOUDFLARED_CONFIG_DIR" ]; then
        info "Searching for hostname in cloudflared configuration directory..."
        for config_file in "$CLOUDFLARED_CONFIG_DIR"/*.json; do
            if [ -f "$config_file" ]; then
                hostname=$(grep -oE '[a-z0-9-]+\.trycloudflare\.com' "$config_file" 2>/dev/null | head -1 || echo "")
                if [ -n "$hostname" ]; then
                    success "Found hostname in configuration file: $hostname"
                    echo "$hostname"
                    return 0
                fi
            fi
        done
    fi
    
    # Method 3: Check if cloudflared is running and try to get info from process
    if pgrep -f cloudflared > /dev/null; then
        info "Cloudflared is running, checking for hostname information..."
        
        # Try to get hostname from cloudflared tunnel info if we can find tunnel ID
        local tunnel_ids
        tunnel_ids=$(ps aux | grep cloudflared | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1 || echo "")
        
        if [ -n "$tunnel_ids" ] && command -v cloudflared &> /dev/null; then
            hostname=$(cloudflared tunnel info "$tunnel_ids" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
            if [ -n "$hostname" ]; then
                success "Found hostname using tunnel info: $hostname"
                echo "$hostname"
                return 0
            fi
        fi
    fi
    
    # Method 4: Check system logs for cloudflared entries (macOS specific)
    info "Checking system logs for cloudflared entries..."
    hostname=$(log show --predicate 'process == "cloudflared"' --last 1h 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | tail -1 || echo "")
    
    if [ -n "$hostname" ]; then
        success "Found hostname in system logs: $hostname"
        echo "$hostname"
        return 0
    fi
    
    error "Could not extract tunnel hostname. Please ensure the tunnel is running and try again."
}

# Function to validate connection information
validate_connection_info() {
    local hostname="$1"
    local username="$2"
    
    info "Validating connection information..."
    
    # Validate hostname format
    if ! echo "$hostname" | grep -qE '^[a-z0-9-]+\.(trycloudflare\.com|[a-z0-9.-]+)$'; then
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
    
    # Check if SSH service is running (macOS uses different service names)
    if ! launchctl list | grep -q "com.openssh.sshd" && ! pgrep -f sshd > /dev/null; then
        warn "SSH daemon does not appear to be running"
    fi
    
    # Check if cloudflared is running
    if ! pgrep -f cloudflared > /dev/null; then
        warn "Cloudflared process does not appear to be running"
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
    
    cat << EOF
=== Jules Endpoint Agent - Connection Information (macOS) ===

SSH Connection Details:
  Hostname: $hostname
  Username: $username
  Port: 22 (default)
  Authentication: SSH public key only

Quick Connect Command:
  ssh $username@$hostname

macOS Information:
  Agent User: $username
  SSH Service: macOS built-in SSH server
  Platform: macOS with bash/zsh

Security Notes:
  - This endpoint requires SSH public key authentication
  - The user '$username' has administrative privileges via sudo
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

Host jules-endpoint-macos
    HostName $hostname
    User $username
    Port 22
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Connection Command: ssh jules-endpoint-macos

Or direct command: ssh $username@$hostname

=== End Jules Configuration ===
EOF
}

# Main function
main() {
    info "Jules Endpoint Agent - Connection Information Generator (macOS)"
    info "=============================================================="
    
    # Extract tunnel hostname
    local hostname
    hostname=$(extract_tunnel_hostname)
    
    # Validate connection information
    validate_connection_info "$hostname" "$AGENT_USER"
    
    # Generate and display connection information
    echo
    generate_config_block "$hostname" "$AGENT_USER"
    
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
        extract_tunnel_hostname
        ;;
    --ssh-command-only)
        hostname=$(extract_tunnel_hostname)
        generate_ssh_command "$hostname" "$AGENT_USER"
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo "Generate connection information for Jules Endpoint Agent (macOS)"
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