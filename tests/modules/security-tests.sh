#!/bin/bash

# Security and User Management Testing Module
# Tests user privileges, SSH security, and access controls

# Security test configuration
SECURITY_TEST_USER="jules"
SECURITY_TEST_TIMEOUT=10

# Security test functions

# Test if jules user exists
test_jules_user_exists() {
    id "$SECURITY_TEST_USER" &>/dev/null
}

# Test if jules user has home directory
test_jules_user_home_directory() {
    local user_home
    user_home=$(eval echo "~$SECURITY_TEST_USER" 2>/dev/null)
    [[ -d "$user_home" ]]
}

# Test if jules user has bash shell
test_jules_user_shell() {
    local user_shell
    user_shell=$(getent passwd "$SECURITY_TEST_USER" | cut -d: -f7)
    [[ "$user_shell" == "/bin/bash" ]]
}

# Test passwordless sudo configuration
test_passwordless_sudo_configuration() {
    local sudoers_file="/etc/sudoers.d/jules-endpoint-agent"
    [[ -f "$sudoers_file" ]] && grep -q "$SECURITY_TEST_USER ALL=(ALL) NOPASSWD:ALL" "$sudoers_file"
}

# Test sudoers file permissions
test_sudoers_file_permissions() {
    local sudoers_file="/etc/sudoers.d/jules-endpoint-agent"
    if [[ -f "$sudoers_file" ]]; then
        local perms
        perms=$(stat -c %a "$sudoers_file")
        [[ "$perms" == "440" ]]
    else
        return 1
    fi
}

# Test sudo access without password (simulation)
test_sudo_access_simulation() {
    # Test if sudo configuration allows passwordless access
    if sudo -l -U "$SECURITY_TEST_USER" 2>/dev/null | grep -q "NOPASSWD: ALL"; then
        return 0
    else
        return 1
    fi
}

# Test SSH directory permissions
test_ssh_directory_permissions() {
    local user_home
    user_home=$(eval echo "~$SECURITY_TEST_USER" 2>/dev/null)
    local ssh_dir="$user_home/.ssh"
    
    if [[ -d "$ssh_dir" ]]; then
        local perms
        perms=$(stat -c %a "$ssh_dir")
        [[ "$perms" == "700" ]]
    else
        return 1
    fi
}

# Test SSH authorized_keys file permissions
test_ssh_authorized_keys_permissions() {
    local user_home
    user_home=$(eval echo "~$SECURITY_TEST_USER" 2>/dev/null)
    local auth_keys_file="$user_home/.ssh/authorized_keys"
    
    if [[ -f "$auth_keys_file" ]]; then
        local perms
        perms=$(stat -c %a "$auth_keys_file")
        [[ "$perms" == "600" ]]
    else
        return 1
    fi
}

# Test SSH authorized_keys file ownership
test_ssh_authorized_keys_ownership() {
    local user_home
    user_home=$(eval echo "~$SECURITY_TEST_USER" 2>/dev/null)
    local auth_keys_file="$user_home/.ssh/authorized_keys"
    
    if [[ -f "$auth_keys_file" ]]; then
        local owner
        owner=$(stat -c %U "$auth_keys_file")
        [[ "$owner" == "$SECURITY_TEST_USER" ]]
    else
        return 1
    fi
}

# Test SSH key format in authorized_keys
test_ssh_key_format_in_authorized_keys() {
    local user_home
    user_home=$(eval echo "~$SECURITY_TEST_USER" 2>/dev/null)
    local auth_keys_file="$user_home/.ssh/authorized_keys"
    
    if [[ -f "$auth_keys_file" ]]; then
        # Check if file contains valid SSH key format
        grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ' "$auth_keys_file"
    else
        return 1
    fi
}

# Test SSH server configuration security
test_ssh_server_security_config() {
    local sshd_config="/etc/ssh/sshd_config"
    
    # Check critical security settings
    if [[ -f "$sshd_config" ]]; then
        grep -q "PermitRootLogin no" "$sshd_config" && \
        grep -q "PasswordAuthentication no" "$sshd_config" && \
        grep -q "PubkeyAuthentication yes" "$sshd_config"
    else
        return 1
    fi
}

# Test SSH service is running
test_ssh_service_running() {
    systemctl is-active --quiet ssh
}

# Test SSH service is enabled
test_ssh_service_enabled() {
    systemctl is-enabled --quiet ssh
}

# Test user can access system resources (file system permissions)
test_user_system_access() {
    local user_home
    user_home=$(eval echo "~$SECURITY_TEST_USER" 2>/dev/null)
    
    # Test if user can read common system directories
    [[ -r "/etc" ]] && [[ -r "/var" ]] && [[ -r "/tmp" ]] && [[ -r "$user_home" ]]
}

