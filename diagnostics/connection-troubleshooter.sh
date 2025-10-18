#!/bin/bash

# Connection Troubleshooting Utilities
# Provides comprehensive connection testing and diagnostic tools

set -euo pipefail

# Source error handler
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error-handler.sh"

# Configuration
TIMEOUT_SHORT=5
TIMEOUT_MEDIUM=15
TIMEOUT_LONG=30
TEST_HOSTS=("8.8.8.8" "1.1.1.1" "google.com")
CLOUDFLARE_API="https://api.cloudflare.com/client/v4"

# Connection test results
declare -A TEST_RESULTS

# Initialize connection troubleshooter
init_troubleshooter() {
    log_info "Initializing connection troubleshooter..."
    set_error_context "component" "connection-troubleshooter"
    
    # Clear previous test results
    TEST_RESULTS=()
    
    log_success "Connection troubleshooter initialized"
}

# Test basic network connectivity
test_basic_connectivity() {
    log_info "Testing basic network connectivity..."
    set_error_context "operation" "basic-connectivity-test"
    
    local success_count=0
    local total_tests=${#TEST_HOSTS[@]}
    
    for host in "${TEST_HOSTS[@]}"; do
        log_debug "Testing connectivity to $host..."
        
        if timeout $TIMEOUT_SHORT ping -c 1 "$host" &>/dev/null; then
            log_success "✓ $host is reachable"
            TEST_RESULTS["ping_$host"]="success"
            ((success_count++))
        else
            log_error "✗ $host is not reachable"
            TEST_RESULTS["ping_$host"]="failed"
        fi
    done
    
    local success_rate=$((success_count * 100 / total_tests))
    log_info "Basic connectivity: $success_count/$total_tests hosts reachable ($success_rate%)"
    
    if [ $success_count -eq 0 ]; then
        handle_error $E_NETWORK "No network connectivity detected" "network" "connectivity-test"
        return $E_NETWORK
    elif [ $success_count -lt $total_tests ]; then
        log_warn "Partial network connectivity detected"
        return 1
    fi
    
    return 0
}

# Test DNS resolution
test_dns_resolution() {
    log_info "Testing DNS resolution..."
    set_error_context "operation" "dns-resolution-test"
    
    local dns_servers=()
    while IFS= read -r line; do
        if [[ $line =~ ^nameserver[[:space:]]+([0-9.]+) ]]; then
            dns_servers+=("${BASH_REMATCH[1]}")
        fi
    done < /etc/resolv.conf
    
    if [ ${#dns_servers[@]} -eq 0 ]; then
        log_error "No DNS servers configured"
        TEST_RESULTS["dns_config"]="failed"
        return $E_CONFIG
    fi
    
    log_info "Configured DNS servers: ${dns_servers[*]}"
    TEST_RESULTS["dns_config"]="success"
    
    # Test DNS resolution for each test host
    local success_count=0
    for host in "${TEST_HOSTS[@]}"; do
        if [[ $host =~ ^[0-9.]+$ ]]; then
            continue  # Skip IP addresses
        fi
        
        log_debug "Testing DNS resolution for $host..."
        
        if timeout $TIMEOUT_SHORT nslookup "$host" &>/dev/null; then
            log_success "✓ $host resolves correctly"
            TEST_RESULTS["dns_$host"]="success"
            ((success_count++))
        else
            log_error "✗ $host failed to resolve"
            TEST_RESULTS["dns_$host"]="failed"
        fi
    done
    
    if [ $success_count -eq 0 ]; then
        handle_error $E_NETWORK "DNS resolution failed for all test hosts" "dns" "resolution-test"
        return $E_NETWORK
    fi
    
    return 0
}

# Test SSH service availability
test_ssh_service() {
    log_info "Testing SSH service..."
    set_error_context "operation" "ssh-service-test"
    
    # Check if SSH service is installed
    if ! command -v sshd &>/dev/null; then
        log_error "SSH server (sshd) is not installed"
        TEST_RESULTS["ssh_installed"]="failed"
        handle_error $E_DEPENDENCY "SSH server not installed" "ssh" "service-check"
        return $E_DEPENDENCY
    fi
    
    TEST_RESULTS["ssh_installed"]="success"
    log_success "✓ SSH server is installed"
    
    # Check if SSH service is running
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        log_success "✓ SSH service is running"
        TEST_RESULTS["ssh_running"]="success"
    else
        log_error "✗ SSH service is not running"
        TEST_RESULTS["ssh_running"]="failed"
        
        # Try to start SSH service
        log_info "Attempting to start SSH service..."
        if systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null; then
            log_success "✓ SSH service started successfully"
            TEST_RESULTS["ssh_running"]="success"
        else
            handle_error $E_SERVICE "Failed to start SSH service" "ssh" "service-start"
            return $E_SERVICE
        fi
    fi
    
    # Check SSH configuration
    if sshd -t 2>/dev/null; then
        log_success "✓ SSH configuration is valid"
        TEST_RESULTS["ssh_config"]="success"
    else
        log_error "✗ SSH configuration has errors"
        TEST_RESULTS["ssh_config"]="failed"
        handle_error $E_CONFIG "SSH configuration validation failed" "ssh" "config-test"
        return $E_CONFIG
    fi
    
    # Check if SSH is listening on expected port
    local ssh_port=$(grep -E "^Port\s+" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    if netstat -ln 2>/dev/null | grep -q ":$ssh_port "; then
        log_success "✓ SSH is listening on port $ssh_port"
        TEST_RESULTS["ssh_listening"]="success"
    else
        log_error "✗ SSH is not listening on port $ssh_port"
        TEST_RESULTS["ssh_listening"]="failed"
        return $E_SERVICE
    fi
    
    return 0
}

# Test Cloudflare tunnel connectivity
test_cloudflare_tunnel() {
    log_info "Testing Cloudflare tunnel..."
    set_error_context "operation" "cloudflare-tunnel-test"
    
    # Check if cloudflared is installed
    if ! command -v cloudflared &>/dev/null; then
        log_error "cloudflared is not installed"
        TEST_RESULTS["cloudflared_installed"]="failed"
        handle_error $E_DEPENDENCY "cloudflared not installed" "cloudflared" "installation-check"
        return $E_DEPENDENCY
    fi
    
    TEST_RESULTS["cloudflared_installed"]="success"
    log_success "✓ cloudflared is installed"
    
    # Check cloudflared version
    local cf_version=$(cloudflared --version 2>/dev/null | head -1 || echo "unknown")
    log_info "cloudflared version: $cf_version"
    
    # Check if cloudflared service is running
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log_success "✓ cloudflared service is running"
        TEST_RESULTS["cloudflared_running"]="success"
    else
        log_error "✗ cloudflared service is not running"
        TEST_RESULTS["cloudflared_running"]="failed"
        
        # Check if there's a configuration file
        if [ -f "/etc/cloudflared/config.yml" ]; then
            log_info "Configuration file exists, attempting to start service..."
            if systemctl start cloudflared 2>/dev/null; then
                log_success "✓ cloudflared service started successfully"
                TEST_RESULTS["cloudflared_running"]="success"
                sleep 3  # Give it time to establish connection
            else
                handle_error $E_SERVICE "Failed to start cloudflared service" "cloudflared" "service-start"
                return $E_SERVICE
            fi
        else
            log_warn "No cloudflared configuration found"
            TEST_RESULTS["cloudflared_config"]="missing"
            return $E_CONFIG
        fi
    fi
    
    # Test Cloudflare API connectivity
    log_info "Testing Cloudflare API connectivity..."
    if timeout $TIMEOUT_MEDIUM curl -s "$CLOUDFLARE_API" &>/dev/null; then
        log_success "✓ Cloudflare API is reachable"
        TEST_RESULTS["cloudflare_api"]="success"
    else
        log_error "✗ Cloudflare API is not reachable"
        TEST_RESULTS["cloudflare_api"]="failed"
        return $E_NETWORK
    fi
    
    # Check tunnel status if possible
    if [ -f "/etc/cloudflared/config.yml" ]; then
        local tunnel_uuid=$(grep "^tunnel:" /etc/cloudflared/config.yml | awk '{print $2}' | tr -d '"' || echo "")
        if [ -n "$tunnel_uuid" ]; then
            log_info "Found tunnel UUID: $tunnel_uuid"
            
            # Try to get tunnel info
            if timeout $TIMEOUT_MEDIUM cloudflared tunnel info "$tunnel_uuid" &>/dev/null; then
                log_success "✓ Tunnel information retrieved successfully"
                TEST_RESULTS["tunnel_info"]="success"
            else
                log_warn "Could not retrieve tunnel information"
                TEST_RESULTS["tunnel_info"]="failed"
            fi
        fi
    fi
    
    return 0
}

# Test end-to-end SSH connection through tunnel
test_ssh_through_tunnel() {
    log_info "Testing SSH connection through tunnel..."
    set_error_context "operation" "ssh-tunnel-test"
    
    # First, we need to get the tunnel hostname
    local tunnel_hostname=""
    
    if [ -f "/etc/cloudflared/config.yml" ]; then
        local tunnel_uuid=$(grep "^tunnel:" /etc/cloudflared/config.yml | awk '{print $2}' | tr -d '"' || echo "")
        if [ -n "$tunnel_uuid" ]; then
            # Try multiple methods to get hostname
            tunnel_hostname=$(cloudflared tunnel info "$tunnel_uuid" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
            
            if [ -z "$tunnel_hostname" ]; then
                tunnel_hostname=$(journalctl -u cloudflared --no-pager -n 50 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | tail -1 || echo "")
            fi
        fi
    fi
    
    if [ -z "$tunnel_hostname" ]; then
        log_warn "Could not determine tunnel hostname, skipping SSH tunnel test"
        TEST_RESULTS["ssh_tunnel"]="skipped"
        return 0
    fi
    
    log_info "Testing SSH connection to: $tunnel_hostname"
    
    # Create a temporary SSH key for testing
    local test_key_dir="/tmp/ssh-tunnel-test-$$"
    mkdir -p "$test_key_dir"
    ssh-keygen -t ed25519 -f "$test_key_dir/test_key" -N "" -C "tunnel-test" &>/dev/null
    
    # Test SSH connection (will fail authentication but should connect)
    if timeout $TIMEOUT_MEDIUM ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no \
        -i "$test_key_dir/test_key" jules@"$tunnel_hostname" exit 2>&1 | grep -q "Permission denied"; then
        log_success "✓ SSH tunnel connection established (authentication expected to fail)"
        TEST_RESULTS["ssh_tunnel"]="success"
    else
        log_error "✗ SSH tunnel connection failed"
        TEST_RESULTS["ssh_tunnel"]="failed"
    fi
    
    # Cleanup
    rm -rf "$test_key_dir"
    
    return 0
}

# Test user configuration
test_user_configuration() {
    log_info "Testing user configuration..."
    set_error_context "operation" "user-config-test"
    
    local agent_user="jules"
    
    # Check if agent user exists
    if id "$agent_user" &>/dev/null; then
        log_success "✓ Agent user '$agent_user' exists"
        TEST_RESULTS["user_exists"]="success"
    else
        log_error "✗ Agent user '$agent_user' does not exist"
        TEST_RESULTS["user_exists"]="failed"
        return $E_CONFIG
    fi
    
    # Check user's home directory
    local user_home=$(eval echo ~$agent_user)
    if [ -d "$user_home" ]; then
        log_success "✓ User home directory exists: $user_home"
        TEST_RESULTS["user_home"]="success"
    else
        log_error "✗ User home directory missing: $user_home"
        TEST_RESULTS["user_home"]="failed"
        return $E_CONFIG
    fi
    
    # Check SSH directory and permissions
    local ssh_dir="$user_home/.ssh"
    if [ -d "$ssh_dir" ]; then
        log_success "✓ SSH directory exists: $ssh_dir"
        TEST_RESULTS["ssh_dir"]="success"
        
        # Check permissions
        local ssh_perms=$(stat -c %a "$ssh_dir")
        if [ "$ssh_perms" = "700" ]; then
            log_success "✓ SSH directory permissions are correct (700)"
            TEST_RESULTS["ssh_dir_perms"]="success"
        else
            log_warn "SSH directory permissions are $ssh_perms (should be 700)"
            TEST_RESULTS["ssh_dir_perms"]="warning"
        fi
    else
        log_error "✗ SSH directory missing: $ssh_dir"
        TEST_RESULTS["ssh_dir"]="failed"
        return $E_CONFIG
    fi
    
    # Check authorized_keys file
    local auth_keys="$ssh_dir/authorized_keys"
    if [ -f "$auth_keys" ]; then
        log_success "✓ authorized_keys file exists"
        TEST_RESULTS["auth_keys"]="success"
        
        # Check permissions
        local auth_perms=$(stat -c %a "$auth_keys")
        if [ "$auth_perms" = "600" ]; then
            log_success "✓ authorized_keys permissions are correct (600)"
            TEST_RESULTS["auth_keys_perms"]="success"
        else
            log_warn "authorized_keys permissions are $auth_perms (should be 600)"
            TEST_RESULTS["auth_keys_perms"]="warning"
        fi
        
        # Check if file has content
        if [ -s "$auth_keys" ]; then
            local key_count=$(wc -l < "$auth_keys")
            log_success "✓ authorized_keys contains $key_count key(s)"
            TEST_RESULTS["auth_keys_content"]="success"
        else
            log_error "✗ authorized_keys file is empty"
            TEST_RESULTS["auth_keys_content"]="failed"
            return $E_CONFIG
        fi
    else
        log_error "✗ authorized_keys file missing: $auth_keys"
        TEST_RESULTS["auth_keys"]="failed"
        return $E_CONFIG
    fi
    
    # Check sudo configuration
    if sudo -l -U "$agent_user" 2>/dev/null | grep -q "NOPASSWD.*ALL"; then
        log_success "✓ User has passwordless sudo access"
        TEST_RESULTS["sudo_access"]="success"
    else
        log_error "✗ User does not have proper sudo access"
        TEST_RESULTS["sudo_access"]="failed"
        return $E_CONFIG
    fi
    
    return 0
}

# Generate comprehensive connection report
generate_connection_report() {
    local report_file="/tmp/jules-endpoint-connection-report-$(date +%s).txt"
    
    log_info "Generating connection diagnostic report: $report_file"
    
    cat > "$report_file" << EOF
Jules Endpoint Agent - Connection Diagnostic Report
==================================================
Generated: $(date)
System: $(uname -a)

Test Results Summary:
--------------------
EOF

    # Add test results
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        local status_symbol=""
        case "$result" in
            "success") status_symbol="✓" ;;
            "failed") status_symbol="✗" ;;
            "warning") status_symbol="⚠" ;;
            "skipped") status_symbol="○" ;;
            *) status_symbol="?" ;;
        esac
        echo "$status_symbol $test_name: $result" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

Detailed System Information:
---------------------------
Network Interfaces:
$(ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "Network interface information not available")

Routing Table:
$(ip route 2>/dev/null || route -n 2>/dev/null || echo "Routing information not available")

DNS Configuration:
$(cat /etc/resolv.conf 2>/dev/null || echo "DNS configuration not available")

SSH Configuration:
$(grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null || echo "SSH configuration not available")

Cloudflared Configuration:
$(cat /etc/cloudflared/config.yml 2>/dev/null || echo "Cloudflared configuration not available")

Service Status:
$(systemctl status ssh cloudflared 2>/dev/null || echo "Service status not available")

Recent Log Entries:
------------------
SSH Logs:
$(journalctl -u ssh --no-pager -n 10 2>/dev/null || echo "SSH logs not available")

Cloudflared Logs:
$(journalctl -u cloudflared --no-pager -n 10 2>/dev/null || echo "Cloudflared logs not available")

Recommendations:
---------------
EOF

    # Add recommendations based on test results
    if [[ "${TEST_RESULTS[ping_8.8.8.8]:-}" == "failed" ]]; then
        echo "- Check internet connectivity and network configuration" >> "$report_file"
    fi
    
    if [[ "${TEST_RESULTS[ssh_running]:-}" == "failed" ]]; then
        echo "- Start SSH service: sudo systemctl start ssh" >> "$report_file"
    fi
    
    if [[ "${TEST_RESULTS[cloudflared_running]:-}" == "failed" ]]; then
        echo "- Configure and start cloudflared tunnel" >> "$report_file"
    fi
    
    if [[ "${TEST_RESULTS[user_exists]:-}" == "failed" ]]; then
        echo "- Create jules user account with proper configuration" >> "$report_file"
    fi
    
    echo "- Review the troubleshooting suggestions in the main error log" >> "$report_file"
    echo "- Consult the Jules Endpoint Agent documentation" >> "$report_file"
    
    log_success "Connection diagnostic report saved to: $report_file"
    echo
    log_info "To view the full report: cat $report_file"
    
    return 0
}

# Main troubleshooting function
run_connection_troubleshooter() {
    local test_category="${1:-all}"
    
    init_troubleshooter
    
    log_info "Starting connection troubleshooting (category: $test_category)..."
    echo
    
    local overall_status=0
    
    # Run tests based on category
    case "$test_category" in
        "network"|"all")
            test_basic_connectivity || overall_status=1
            test_dns_resolution || overall_status=1
            ;;
    esac
    
    case "$test_category" in
        "ssh"|"all")
            test_ssh_service || overall_status=1
            test_user_configuration || overall_status=1
            ;;
    esac
    
    case "$test_category" in
        "tunnel"|"all")
            test_cloudflare_tunnel || overall_status=1
            ;;
    esac
    
    case "$test_category" in
        "integration"|"all")
            test_ssh_through_tunnel || overall_status=1
            ;;
    esac
    
    # Generate comprehensive report
    generate_connection_report
    
    echo
    if [ $overall_status -eq 0 ]; then
        log_success "All connection tests passed!"
    else
        log_warn "Some connection tests failed. Check the report for details."
    fi
    
    return $overall_status
}

# Command line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-all}" in
        "network")
            run_connection_troubleshooter "network"
            ;;
        "ssh")
            run_connection_troubleshooter "ssh"
            ;;
        "tunnel")
            run_connection_troubleshooter "tunnel"
            ;;
        "integration")
            run_connection_troubleshooter "integration"
            ;;
        "all")
            run_connection_troubleshooter "all"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [CATEGORY]"
            echo "Categories: network, ssh, tunnel, integration, all"
            echo "Default: all"
            ;;
        *)
            log_error "Unknown category: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi