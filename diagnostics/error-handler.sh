#!/bin/bash

# Enhanced Error Handling and Diagnostics Module
# Provides comprehensive error messages, troubleshooting utilities, and system health checks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Error codes (only define if not already set)
if [ -z "${E_SUCCESS:-}" ]; then
    readonly E_SUCCESS=0
    readonly E_GENERAL=1
    readonly E_MISUSE=2
    readonly E_PERMISSION=3
    readonly E_NETWORK=4
    readonly E_SERVICE=5
    readonly E_CONFIG=6
    readonly E_DEPENDENCY=7
    readonly E_TIMEOUT=8
    readonly E_AUTH=9
    readonly E_RESOURCE=10
fi

# Logging configuration
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-/tmp/jules-endpoint-diagnostics.log}"
ENABLE_SYSLOG="${ENABLE_SYSLOG:-false}"

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize log file with header
    if [ ! -f "$LOG_FILE" ]; then
        echo "Jules Endpoint Agent - Diagnostics Log - $(date)" > "$LOG_FILE"
        echo "=======================================================" >> "$LOG_FILE"
    fi
    
    # Set up syslog if enabled
    if [ "$ENABLE_SYSLOG" = "true" ] && command -v logger &> /dev/null; then
        logger -t "jules-endpoint" "Diagnostics module initialized"
    fi
}

# Enhanced logging functions with levels
log_debug() {
    [ "$LOG_LEVEL" = "DEBUG" ] && _log "DEBUG" "$1" "${CYAN}"
}

log_info() {
    [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO)$ ]] && _log "INFO" "$1" "${BLUE}"
}

log_warn() {
    [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO|WARN)$ ]] && _log "WARN" "$1" "${YELLOW}"
}

log_error() {
    _log "ERROR" "$1" "${RED}"
}

log_success() {
    [[ "$LOG_LEVEL" =~ ^(DEBUG|INFO|WARN|SUCCESS)$ ]] && _log "SUCCESS" "$1" "${GREEN}"
}

log_critical() {
    _log "CRITICAL" "$1" "${PURPLE}"
}

# Internal logging function
_log() {
    local level="$1"
    local message="$2"
    local color="${3:-$NC}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Console output with color
    echo -e "${color}[$level]${NC} $message"
    
    # File output without color
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Syslog output if enabled
    if [ "$ENABLE_SYSLOG" = "true" ] && command -v logger &> /dev/null; then
        logger -t "jules-endpoint" -p "user.$level" "$message"
    fi
}

# Error context tracking
declare -A ERROR_CONTEXT
ERROR_CONTEXT[operation]=""
ERROR_CONTEXT[component]=""
ERROR_CONTEXT[user]=""
ERROR_CONTEXT[timestamp]=""

# Set error context
set_error_context() {
    local key="$1"
    local value="$2"
    ERROR_CONTEXT[$key]="$value"
    ERROR_CONTEXT[timestamp]=$(date '+%Y-%m-%d %H:%M:%S')
}

# Get error context
get_error_context() {
    local context_info=""
    for key in "${!ERROR_CONTEXT[@]}"; do
        if [ -n "${ERROR_CONTEXT[$key]}" ]; then
            context_info="$context_info$key=${ERROR_CONTEXT[$key]} "
        fi
    done
    echo "$context_info"
}

