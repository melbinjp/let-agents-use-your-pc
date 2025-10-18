#!/bin/bash

# Logging and Monitoring Module
# Provides centralized logging, monitoring, and alerting capabilities

set -euo pipefail

# Source error handler
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error-handler.sh"

# Logging configuration
LOG_DIR="/var/log/jules-endpoint"
MAIN_LOG_FILE="$LOG_DIR/jules-endpoint.log"
ERROR_LOG_FILE="$LOG_DIR/jules-endpoint-error.log"
ACCESS_LOG_FILE="$LOG_DIR/jules-endpoint-access.log"
AUDIT_LOG_FILE="$LOG_DIR/jules-endpoint-audit.log"

# Monitoring configuration
MONITOR_INTERVAL=30
LOG_ROTATION_SIZE="100M"
LOG_RETENTION_DAYS=30
ALERT_EMAIL=""
ALERT_WEBHOOK=""

# Log levels
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

CURRENT_LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Initialize logging system
init_logging_system() {
    log_info "Initializing logging system..."
    set_error_context "component" "logging-system"
    
    # Create log directory with proper permissions
    if [ ! -d "$LOG_DIR" ]; then
        sudo mkdir -p "$LOG_DIR"
        sudo chown $(whoami):$(whoami) "$LOG_DIR" 2>/dev/null || true
        sudo chmod 755 "$LOG_DIR"
    fi
    
    # Initialize log files
    for log_file in "$MAIN_LOG_FILE" "$ERROR_LOG_FILE" "$ACCESS_LOG_FILE" "$AUDIT_LOG_FILE"; do
        if [ ! -f "$log_file" ]; then
            touch "$log_file"
            chmod 644 "$log_file"
        fi
    done
    
    # Set up log rotation
    setup_log_rotation
    
    # Write initialization message
    write_log "INFO" "main" "Logging system initialized"
    
    log_success "Logging system initialized successfully"
}

