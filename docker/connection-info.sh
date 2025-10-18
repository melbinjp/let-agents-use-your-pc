#!/bin/bash

# jules-endpoint-agent: connection-info.sh (Docker Edition)
#
# This script generates connection information for Jules to access the SSH endpoint
# running in a Docker container. It extracts tunnel hostname and creates formatted
# configuration blocks.

set -euo pipefail

# --- Constants ---
AGENT_USER="${JULES_USERNAME:-jules}"

# --- Helper Functions ---
info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1" >&2
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
    exit 1
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

# Function to extract tunnel hostname from environment or running process
extract_tunnel_hostname() {
    local hostname=""
    
    info "Extracting tunnel hostname..."
    
    # Method 1: Check if hostname is provided via environment variable
    if [ -n "${TUNNEL_HOSTNAME:-}" ]; then
        hostname="$TUNNEL_HOSTNAME"
        success "Found hostname from environment variable: $hostname"
        echo "$hostname"
        return 0
    fi
    
    # Method 2: Try to extract from cloudflared process logs
    if pgrep -f cloudflared > /dev/null; then
        info "Cloudflared is running, checking for hostname in process output..."
        
        # Give cloudflared a moment to establish connection if just started
        sleep 2
        
        # Try to find hostname in recent logs or process output
        # This is a bit tricky in Docker, so we'll try multiple approaches
        
        # Check if we can find it in any log files
        for log_location in /var/log/cloudflared.log /tmp/cloudflared.log; do
            if [ -f "$log_location" ]; then
                hostname=$(grep -oE '[a-z0-9-]+\.trycloudflare\.com' "$log_location" 2>/dev/null | tail -1 || echo "")
                if [ -n "$hostname" ]; then
                    success "Found hostname in log file $log_location: $hostname"
                    echo "$hostname"
                    return 0
                fi
            fi
        done
        
        # Try to get hostname from cloudflared tunnel info if we have the token
        if [ -n "${CLOUDFLARE_TOKEN:-}" ] && command -v cloudflared &> /dev/null; then
            # Extract tunnel ID from token (this is a simplified approach)
            info "Attempting to get tunnel info using cloudflared..."
            hostname=$(timeout 10 cloudflared tunnel info 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
            if [ -n "$hostname" ]; then
                success "Found hostname using cloudflared tunnel info: $hostname"
                echo "$hostname"
                return 0
            fi
        fi
    fi
    
    # Method 3: If we have a tunnel token, try to extract tunnel ID and get info
    if [ -n "${CLOUDFLARE_TOKEN:-}" ]; then
        info "Attempting to extract tunnel information from token..."
        # This is a simplified approach - in practice, the token format may vary
        # For now, we'll indicate that manual hostname extraction may be needed
        warn "Could not automatically extract hostname from tunnel token"
    fi
    
    error "Could not extract tunnel hostname automatically. Please provide TUNNEL_HOSTNAME environment variable or ensure cloudflared is running with proper logging."
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
    
    # Check if SSH service is running
    if ! pgrep -f sshd > /dev/null; then
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
=== Jules Endpoint Agent - Connection Information (Docker) ===

SSH Connection Details:
  Hostname: $hostname
  Username: $username
  Port: 22 (default)
  Authentication: SSH public key only

Quick Connect Command:
  ssh $username@$hostname

Container Information:
  Agent User: $username
  SSH Port: ${SSH_PORT:-22}
  Container: Docker-based deployment

Security Notes:
  - This endpoint requires SSH public key authentication
  - The user '$username' has full sudo privileges within the container
  - All traffic is encrypted through Cloudflare's network
  - Container provides isolated environment with full hardware access

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

Host jules-endpoint-docker
    HostName $hostname
    User $username
    Port 22
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Connection Command: ssh jules-endpoint-docker

Or direct command: ssh $username@$hostname

=== End Jules Configuration ===
EOF
}

# Function to generate environment-based connection info
generate_env_info() {
    cat << EOF

=== Environment Variables for Reference ===

Current Configuration:
  JULES_USERNAME: ${JULES_USERNAME:-jules}
  SSH_PORT: ${SSH_PORT:-22}
  CLOUDFLARE_TOKEN: ${CLOUDFLARE_TOKEN:+[SET]}
  TUNNEL_HOSTNAME: ${TUNNEL_HOSTNAME:-[NOT SET]}

To set tunnel hostname manually:
  docker run -e TUNNEL_HOSTNAME=your-tunnel.trycloudflare.com ...

=== End Environment Information ===
EOF
}

# Main function
main() {
    info "Jules Endpoint Agent - Connection Information Generator (Docker)"
    info "================================================================"
    
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
    
    # Generate environment information
    generate_env_info
    
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
        echo "Generate connection information for Jules Endpoint Agent (Docker)"
        echo
        echo "Options:"
        echo "  --hostname-only      Output only the tunnel hostname"
        echo "  --ssh-command-only   Output only the SSH connection command"
        echo "  --help, -h          Show this help message"
        echo
        echo "Environment Variables:"
        echo "  TUNNEL_HOSTNAME      Manually specify tunnel hostname"
        echo "  JULES_USERNAME       Username for agent (default: jules)"
        echo "  SSH_PORT            SSH port (default: 22)"
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