# Enhanced error handler with context and suggestions
handle_error() {
    local exit_code="$1"
    local error_message="$2"
    local component="${3:-unknown}"
    local operation="${4:-unknown}"
    
    set_error_context "component" "$component"
    set_error_context "operation" "$operation"
    
    log_error "Error in $component during $operation: $error_message"
    log_error "Context: $(get_error_context)"
    
    # Provide specific error handling based on exit code
    case $exit_code in
        $E_PERMISSION)
            handle_permission_error "$error_message" "$component"
            ;;
        $E_NETWORK)
            handle_network_error "$error_message" "$component"
            ;;
        $E_SERVICE)
            handle_service_error "$error_message" "$component"
            ;;
        $E_CONFIG)
            handle_config_error "$error_message" "$component"
            ;;
        $E_DEPENDENCY)
            handle_dependency_error "$error_message" "$component"
            ;;
        $E_TIMEOUT)
            handle_timeout_error "$error_message" "$component"
            ;;
        $E_AUTH)
            handle_auth_error "$error_message" "$component"
            ;;
        $E_RESOURCE)
            handle_resource_error "$error_message" "$component"
            ;;
        *)
            handle_general_error "$error_message" "$component"
            ;;
    esac
    
    # Generate troubleshooting report
    generate_troubleshooting_report "$exit_code" "$error_message" "$component"
    
    return $exit_code
}

# Specific error handlers with troubleshooting suggestions
handle_permission_error() {
    local message="$1"
    local component="$2"
    
    log_error "Permission Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    log_error "  Current User: $(whoami)"
    log_error "  Current UID: $(id -u)"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Ensure you're running with appropriate privileges (sudo if needed)"
    log_warn "2. Check file/directory permissions: ls -la"
    log_warn "3. Verify user is in required groups: groups \$(whoami)"
    log_warn "4. Check SELinux/AppArmor policies if applicable"
    
    if [ "$component" = "ssh" ]; then
        log_warn "5. SSH-specific: Check ~/.ssh directory permissions (700)"
        log_warn "6. SSH-specific: Check authorized_keys permissions (600)"
    fi
}

handle_network_error() {
    local message="$1"
    local component="$2"
    
    log_error "Network Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Check internet connectivity: ping 8.8.8.8"
    log_warn "2. Verify DNS resolution: nslookup google.com"
    log_warn "3. Check firewall settings: sudo ufw status"
    log_warn "4. Test specific ports: telnet <host> <port>"
    
    if [ "$component" = "cloudflared" ]; then
        log_warn "5. Cloudflare-specific: Check tunnel status: cloudflared tunnel list"
        log_warn "6. Cloudflare-specific: Verify token validity"
        log_warn "7. Cloudflare-specific: Check Cloudflare service status"
    fi
}

handle_service_error() {
    local message="$1"
    local component="$2"
    
    log_error "Service Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Check service status: systemctl status $component"
    log_warn "2. View service logs: journalctl -u $component -f"
    log_warn "3. Restart service: sudo systemctl restart $component"
    log_warn "4. Check service configuration files"
    log_warn "5. Verify service dependencies are running"
}

handle_config_error() {
    local message="$1"
    local component="$2"
    
    log_error "Configuration Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Validate configuration file syntax"
    log_warn "2. Check for missing required parameters"
    log_warn "3. Verify file paths and permissions"
    log_warn "4. Compare with working configuration examples"
    log_warn "5. Check for conflicting settings"
    
    if [ "$component" = "ssh" ]; then
        log_warn "6. SSH-specific: Test config: sudo sshd -t"
        log_warn "7. SSH-specific: Check /etc/ssh/sshd_config"
    elif [ "$component" = "cloudflared" ]; then
        log_warn "6. Cloudflare-specific: Validate YAML syntax"
        log_warn "7. Cloudflare-specific: Check tunnel credentials"
    fi
}

handle_dependency_error() {
    local message="$1"
    local component="$2"
    
    log_error "Dependency Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Update package lists: sudo apt update"
    log_warn "2. Install missing dependencies: sudo apt install <package>"
    log_warn "3. Check package availability: apt search <package>"
    log_warn "4. Verify system architecture compatibility"
    log_warn "5. Check for broken packages: sudo apt --fix-broken install"
}

handle_timeout_error() {
    local message="$1"
    local component="$2"
    
    log_error "Timeout Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Check network connectivity and latency"
    log_warn "2. Increase timeout values if appropriate"
    log_warn "3. Verify target service is responsive"
    log_warn "4. Check for network congestion or filtering"
    log_warn "5. Try operation during off-peak hours"
}

handle_auth_error() {
    local message="$1"
    local component="$2"
    
    log_error "Authentication Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Verify credentials are correct and current"
    log_warn "2. Check for expired tokens or certificates"
    log_warn "3. Ensure proper key format and permissions"
    log_warn "4. Verify user account exists and is active"
    log_warn "5. Check authentication service availability"
    
    if [ "$component" = "ssh" ]; then
        log_warn "6. SSH-specific: Test key: ssh-keygen -l -f <keyfile>"
        log_warn "7. SSH-specific: Check authorized_keys format"
    elif [ "$component" = "cloudflared" ]; then
        log_warn "6. Cloudflare-specific: Re-authenticate: cloudflared tunnel login"
        log_warn "7. Cloudflare-specific: Check account permissions"
    fi
}

handle_resource_error() {
    local message="$1"
    local component="$2"
    
    log_error "Resource Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "Troubleshooting Suggestions:"
    log_warn "1. Check available disk space: df -h"
    log_warn "2. Check memory usage: free -h"
    log_warn "3. Check CPU usage: top or htop"
    log_warn "4. Clean up temporary files: sudo apt autoremove"
    log_warn "5. Check for resource limits: ulimit -a"
}

handle_general_error() {
    local message="$1"
    local component="$2"
    
    log_error "General Error Details:"
    log_error "  Component: $component"
    log_error "  Message: $message"
    
    echo
    log_warn "General Troubleshooting Suggestions:"
    log_warn "1. Check system logs: journalctl -xe"
    log_warn "2. Verify system requirements are met"
    log_warn "3. Try running with verbose output"
    log_warn "4. Check for recent system changes"
    log_warn "5. Consult documentation and known issues"
}

# Generate comprehensive troubleshooting report
generate_troubleshooting_report() {
    local exit_code="$1"
    local error_message="$2"
    local component="$3"
    local report_file="/tmp/jules-endpoint-troubleshooting-$(date +%s).txt"
    
    log_info "Generating troubleshooting report: $report_file"
    
    cat > "$report_file" << EOF
Jules Endpoint Agent - Troubleshooting Report
============================================
Generated: $(date)
Error Code: $exit_code
Component: $component
Error Message: $error_message
Context: $(get_error_context)

System Information:
------------------
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
User: $(whoami)
UID: $(id -u)
Groups: $(groups)

Service Status:
--------------
SSH Service: $(systemctl is-active ssh 2>/dev/null || echo "not available")
Cloudflared Service: $(systemctl is-active cloudflared 2>/dev/null || echo "not available")

Network Information:
-------------------
IP Address: $(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
DNS Servers: $(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\n' ' ')
Internet Connectivity: $(ping -c 1 8.8.8.8 &>/dev/null && echo "OK" || echo "FAILED")

Resource Usage:
--------------
Disk Space: $(df -h / | tail -1 | awk '{print $4 " available"}')
Memory: $(free -h | grep Mem | awk '{print $7 " available"}')
Load Average: $(uptime | awk -F'load average:' '{print $2}')

Recent Log Entries:
------------------
$(tail -20 "$LOG_FILE" 2>/dev/null || echo "No log entries available")

Recommended Actions:
-------------------
1. Review the error-specific troubleshooting suggestions above
2. Check the system requirements and dependencies
3. Verify network connectivity and firewall settings
4. Consult the documentation for your specific use case
5. If the issue persists, provide this report when seeking support

EOF

    log_success "Troubleshooting report saved to: $report_file"
    echo
    log_info "To view the full report: cat $report_file"
}

# Initialize logging when module is sourced
init_logging

# Export functions for use by other scripts
export -f log_debug log_info log_warn log_error log_success log_critical
export -f handle_error set_error_context get_error_context
export -f generate_troubleshooting_report