# Setup log rotation using logrotate
setup_log_rotation() {
    local logrotate_config="/etc/logrotate.d/jules-endpoint"
    
    if [ -w "/etc/logrotate.d" ] || sudo -n true 2>/dev/null; then
        log_info "Setting up log rotation..."
        
        sudo tee "$logrotate_config" > /dev/null << EOF
$LOG_DIR/*.log {
    daily
    rotate $LOG_RETENTION_DAYS
    compress
    delaycompress
    missingok
    notifempty
    create 644 $(whoami) $(whoami)
    size $LOG_ROTATION_SIZE
    postrotate
        systemctl reload rsyslog 2>/dev/null || true
    endscript
}
EOF
        
        log_success "Log rotation configured"
    else
        log_warn "Cannot configure log rotation (insufficient permissions)"
    fi
}

# Write to specific log file
write_log() {
    local level="$1"
    local category="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] [$category] $message"
    
    # Check if we should log this level
    if [ ${LOG_LEVELS[$level]:-1} -lt ${LOG_LEVELS[$CURRENT_LOG_LEVEL]:-1} ]; then
        return 0
    fi
    
    # Write to main log
    echo "$log_entry" >> "$MAIN_LOG_FILE"
    
    # Write to specific logs based on level/category
    case "$level" in
        "ERROR"|"CRITICAL")
            echo "$log_entry" >> "$ERROR_LOG_FILE"
            ;;
    esac
    
    case "$category" in
        "access"|"ssh"|"connection")
            echo "$log_entry" >> "$ACCESS_LOG_FILE"
            ;;
        "audit"|"security"|"auth")
            echo "$log_entry" >> "$AUDIT_LOG_FILE"
            ;;
    esac
    
    # Send to syslog if available
    if command -v logger &>/dev/null; then
        logger -t "jules-endpoint" -p "user.$level" "[$category] $message"
    fi
}

# Enhanced logging functions
log_main() {
    local level="$1"
    local message="$2"
    local category="${3:-main}"
    
    write_log "$level" "$category" "$message"
    
    # Also output to console with color
    case "$level" in
        "DEBUG")
            echo -e "${CYAN}[DEBUG]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "CRITICAL")
            echo -e "${PURPLE}[CRITICAL]${NC} $message" >&2
            ;;
    esac
}

# Specialized logging functions
log_access() {
    local user="$1"
    local action="$2"
    local result="$3"
    local details="${4:-}"
    
    local message="User: $user, Action: $action, Result: $result"
    if [ -n "$details" ]; then
        message="$message, Details: $details"
    fi
    
    write_log "INFO" "access" "$message"
}

log_security() {
    local event="$1"
    local severity="$2"
    local details="$3"
    
    local message="Security Event: $event, Details: $details"
    write_log "$severity" "security" "$message"
    
    # Send alert for critical security events
    if [ "$severity" = "CRITICAL" ]; then
        send_alert "SECURITY ALERT" "$message"
    fi
}

log_performance() {
    local metric="$1"
    local value="$2"
    local threshold="$3"
    local unit="${4:-}"
    
    local message="Performance Metric: $metric = $value$unit"
    if [ -n "$threshold" ]; then
        message="$message (threshold: $threshold$unit)"
    fi
    
    local level="INFO"
    if [ -n "$threshold" ] && (( $(echo "$value > $threshold" | bc -l 2>/dev/null || echo 0) )); then
        level="WARN"
        send_alert "PERFORMANCE WARNING" "$message"
    fi
    
    write_log "$level" "performance" "$message"
}

log_system_event() {
    local event="$1"
    local component="$2"
    local status="$3"
    local details="${4:-}"
    
    local message="System Event: $event, Component: $component, Status: $status"
    if [ -n "$details" ]; then
        message="$message, Details: $details"
    fi
    
    local level="INFO"
    case "$status" in
        "failed"|"error"|"critical")
            level="ERROR"
            ;;
        "warning"|"degraded")
            level="WARN"
            ;;
    esac
    
    write_log "$level" "system" "$message"
}

# Monitor SSH connections
monitor_ssh_connections() {
    log_debug "Monitoring SSH connections..."
    
    # Get current SSH connections
    local ssh_connections=$(netstat -tn 2>/dev/null | grep :22 | grep ESTABLISHED | wc -l || echo "0")
    log_performance "ssh_connections" "$ssh_connections" "10" ""
    
    # Monitor failed SSH attempts
    local failed_attempts=$(journalctl -u ssh --since "5 minutes ago" 2>/dev/null | grep -c "Failed password" || echo "0")
    if [ "$failed_attempts" -gt 5 ]; then
        log_security "multiple_failed_ssh_attempts" "WARN" "Failed attempts in last 5 minutes: $failed_attempts"
    fi
    
    # Monitor successful SSH logins
    local successful_logins=$(journalctl -u ssh --since "5 minutes ago" 2>/dev/null | grep -c "Accepted publickey" || echo "0")
    if [ "$successful_logins" -gt 0 ]; then
        log_access "jules" "ssh_login" "success" "Successful logins in last 5 minutes: $successful_logins"
    fi
}

# Monitor Cloudflare tunnel
monitor_cloudflare_tunnel() {
    log_debug "Monitoring Cloudflare tunnel..."
    
    # Check tunnel service status
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log_system_event "tunnel_status_check" "cloudflared" "running"
        
        # Check for tunnel errors in logs
        local tunnel_errors=$(journalctl -u cloudflared --since "5 minutes ago" 2>/dev/null | grep -c -i "error\|failed\|timeout" || echo "0")
        if [ "$tunnel_errors" -gt 0 ]; then
            log_system_event "tunnel_errors_detected" "cloudflared" "warning" "Errors in last 5 minutes: $tunnel_errors"
        fi
        
        # Check tunnel connectivity
        local tunnel_uuid=""
        if [ -f "/etc/cloudflared/config.yml" ]; then
            tunnel_uuid=$(grep "^tunnel:" /etc/cloudflared/config.yml | awk '{print $2}' | tr -d '"' || echo "")
        fi
        
        if [ -n "$tunnel_uuid" ]; then
            if timeout 10 cloudflared tunnel info "$tunnel_uuid" &>/dev/null; then
                log_system_event "tunnel_connectivity_check" "cloudflared" "success"
            else
                log_system_event "tunnel_connectivity_check" "cloudflared" "failed" "Cannot retrieve tunnel info"
            fi
        fi
    else
        log_system_event "tunnel_status_check" "cloudflared" "stopped"
    fi
}

# Monitor system resources
monitor_system_resources() {
    log_debug "Monitoring system resources..."
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    log_performance "cpu_usage" "$cpu_usage" "80" "%"
    
    # Memory usage
    local mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    log_performance "memory_usage" "$mem_usage" "85" "%"
    
    # Disk usage
    local disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    log_performance "disk_usage" "$disk_usage" "90" "%"
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log_performance "load_average" "$load_avg" "5.0" ""
}

# Send alerts via configured methods
send_alert() {
    local subject="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_message="[$timestamp] $subject: $message"
    
    log_info "Sending alert: $subject"
    
    # Email alert
    if [ -n "$ALERT_EMAIL" ] && command -v mail &>/dev/null; then
        echo "$full_message" | mail -s "Jules Endpoint Alert: $subject" "$ALERT_EMAIL" || \
            log_warn "Failed to send email alert to $ALERT_EMAIL"
    fi
    
    # Webhook alert
    if [ -n "$ALERT_WEBHOOK" ] && command -v curl &>/dev/null; then
        local payload="{\"subject\":\"$subject\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}"
        curl -X POST -H "Content-Type: application/json" -d "$payload" "$ALERT_WEBHOOK" &>/dev/null || \
            log_warn "Failed to send webhook alert to $ALERT_WEBHOOK"
    fi
    
    # System notification
    if command -v notify-send &>/dev/null; then
        notify-send "Jules Endpoint Alert" "$subject: $message" || true
    fi
    
    # Write to alert log
    write_log "CRITICAL" "alert" "$full_message"
}

# Analyze log patterns
analyze_log_patterns() {
    local log_file="${1:-$MAIN_LOG_FILE}"
    local hours="${2:-24}"
    
    log_info "Analyzing log patterns for last $hours hours..."
    
    if [ ! -f "$log_file" ]; then
        log_warn "Log file not found: $log_file"
        return 1
    fi
    
    local since_time=$(date -d "$hours hours ago" '+%Y-%m-%d %H:%M:%S')
    
    # Count log levels
    echo "Log Level Distribution (last $hours hours):"
    awk -v since="$since_time" '$0 >= since' "$log_file" | \
        grep -oE '\[(DEBUG|INFO|WARN|ERROR|CRITICAL)\]' | \
        sort | uniq -c | sort -nr
    
    echo
    echo "Top Error Messages:"
    awk -v since="$since_time" '$0 >= since && /\[ERROR\]|\[CRITICAL\]/' "$log_file" | \
        cut -d']' -f4- | sort | uniq -c | sort -nr | head -10
    
    echo
    echo "Component Activity:"
    awk -v since="$since_time" '$0 >= since' "$log_file" | \
        grep -oE '\[[a-z-]+\]' | grep -v '\[(DEBUG|INFO|WARN|ERROR|CRITICAL)\]' | \
        sort | uniq -c | sort -nr | head -10
}

# Generate monitoring report
generate_monitoring_report() {
    local report_file="/tmp/jules-endpoint-monitoring-report-$(date +%s).txt"
    
    log_info "Generating monitoring report: $report_file"
    
    cat > "$report_file" << EOF
Jules Endpoint Agent - Monitoring Report
=======================================
Generated: $(date)

Log File Status:
---------------
Main Log: $(wc -l < "$MAIN_LOG_FILE" 2>/dev/null || echo "0") lines
Error Log: $(wc -l < "$ERROR_LOG_FILE" 2>/dev/null || echo "0") lines
Access Log: $(wc -l < "$ACCESS_LOG_FILE" 2>/dev/null || echo "0") lines
Audit Log: $(wc -l < "$AUDIT_LOG_FILE" 2>/dev/null || echo "0") lines

Recent Activity Summary:
-----------------------
EOF

    # Add log analysis
    analyze_log_patterns "$MAIN_LOG_FILE" 1 >> "$report_file" 2>/dev/null || echo "Log analysis failed" >> "$report_file"
    
    cat >> "$report_file" << EOF

System Status:
-------------
SSH Service: $(systemctl is-active ssh 2>/dev/null || echo "unknown")
Cloudflared Service: $(systemctl is-active cloudflared 2>/dev/null || echo "unknown")
Disk Usage: $(df -h / | tail -1 | awk '{print $5}')
Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
Load Average: $(uptime | awk -F'load average:' '{print $2}')

Recent Alerts:
-------------
$(tail -20 "$MAIN_LOG_FILE" 2>/dev/null | grep "\[CRITICAL\]" | tail -5 || echo "No recent critical alerts")

Recommendations:
---------------
- Review error logs regularly: tail -f $ERROR_LOG_FILE
- Monitor system resources: watch -n 5 'free -h; df -h'
- Check service logs: journalctl -u ssh -u cloudflared -f
- Set up automated alerts for critical events
EOF

    log_success "Monitoring report saved to: $report_file"
    echo
    log_info "To view the full report: cat $report_file"
}

# Run continuous monitoring
run_monitoring() {
    local duration="${1:-0}"  # 0 means run indefinitely
    local interval="${2:-$MONITOR_INTERVAL}"
    
    init_logging_system
    
    log_info "Starting continuous monitoring..."
    if [ "$duration" -gt 0 ]; then
        log_info "Monitoring duration: ${duration} seconds (interval: ${interval}s)"
    else
        log_info "Running indefinitely (interval: ${interval}s)"
    fi
    
    local start_time=$(date +%s)
    local check_count=0
    
    # Set up signal handlers for graceful shutdown
    trap 'log_info "Monitoring stopped by signal"; exit 0' INT TERM
    
    while true; do
        ((check_count++))
        log_debug "Monitoring check #$check_count - $(date)"
        
        # Run monitoring checks
        monitor_ssh_connections
        monitor_cloudflare_tunnel
        monitor_system_resources
        
        # Generate periodic reports
        if [ $((check_count % 20)) -eq 0 ]; then  # Every 20 checks
            generate_monitoring_report
        fi
        
        # Check if we should continue monitoring
        if [ "$duration" -gt 0 ]; then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            if [ $elapsed -ge $duration ]; then
                log_info "Monitoring duration completed"
                break
            fi
        fi
        
        # Wait for next check
        sleep $interval
    done
    
    log_success "Monitoring completed"
    return 0
}

# Command line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-monitor}" in
        "init")
            init_logging_system
            ;;
        "monitor")
            local duration="${2:-0}"
            local interval="${3:-$MONITOR_INTERVAL}"
            run_monitoring "$duration" "$interval"
            ;;
        "analyze")
            local hours="${2:-24}"
            analyze_log_patterns "$MAIN_LOG_FILE" "$hours"
            ;;
        "report")
            generate_monitoring_report
            ;;
        "alert")
            local subject="${2:-Test Alert}"
            local message="${3:-This is a test alert message}"
            send_alert "$subject" "$message"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo "Commands:"
            echo "  init                     Initialize logging system"
            echo "  monitor [duration] [interval]  Run continuous monitoring"
            echo "  analyze [hours]          Analyze log patterns"
            echo "  report                   Generate monitoring report"
            echo "  alert [subject] [message]  Send test alert"
            echo "Options:"
            echo "  duration                 Monitoring duration in seconds (0 = indefinite)"
            echo "  interval                 Check interval in seconds (default: $MONITOR_INTERVAL)"
            echo "  hours                    Hours to analyze (default: 24)"
            echo "Examples:"
            echo "  $0 init                  # Initialize logging"
            echo "  $0 monitor               # Monitor indefinitely"
            echo "  $0 monitor 3600 60       # Monitor for 1 hour, check every minute"
            echo "  $0 analyze 12            # Analyze last 12 hours"
            echo "  $0 report                # Generate current report"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi