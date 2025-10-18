#!/bin/bash

# SSH Security Hardening Module
# Implements comprehensive SSH security configurations

set -euo pipefail

# Function to apply SSH security hardening
apply_ssh_security_hardening() {
    local sshd_config_file="${1:-/etc/ssh/sshd_config}"
    local backup_suffix="$(date +%Y%m%d_%H%M%S)"
    
    echo "INFO: Applying SSH security hardening to $sshd_config_file"
    
    # Create backup of original configuration
    if [[ ! -f "$sshd_config_file.backup" ]]; then
        cp "$sshd_config_file" "$sshd_config_file.backup"
        echo "INFO: Created backup of SSH configuration at $sshd_config_file.backup"
    fi
    
    # Create additional timestamped backup
    cp "$sshd_config_file" "$sshd_config_file.backup.$backup_suffix"
    
    # Apply security hardening configurations
    cat >> "$sshd_config_file" << 'EOF'

# Jules Endpoint Agent SSH Security Hardening
# Added by jules-endpoint-agent security hardening module

# Authentication Security
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes

# Connection Security
Protocol 2
Port 22
AddressFamily any
ListenAddress 0.0.0.0

# Session Security
PermitEmptyPasswords no
PermitUserEnvironment no
AllowAgentForwarding yes
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes

# Timing and Connection Limits
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
MaxAuthTries 3
MaxSessions 10
MaxStartups 10:30:100

# Logging and Monitoring
LogLevel VERBOSE
SyslogFacility AUTH

# Cryptographic Security
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256

# Host Key Security
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Banner and MOTD
Banner none
PrintMotd no
PrintLastLog yes

# Environment and Locale
AcceptEnv LANG LC_*

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server

# Jules-specific user restrictions
Match User jules
    AllowAgentForwarding yes
    AllowTcpForwarding yes
    X11Forwarding yes
    PermitTTY yes
    ForceCommand none
EOF

    echo "SUCCESS: SSH security hardening configuration applied"
}

# Function to validate SSH configuration
validate_ssh_configuration() {
    local sshd_config_file="${1:-/etc/ssh/sshd_config}"
    
    echo "INFO: Validating SSH configuration"
    
    # Test SSH configuration syntax
    if ! /usr/sbin/sshd -t -f "$sshd_config_file"; then
        echo "ERROR: SSH configuration test failed"
        return 1
    fi
    
    echo "SUCCESS: SSH configuration syntax is valid"
    
    # Check for security-critical settings
    local security_checks=(
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "PermitEmptyPasswords no"
        "Protocol 2"
    )
    
    for check in "${security_checks[@]}"; do
        local setting=$(echo "$check" | cut -d' ' -f1)
        local expected_value=$(echo "$check" | cut -d' ' -f2-)
        
        if grep -q "^$setting $expected_value" "$sshd_config_file"; then
            echo "SUCCESS: $setting is correctly set to $expected_value"
        else
            echo "WARNING: $setting may not be set to $expected_value"
        fi
    done
    
    return 0
}

# Function to generate SSH host keys with proper security
generate_secure_host_keys() {
    echo "INFO: Generating secure SSH host keys"
    
    # Remove any existing weak keys
    rm -f /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_dsa_key.pub
    
    # Generate strong host keys
    if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
        ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" -C "$(hostname)-rsa-$(date +%Y%m%d)"
        echo "INFO: Generated RSA host key (4096 bits)"
    fi
    
    if [[ ! -f /etc/ssh/ssh_host_ecdsa_key ]]; then
        ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -N "" -C "$(hostname)-ecdsa-$(date +%Y%m%d)"
        echo "INFO: Generated ECDSA host key (521 bits)"
    fi
    
    if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -C "$(hostname)-ed25519-$(date +%Y%m%d)"
        echo "INFO: Generated Ed25519 host key"
    fi
    
    # Set proper permissions on host keys
    chmod 600 /etc/ssh/ssh_host_*_key
    chmod 644 /etc/ssh/ssh_host_*_key.pub
    chown root:root /etc/ssh/ssh_host_*_key*
    
    echo "SUCCESS: SSH host keys generated and secured"
}

# Function to configure SSH logging and monitoring
configure_ssh_monitoring() {
    echo "INFO: Configuring SSH logging and monitoring"
    
    # Ensure rsyslog is configured for SSH logging
    if [[ -f /etc/rsyslog.conf ]]; then
        if ! grep -q "auth,authpriv" /etc/rsyslog.conf; then
            echo "auth,authpriv.*                 /var/log/auth.log" >> /etc/rsyslog.conf
            systemctl restart rsyslog 2>/dev/null || true
        fi
    fi
    
    # Create SSH monitoring script
    cat > /usr/local/bin/ssh-monitor.sh << 'EOF'
#!/bin/bash
# SSH Connection Monitor
# Logs SSH connection attempts and active sessions

LOG_FILE="/var/log/ssh-monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Log current SSH sessions
active_sessions=$(who | grep -c "pts/" || echo "0")
log_message "Active SSH sessions: $active_sessions"

# Log recent SSH connections from auth.log
if [[ -f /var/log/auth.log ]]; then
    recent_connections=$(tail -n 100 /var/log/auth.log | grep "sshd.*Accepted" | tail -n 5)
    if [[ -n "$recent_connections" ]]; then
        log_message "Recent SSH connections:"
        echo "$recent_connections" >> "$LOG_FILE"
    fi
fi
EOF
    
    chmod +x /usr/local/bin/ssh-monitor.sh
    
    # Create systemd timer for SSH monitoring (optional)
    cat > /etc/systemd/system/ssh-monitor.timer << 'EOF'
[Unit]
Description=SSH Connection Monitor Timer
Requires=ssh-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/ssh-monitor.service << 'EOF'
[Unit]
Description=SSH Connection Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ssh-monitor.sh
User=root
EOF

    echo "SUCCESS: SSH monitoring configured"
}

# Function to apply fail2ban configuration for SSH protection
configure_ssh_fail2ban() {
    echo "INFO: Configuring fail2ban for SSH protection"
    
    # Check if fail2ban is available
    if ! command -v fail2ban-client &> /dev/null; then
        echo "WARNING: fail2ban not installed. Consider installing for additional SSH protection"
        return 0
    fi
    
    # Create SSH jail configuration
    cat > /etc/fail2ban/jail.d/ssh-jules.conf << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
ignoreip = 127.0.0.1/8 ::1
EOF

    # Restart fail2ban to apply configuration
    systemctl restart fail2ban 2>/dev/null || true
    
    echo "SUCCESS: fail2ban configured for SSH protection"
}

# Main function to apply all SSH security hardening
apply_comprehensive_ssh_hardening() {
    echo "INFO: Starting comprehensive SSH security hardening"
    
    # Generate secure host keys
    generate_secure_host_keys
    
    # Apply SSH configuration hardening
    apply_ssh_security_hardening
    
    # Validate configuration
    if ! validate_ssh_configuration; then
        echo "ERROR: SSH configuration validation failed"
        return 1
    fi
    
    # Configure monitoring
    configure_ssh_monitoring
    
    # Configure fail2ban if available
    configure_ssh_fail2ban
    
    # Restart SSH service to apply changes
    echo "INFO: Restarting SSH service to apply security hardening"
    if systemctl restart ssh; then
        echo "SUCCESS: SSH service restarted successfully"
    else
        echo "ERROR: Failed to restart SSH service"
        return 1
    fi
    
    # Verify SSH service is running
    if systemctl is-active --quiet ssh; then
        echo "SUCCESS: SSH service is active and running"
    else
        echo "ERROR: SSH service failed to start after hardening"
        return 1
    fi
    
    echo "SUCCESS: Comprehensive SSH security hardening completed"
    return 0
}

# Export functions for use in other scripts
export -f apply_ssh_security_hardening
export -f validate_ssh_configuration
export -f generate_secure_host_keys
export -f configure_ssh_monitoring
export -f configure_ssh_fail2ban
export -f apply_comprehensive_ssh_hardening