# Test security hardening is applied
test_ssh_security_hardening_applied() {
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ -f "$sshd_config" ]]; then
        # Check if our security hardening section exists
        grep -q "Jules Endpoint Agent SSH Security Hardening" "$sshd_config"
    else
        return 1
    fi
}

# Test SSH host keys exist and have proper permissions
test_ssh_host_keys_security() {
    local host_keys=(
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_ecdsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
    )
    
    for key in "${host_keys[@]}"; do
        if [[ -f "$key" ]]; then
            local perms
            perms=$(stat -c %a "$key")
            if [[ "$perms" != "600" ]]; then
                return 1
            fi
        fi
    done
    
    return 0
}

# Test that weak SSH algorithms are disabled
test_ssh_weak_algorithms_disabled() {
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ -f "$sshd_config" ]]; then
        # Check that DSS keys are not allowed (should not find ssh-dss)
        ! grep -q "ssh-dss" "$sshd_config"
    else
        return 1
    fi
}

# Test SSH connection limits are configured
test_ssh_connection_limits() {
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ -f "$sshd_config" ]]; then
        grep -q "MaxAuthTries" "$sshd_config" && \
        grep -q "MaxSessions" "$sshd_config" && \
        grep -q "ClientAliveInterval" "$sshd_config"
    else
        return 1
    fi
}

# Test user privilege escalation works
test_user_privilege_escalation() {
    # This is a simulation test - we check if the configuration allows it
    # without actually running commands as the user
    local sudoers_file="/etc/sudoers.d/jules-endpoint-agent"
    
    if [[ -f "$sudoers_file" ]]; then
        # Check if user has NOPASSWD sudo access
        grep -q "$SECURITY_TEST_USER.*NOPASSWD.*ALL" "$sudoers_file"
    else
        return 1
    fi
}

# Test system logging for SSH is configured
test_ssh_logging_configured() {
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ -f "$sshd_config" ]]; then
        # Check if logging is configured
        grep -q "LogLevel" "$sshd_config" && \
        grep -q "SyslogFacility" "$sshd_config"
    else
        return 1
    fi
}

# Function to list security tests
list_security_tests() {
    echo "  - Jules user exists"
    echo "  - Jules user home directory"
    echo "  - Jules user shell configuration"
    echo "  - Passwordless sudo configuration"
    echo "  - Sudoers file permissions"
    echo "  - Sudo access simulation"
    echo "  - SSH directory permissions"
    echo "  - SSH authorized_keys permissions"
    echo "  - SSH authorized_keys ownership"
    echo "  - SSH key format validation"
    echo "  - SSH server security configuration"
    echo "  - SSH service running"
    echo "  - SSH service enabled"
    echo "  - User system access"
    echo "  - SSH security hardening applied"
    echo "  - SSH host keys security"
    echo "  - SSH weak algorithms disabled"
    echo "  - SSH connection limits"
    echo "  - User privilege escalation"
    echo "  - SSH logging configured"
}

# Main security test runner
run_security_tests() {
    local pattern="${1:-.*}"
    
    log_category "Security and User Management"
    
    # User Management Tests
    run_test "Jules user exists" "test_jules_user_exists"
    run_test "Jules user home directory" "test_jules_user_home_directory"
    run_test "Jules user shell configuration" "test_jules_user_shell"
    
    # Sudo Configuration Tests
    run_test "Passwordless sudo configuration" "test_passwordless_sudo_configuration"
    run_test "Sudoers file permissions" "test_sudoers_file_permissions"
    run_test "Sudo access simulation" "test_sudo_access_simulation"
    
    # SSH Security Tests
    run_test "SSH directory permissions" "test_ssh_directory_permissions"
    run_test "SSH authorized_keys permissions" "test_ssh_authorized_keys_permissions"
    run_test "SSH authorized_keys ownership" "test_ssh_authorized_keys_ownership"
    run_test "SSH key format validation" "test_ssh_key_format_in_authorized_keys"
    
    # SSH Server Security Tests
    run_test "SSH server security configuration" "test_ssh_server_security_config"
    run_test "SSH service running" "test_ssh_service_running"
    run_test "SSH service enabled" "test_ssh_service_enabled"
    run_test "SSH security hardening applied" "test_ssh_security_hardening_applied"
    run_test "SSH host keys security" "test_ssh_host_keys_security"
    run_test "SSH weak algorithms disabled" "test_ssh_weak_algorithms_disabled"
    run_test "SSH connection limits" "test_ssh_connection_limits"
    run_test "SSH logging configured" "test_ssh_logging_configured"
    
    # System Access Tests
    run_test "User system access" "test_user_system_access"
    run_test "User privilege escalation" "test_user_privilege_escalation"
}