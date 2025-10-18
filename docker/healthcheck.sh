#!/bin/bash

# Health check script for Jules Endpoint Agent
# This script verifies that both SSH and cloudflared services are running properly

set -e

# Load enhanced diagnostics if available
if [[ -f "/app/diagnostics/error-handler.sh" ]]; then
    source "/app/diagnostics/error-handler.sh"
    set_error_context "component" "docker-healthcheck"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if SSH server is running
check_ssh() {
    if pgrep -f "sshd" > /dev/null; then
        echo -e "${GREEN}✓${NC} SSH server is running"
        return 0
    else
        echo -e "${RED}✗${NC} SSH server is not running"
        return 1
    fi
}

# Function to check if cloudflared is running
check_cloudflared() {
    if pgrep -f "cloudflared" > /dev/null; then
        echo -e "${GREEN}✓${NC} Cloudflared tunnel is running"
        return 0
    else
        echo -e "${RED}✗${NC} Cloudflared tunnel is not running"
        return 1
    fi
}

# Function to check if SSH port is listening
check_ssh_port() {
    local port=${SSH_PORT:-22}
    if netstat -ln | grep -q ":${port} "; then
        echo -e "${GREEN}✓${NC} SSH server is listening on port ${port}"
        return 0
    else
        echo -e "${RED}✗${NC} SSH server is not listening on port ${port}"
        return 1
    fi
}

# Function to check if jules user exists and has proper configuration
check_user() {
    local username=${JULES_USERNAME:-jules}
    if id "$username" &>/dev/null; then
        echo -e "${GREEN}✓${NC} User $username exists"
        
        # Check if SSH directory exists
        if [ -d "/home/$username/.ssh" ]; then
            echo -e "${GREEN}✓${NC} SSH directory exists for $username"
            
            # Check if authorized_keys exists
            if [ -f "/home/$username/.ssh/authorized_keys" ]; then
                echo -e "${GREEN}✓${NC} SSH authorized_keys file exists"
                return 0
            else
                echo -e "${RED}✗${NC} SSH authorized_keys file missing"
                return 1
            fi
        else
            echo -e "${RED}✗${NC} SSH directory missing for $username"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} User $username does not exist"
        return 1
    fi
}

# Function to check tunnel reliability status
check_tunnel_reliability() {
    if [ -f "/app/diagnostics/tunnel-reliability.sh" ]; then
        echo -e "${YELLOW}Checking tunnel reliability...${NC}"
        if bash "/app/diagnostics/tunnel-reliability.sh" health-check &>/dev/null; then
            echo -e "${GREEN}✓${NC} Tunnel reliability check passed"
            return 0
        else
            echo -e "${RED}✗${NC} Tunnel reliability check failed"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} Tunnel reliability monitoring not available"
        return 0
    fi
}

# Main health check
main() {
    echo "Jules Endpoint Agent Health Check"
    echo "================================="
    
    local exit_code=0
    
    # Check all components
    check_ssh || exit_code=1
    check_cloudflared || exit_code=1
    check_ssh_port || exit_code=1
    check_user || exit_code=1
    check_tunnel_reliability || exit_code=1
    
    echo
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}All health checks passed!${NC}"
        if command -v log_success &>/dev/null; then
            log_success "Docker container health check passed"
        fi
    else
        echo -e "${RED}Some health checks failed!${NC}"
        if command -v log_error &>/dev/null; then
            log_error "Docker container health check failed"
        fi
    fi
    
    exit $exit_code
}

# Install netstat if not available (for port checking)
if ! command -v netstat &> /dev/null; then
    apt-get update && apt-get install -y net-tools --no-install-recommends
fi

main "$@"