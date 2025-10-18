#!/bin/bash

# System Health Check Script
# Provides comprehensive system health monitoring and diagnostics

set -euo pipefail

# Source error handler
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error-handler.sh"

# Health check configuration
HEALTH_CHECK_INTERVAL=60
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_LOAD=5.0
MIN_FREE_DISK_GB=1

# Health status tracking
declare -A HEALTH_STATUS
declare -A HEALTH_METRICS
declare -A HEALTH_HISTORY

# Initialize health monitoring
init_health_monitor() {
    log_info "Initializing system health monitor..."
    set_error_context "component" "health-monitor"
    
    # Create health status directory
    local health_dir="/tmp/jules-endpoint-health"
    mkdir -p "$health_dir"
    
    # Initialize status tracking
    HEALTH_STATUS[overall]="unknown"
    HEALTH_STATUS[cpu]="unknown"
    HEALTH_STATUS[memory]="unknown"
    HEALTH_STATUS[disk]="unknown"
    HEALTH_STATUS[network]="unknown"
    HEALTH_STATUS[services]="unknown"
    
    log_success "Health monitor initialized"
}

# Check CPU usage and load
check_cpu_health() {
    log_debug "Checking CPU health..."
    set_error_context "operation" "cpu-health-check"
    
    # Get CPU usage (average over 1 second)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    if [[ ! "$cpu_usage" =~ ^[0-9.]+$ ]]; then
        cpu_usage=0
    fi
    
    # Get load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || echo "0")
    if [[ ! "$load_avg" =~ ^[0-9.]+$ ]]; then
        load_avg=0
    fi
    
    # Get number of CPU cores
    local cpu_cores=$(nproc)
    
    # Store metrics
    HEALTH_METRICS[cpu_usage]="$cpu_usage"
    HEALTH_METRICS[load_avg]="$load_avg"
    HEALTH_METRICS[cpu_cores]="$cpu_cores"
    
    # Evaluate CPU health
    local cpu_status="healthy"
    local cpu_issues=()
    
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        cpu_status="warning"
        cpu_issues+=("High CPU usage: ${cpu_usage}%")
    fi
    
    if (( $(echo "$load_avg > $ALERT_THRESHOLD_LOAD" | bc -l) )); then
        cpu_status="critical"
        cpu_issues+=("High load average: $load_avg")
    fi
    
    HEALTH_STATUS[cpu]="$cpu_status"
    
    if [ ${#cpu_issues[@]} -gt 0 ]; then
        log_warn "CPU health issues detected: ${cpu_issues[*]}"
    else
        log_success "CPU health: OK (Usage: ${cpu_usage}%, Load: $load_avg)"
    fi
    
    return 0
}

# Check memory usage
check_memory_health() {
    log_debug "Checking memory health..."
    set_error_context "operation" "memory-health-check"
    
    # Get memory information
    local mem_info=$(free -m)
    local total_mem=$(echo "$mem_info" | awk 'NR==2{print $2}')
    local used_mem=$(echo "$mem_info" | awk 'NR==2{print $3}')
    local free_mem=$(echo "$mem_info" | awk 'NR==2{print $4}')
    local available_mem=$(echo "$mem_info" | awk 'NR==2{print $7}' || echo "$free_mem")
    
    # Calculate usage percentage
    local mem_usage_pct=$((used_mem * 100 / total_mem))
    
    # Store metrics
    HEALTH_METRICS[total_memory]="$total_mem"
    HEALTH_METRICS[used_memory]="$used_mem"
    HEALTH_METRICS[free_memory]="$free_mem"
    HEALTH_METRICS[available_memory]="$available_mem"
    HEALTH_METRICS[memory_usage_pct]="$mem_usage_pct"
    
    # Evaluate memory health
    local mem_status="healthy"
    local mem_issues=()
    
    if [ $mem_usage_pct -gt $ALERT_THRESHOLD_MEMORY ]; then
        mem_status="warning"
        mem_issues+=("High memory usage: ${mem_usage_pct}%")
    fi
    
    if [ $available_mem -lt 100 ]; then  # Less than 100MB available
        mem_status="critical"
        mem_issues+=("Very low available memory: ${available_mem}MB")
    fi
    
    HEALTH_STATUS[memory]="$mem_status"
    
    if [ ${#mem_issues[@]} -gt 0 ]; then
        log_warn "Memory health issues detected: ${mem_issues[*]}"
    else
        log_success "Memory health: OK (Usage: ${mem_usage_pct}%, Available: ${available_mem}MB)"
    fi
    
    return 0
}

# Check disk usage
check_disk_health() {
    log_debug "Checking disk health..."
    set_error_context "operation" "disk-health-check"
    
    # Get disk usage for root filesystem
    local disk_info=$(df -h / | tail -1)
    local total_disk=$(echo "$disk_info" | awk '{print $2}')
    local used_disk=$(echo "$disk_info" | awk '{print $3}')
    local available_disk=$(echo "$disk_info" | awk '{print $4}')
    local usage_pct=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    
    # Convert available disk to GB for comparison
    local available_gb=$(echo "$available_disk" | sed 's/G//' | sed 's/M/0.001*/' | bc -l 2>/dev/null || echo "0")
    
    # Store metrics
    HEALTH_METRICS[total_disk]="$total_disk"
    HEALTH_METRICS[used_disk]="$used_disk"
    HEALTH_METRICS[available_disk]="$available_disk"
    HEALTH_METRICS[disk_usage_pct]="$usage_pct"
    
    # Evaluate disk health
    local disk_status="healthy"
    local disk_issues=()
    
    if [ "$usage_pct" -gt $ALERT_THRESHOLD_DISK ]; then
        disk_status="warning"
        disk_issues+=("High disk usage: ${usage_pct}%")
    fi
    
    if (( $(echo "$available_gb < $MIN_FREE_DISK_GB" | bc -l) )); then
        disk_status="critical"
        disk_issues+=("Very low disk space: $available_disk available")
    fi
    
    HEALTH_STATUS[disk]="$disk_status"
    
    if [ ${#disk_issues[@]} -gt 0 ]; then
        log_warn "Disk health issues detected: ${disk_issues[*]}"
    else
        log_success "Disk health: OK (Usage: ${usage_pct}%, Available: $available_disk)"
    fi
    
    return 0
}

# Check network health
check_network_health() {
    log_debug "Checking network health..."
    set_error_context "operation" "network-health-check"
    
    local network_status="healthy"
    local network_issues=()
    
    # Test basic connectivity
    local connectivity_count=0
    local test_hosts=("8.8.8.8" "1.1.1.1")
    
    for host in "${test_hosts[@]}"; do
        if timeout 5 ping -c 1 "$host" &>/dev/null; then
            ((connectivity_count++))
        fi
    done
    
    HEALTH_METRICS[connectivity_hosts]="$connectivity_count/${#test_hosts[@]}"
    
    if [ $connectivity_count -eq 0 ]; then
        network_status="critical"
        network_issues+=("No internet connectivity")
    elif [ $connectivity_count -lt ${#test_hosts[@]} ]; then
        network_status="warning"
        network_issues+=("Partial connectivity issues")
    fi
    
    # Check DNS resolution
    if timeout 5 nslookup google.com &>/dev/null; then
        HEALTH_METRICS[dns_resolution]="working"
    else
        network_status="warning"
        network_issues+=("DNS resolution issues")
        HEALTH_METRICS[dns_resolution]="failed"
    fi
    
    # Check network interfaces
    local active_interfaces=$(ip link show up | grep -c "state UP" || echo "0")
    HEALTH_METRICS[active_interfaces]="$active_interfaces"
    
    if [ $active_interfaces -eq 0 ]; then
        network_status="critical"
        network_issues+=("No active network interfaces")
    fi
    
    HEALTH_STATUS[network]="$network_status"
    
    if [ ${#network_issues[@]} -gt 0 ]; then
        log_warn "Network health issues detected: ${network_issues[*]}"
    else
        log_success "Network health: OK (Connectivity: ${connectivity_count}/${#test_hosts[@]}, DNS: working)"
    fi
    
    return 0
}

# Check service health
check_service_health() {
    log_debug "Checking service health..."
    set_error_context "operation" "service-health-check"
    
    local service_status="healthy"
    local service_issues=()
    
    # Check SSH service
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        HEALTH_METRICS[ssh_service]="running"
        log_debug "SSH service is running"
    else
        service_status="critical"
        service_issues+=("SSH service not running")
        HEALTH_METRICS[ssh_service]="stopped"
    fi
    
    # Check cloudflared service
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        HEALTH_METRICS[cloudflared_service]="running"
        log_debug "Cloudflared service is running"
    else
        service_status="warning"
        service_issues+=("Cloudflared service not running")
        HEALTH_METRICS[cloudflared_service]="stopped"
    fi
    
    # Check if services are enabled
    if systemctl is-enabled --quiet ssh 2>/dev/null || systemctl is-enabled --quiet sshd 2>/dev/null; then
        HEALTH_METRICS[ssh_enabled]="enabled"
    else
        service_status="warning"
        service_issues+=("SSH service not enabled for startup")
        HEALTH_METRICS[ssh_enabled]="disabled"
    fi
    
    if systemctl is-enabled --quiet cloudflared 2>/dev/null; then
        HEALTH_METRICS[cloudflared_enabled]="enabled"
    else
        service_status="warning"
        service_issues+=("Cloudflared service not enabled for startup")
        HEALTH_METRICS[cloudflared_enabled]="disabled"
    fi
    
    HEALTH_STATUS[services]="$service_status"
    
    if [ ${#service_issues[@]} -gt 0 ]; then
        log_warn "Service health issues detected: ${service_issues[*]}"
    else
        log_success "Service health: OK (SSH: running, Cloudflared: running)"
    fi
    
    return 0
}

# Check security status
check_security_health() {
    log_debug "Checking security health..."
    set_error_context "operation" "security-health-check"
    
    local security_status="healthy"
    local security_issues=()
    
    # Check if running as root (security concern)
    if [ "$(id -u)" -eq 0 ]; then
        security_status="warning"
        security_issues+=("Running as root user")
        HEALTH_METRICS[running_as_root]="yes"
    else
        HEALTH_METRICS[running_as_root]="no"
    fi
    
    # Check SSH configuration security
    if [ -f "/etc/ssh/sshd_config" ]; then
        # Check if root login is disabled
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            HEALTH_METRICS[ssh_root_login]="disabled"
        else
            security_status="warning"
            security_issues+=("SSH root login not explicitly disabled")
            HEALTH_METRICS[ssh_root_login]="enabled_or_default"
        fi
        
        # Check if password authentication is disabled
        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            HEALTH_METRICS[ssh_password_auth]="disabled"
        else
            security_status="warning"
            security_issues+=("SSH password authentication not disabled")
            HEALTH_METRICS[ssh_password_auth]="enabled_or_default"
        fi
    fi
    
    # Check for failed login attempts
    local failed_logins=$(journalctl -u ssh --since "1 hour ago" 2>/dev/null | grep -c "Failed password" || echo "0")
    HEALTH_METRICS[failed_ssh_logins]="$failed_logins"
    
    if [ "$failed_logins" -gt 10 ]; then
        security_status="warning"
        security_issues+=("High number of failed SSH login attempts: $failed_logins")
    fi
    
    # Check firewall status
    if command -v ufw &>/dev/null; then
        local ufw_status=$(ufw status | head -1 | awk '{print $2}' || echo "unknown")
        HEALTH_METRICS[firewall_status]="$ufw_status"
        
        if [ "$ufw_status" = "inactive" ]; then
            security_status="warning"
            security_issues+=("Firewall is inactive")
        fi
    else
        HEALTH_METRICS[firewall_status]="not_installed"
    fi
    
    HEALTH_STATUS[security]="$security_status"
    
    if [ ${#security_issues[@]} -gt 0 ]; then
        log_warn "Security health issues detected: ${security_issues[*]}"
    else
        log_success "Security health: OK"
    fi
    
    return 0
}

# Calculate overall health status
calculate_overall_health() {
    log_debug "Calculating overall health status..."
    
    local critical_count=0
    local warning_count=0
    local healthy_count=0
    
    for component in "${!HEALTH_STATUS[@]}"; do
        if [ "$component" = "overall" ]; then
            continue
        fi
        
        case "${HEALTH_STATUS[$component]}" in
            "critical")
                ((critical_count++))
                ;;
            "warning")
                ((warning_count++))
                ;;
            "healthy")
                ((healthy_count++))
                ;;
        esac
    done
    
    # Determine overall status
    if [ $critical_count -gt 0 ]; then
        HEALTH_STATUS[overall]="critical"
    elif [ $warning_count -gt 0 ]; then
        HEALTH_STATUS[overall]="warning"
    else
        HEALTH_STATUS[overall]="healthy"
    fi
    
    log_info "Overall health: ${HEALTH_STATUS[overall]} (Critical: $critical_count, Warning: $warning_count, Healthy: $healthy_count)"
}

# Generate health report
generate_health_report() {
    local report_file="/tmp/jules-endpoint-health-report-$(date +%s).txt"
    
    log_info "Generating system health report: $report_file"
    
    cat > "$report_file" << EOF
Jules Endpoint Agent - System Health Report
==========================================
Generated: $(date)
Overall Status: ${HEALTH_STATUS[overall]^^}

Component Health Status:
-----------------------
CPU: ${HEALTH_STATUS[cpu]^^}
Memory: ${HEALTH_STATUS[memory]^^}
Disk: ${HEALTH_STATUS[disk]^^}
Network: ${HEALTH_STATUS[network]^^}
Services: ${HEALTH_STATUS[services]^^}
Security: ${HEALTH_STATUS[security]^^}

Detailed Metrics:
----------------
EOF

    # Add all metrics
    for metric in "${!HEALTH_METRICS[@]}"; do
        echo "$metric: ${HEALTH_METRICS[$metric]}" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

System Information:
------------------
Hostname: $(hostname)
Uptime: $(uptime -p 2>/dev/null || uptime)
Kernel: $(uname -r)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "Unknown")
Architecture: $(uname -m)

Process Information:
-------------------
Top CPU Processes:
$(ps aux --sort=-%cpu | head -6)

Top Memory Processes:
$(ps aux --sort=-%mem | head -6)

Network Connections:
-------------------
$(netstat -tuln 2>/dev/null | head -10 || ss -tuln 2>/dev/null | head -10 || echo "Network connection info not available")

Recent System Events:
--------------------
$(journalctl --since "1 hour ago" --no-pager -n 20 2>/dev/null || echo "System events not available")

Recommendations:
---------------
EOF

    # Add recommendations based on health status
    if [[ "${HEALTH_STATUS[cpu]}" == "warning" ]] || [[ "${HEALTH_STATUS[cpu]}" == "critical" ]]; then
        echo "- Monitor CPU usage and consider optimizing high-usage processes" >> "$report_file"
    fi
    
    if [[ "${HEALTH_STATUS[memory]}" == "warning" ]] || [[ "${HEALTH_STATUS[memory]}" == "critical" ]]; then
        echo "- Free up memory by closing unnecessary applications" >> "$report_file"
        echo "- Consider adding more RAM if consistently high usage" >> "$report_file"
    fi
    
    if [[ "${HEALTH_STATUS[disk]}" == "warning" ]] || [[ "${HEALTH_STATUS[disk]}" == "critical" ]]; then
        echo "- Clean up disk space: sudo apt autoremove && sudo apt autoclean" >> "$report_file"
        echo "- Remove old log files and temporary files" >> "$report_file"
    fi
    
    if [[ "${HEALTH_STATUS[network]}" == "warning" ]] || [[ "${HEALTH_STATUS[network]}" == "critical" ]]; then
        echo "- Check network configuration and connectivity" >> "$report_file"
        echo "- Verify DNS settings and firewall rules" >> "$report_file"
    fi
    
    if [[ "${HEALTH_STATUS[services]}" == "warning" ]] || [[ "${HEALTH_STATUS[services]}" == "critical" ]]; then
        echo "- Start required services: sudo systemctl start ssh cloudflared" >> "$report_file"
        echo "- Enable services for startup: sudo systemctl enable ssh cloudflared" >> "$report_file"
    fi
    
    if [[ "${HEALTH_STATUS[security]}" == "warning" ]] || [[ "${HEALTH_STATUS[security]}" == "critical" ]]; then
        echo "- Review and improve security configuration" >> "$report_file"
        echo "- Enable firewall if not already active" >> "$report_file"
        echo "- Monitor for suspicious login attempts" >> "$report_file"
    fi
    
    log_success "System health report saved to: $report_file"
    echo
    log_info "To view the full report: cat $report_file"
    
    return 0
}

# Run continuous health monitoring
run_health_monitor() {
    local duration="${1:-0}"  # 0 means run once
    local interval="${2:-$HEALTH_CHECK_INTERVAL}"
    
    init_health_monitor
    
    log_info "Starting system health monitoring..."
    if [ "$duration" -gt 0 ]; then
        log_info "Monitoring duration: ${duration} seconds (interval: ${interval}s)"
    else
        log_info "Running single health check..."
    fi
    
    local start_time=$(date +%s)
    local check_count=0
    
    while true; do
        ((check_count++))
        log_info "Health check #$check_count - $(date)"
        
        # Run all health checks
        check_cpu_health
        check_memory_health
        check_disk_health
        check_network_health
        check_service_health
        check_security_health
        
        # Calculate overall health
        calculate_overall_health
        
        # Generate report
        generate_health_report
        
        # Check if we should continue monitoring
        if [ "$duration" -eq 0 ]; then
            break  # Single run
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $duration ]; then
            log_info "Monitoring duration completed"
            break
        fi
        
        # Wait for next check
        log_info "Next check in ${interval} seconds..."
        sleep $interval
    done
    
    log_success "Health monitoring completed"
    return 0
}

# Command line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-check}" in
        "check")
            run_health_monitor 0
            ;;
        "monitor")
            local duration="${2:-300}"  # Default 5 minutes
            local interval="${3:-60}"   # Default 1 minute
            run_health_monitor "$duration" "$interval"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo "Commands:"
            echo "  check                    Run single health check (default)"
            echo "  monitor [duration] [interval]  Run continuous monitoring"
            echo "Options:"
            echo "  duration                 Monitoring duration in seconds (default: 300)"
            echo "  interval                 Check interval in seconds (default: 60)"
            echo "Examples:"
            echo "  $0 check                 # Single health check"
            echo "  $0 monitor               # Monitor for 5 minutes"
            echo "  $0 monitor 600 30        # Monitor for 10 minutes, check every 30s"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi