#!/bin/bash

# Tunnel Reliability and Monitoring Module
# Provides automatic reconnection, health monitoring, and stability testing for Cloudflare tunnels

set -euo pipefail

# Source error handler and logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error-handler.sh"
source "$SCRIPT_DIR/logging-monitor.sh"

# Tunnel reliability configuration
TUNNEL_CHECK_INTERVAL=30
TUNNEL_RECONNECT_ATTEMPTS=5
TUNNEL_RECONNECT_DELAY=10
TUNNEL_HEALTH_TIMEOUT=15
TUNNEL_STABILITY_WINDOW=300  # 5 minutes
TUNNEL_FAILURE_THRESHOLD=3
NETWORK_TEST_HOSTS=("8.8.8.8" "1.1.1.1" "cloudflare.com")

# State tracking
declare -A TUNNEL_STATE
declare -A TUNNEL_METRICS
declare -A RECONNECT_HISTORY
TUNNEL_PID=""
MONITORING_ACTIVE=false

# Initialize tunnel reliability system
init_tunnel_reliability() {
    log_info "Initializing tunnel reliability system..."
    set_error_context "component" "tunnel-reliability"
    
    # Initialize state tracking
    TUNNEL_STATE[status]="unknown"
    TUNNEL_STATE[last_check]="0"
    TUNNEL_STATE[consecutive_failures]="0"
    TUNNEL_STATE[last_success]="0"
    TUNNEL_STATE[reconnect_count]="0"
    
    # Initialize metrics
    TUNNEL_METRICS[uptime_start]="$(date +%s)"
    TUNNEL_METRICS[total_checks]="0"
    TUNNEL_METRICS[successful_checks]="0"
    TUNNEL_METRICS[failed_checks]="0"
    TUNNEL_METRICS[reconnections]="0"
    TUNNEL_METRICS[network_interruptions]="0"
    
    # Create state directory
    local state_dir="/tmp/jules-tunnel-reliability"
    mkdir -p "$state_dir"
    
    log_success "Tunnel reliability system initialized"
}

# Check if cloudflared service is running
check_tunnel_service() {
    log_debug "Checking tunnel service status..."
    
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        TUNNEL_STATE[service_running]="true"
        
        # Get PID if available
        TUNNEL_PID=$(systemctl show --property MainPID --value cloudflared 2>/dev/null || echo "")
        if [ -n "$TUNNEL_PID" ] && [ "$TUNNEL_PID" != "0" ]; then
            TUNNEL_STATE[pid]="$TUNNEL_PID"
            log_debug "Tunnel service running with PID: $TUNNEL_PID"
        fi
        
        return 0
    else
        TUNNEL_STATE[service_running]="false"
        TUNNEL_STATE[pid]=""
        log_warn "Tunnel service is not running"
        return 1
    fi
}

# Test tunnel connectivity
test_tunnel_connectivity() {
    log_debug "Testing tunnel connectivity..."
    set_error_context "operation" "tunnel-connectivity-test"
    
    local tunnel_uuid=""
    local tunnel_hostname=""
    
    # Get tunnel configuration
    if [ -f "/etc/cloudflared/config.yml" ]; then
        tunnel_uuid=$(grep "^tunnel:" /etc/cloudflared/config.yml | awk '{print $2}' | tr -d '"' 2>/dev/null || echo "")
    fi
    
    if [ -z "$tunnel_uuid" ]; then
        log_warn "Cannot find tunnel UUID in configuration"
        TUNNEL_STATE[config_valid]="false"
        return 1
    fi
    
    TUNNEL_STATE[config_valid]="true"
    TUNNEL_STATE[tunnel_uuid]="$tunnel_uuid"
    
    # Test tunnel info retrieval
    local tunnel_info_result=0
    if timeout $TUNNEL_HEALTH_TIMEOUT cloudflared tunnel info "$tunnel_uuid" &>/dev/null; then
        log_debug "Tunnel info retrieval successful"
        TUNNEL_STATE[info_accessible]="true"
    else
        log_warn "Cannot retrieve tunnel information"
        TUNNEL_STATE[info_accessible]="false"
        tunnel_info_result=1
    fi
    
    # Try to get tunnel hostname
    tunnel_hostname=$(cloudflared tunnel info "$tunnel_uuid" 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
    
    if [ -z "$tunnel_hostname" ]; then
        # Try from service logs
        tunnel_hostname=$(journalctl -u cloudflared --no-pager -n 50 2>/dev/null | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | tail -1 || echo "")
    fi
    
    if [ -n "$tunnel_hostname" ]; then
        TUNNEL_STATE[hostname]="$tunnel_hostname"
        log_debug "Tunnel hostname: $tunnel_hostname"
        
        # Test HTTP connectivity to tunnel
        if timeout $TUNNEL_HEALTH_TIMEOUT curl -s -o /dev/null "https://$tunnel_hostname" 2>/dev/null; then
            log_debug "Tunnel HTTP connectivity successful"
            TUNNEL_STATE[http_accessible]="true"
        else
            log_warn "Tunnel HTTP connectivity failed"
            TUNNEL_STATE[http_accessible]="false"
            return 1
        fi
    else
        log_warn "Cannot determine tunnel hostname"
        TUNNEL_STATE[hostname]=""
        TUNNEL_STATE[http_accessible]="false"
        return 1
    fi
    
    return $tunnel_info_result
}

# Test network connectivity
test_network_connectivity() {
    log_debug "Testing network connectivity..."
    set_error_context "operation" "network-connectivity-test"
    
    local successful_hosts=0
    local total_hosts=${#NETWORK_TEST_HOSTS[@]}
    
    for host in "${NETWORK_TEST_HOSTS[@]}"; do
        if timeout 5 ping -c 1 "$host" &>/dev/null; then
            ((successful_hosts++))
            log_debug "Network connectivity to $host: OK"
        else
            log_debug "Network connectivity to $host: FAILED"
        fi
    done
    
    local connectivity_ratio=$((successful_hosts * 100 / total_hosts))
    TUNNEL_STATE[network_connectivity]="$connectivity_ratio"
    
    if [ $successful_hosts -eq 0 ]; then
        log_error "Complete network connectivity failure"
        TUNNEL_METRICS[network_interruptions]=$((${TUNNEL_METRICS[network_interruptions]} + 1))
        return 2  # Network failure
    elif [ $successful_hosts -lt $total_hosts ]; then
        log_warn "Partial network connectivity ($successful_hosts/$total_hosts hosts reachable)"
        return 1  # Partial failure
    else
        log_debug "Full network connectivity confirmed"
        return 0  # Success
    fi
}

# Perform comprehensive tunnel health check
perform_tunnel_health_check() {
    log_debug "Performing comprehensive tunnel health check..."
    set_error_context "operation" "tunnel-health-check"
    
    local current_time=$(date +%s)
    TUNNEL_STATE[last_check]="$current_time"
    TUNNEL_METRICS[total_checks]=$((${TUNNEL_METRICS[total_checks]} + 1))
    
    local health_score=0
    local max_score=4
    local issues=()
    
    # Check 1: Service running
    if check_tunnel_service; then
        ((health_score++))
        log_debug "✓ Tunnel service is running"
    else
        issues+=("Service not running")
    fi
    
    # Check 2: Network connectivity
    local network_result
    test_network_connectivity
    network_result=$?
    
    if [ $network_result -eq 0 ]; then
        ((health_score++))
        log_debug "✓ Network connectivity is good"
    elif [ $network_result -eq 1 ]; then
        issues+=("Partial network connectivity")
    else
        issues+=("Network connectivity failure")
    fi
    
    # Check 3: Tunnel connectivity
    if test_tunnel_connectivity; then
        ((health_score++))
        log_debug "✓ Tunnel connectivity is working"
    else
        issues+=("Tunnel connectivity failure")
    fi
    
    # Check 4: SSH service (tunnel target)
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        ((health_score++))
        log_debug "✓ SSH service is running"
    else
        issues+=("SSH service not running")
    fi
    
    # Calculate health percentage
    local health_percentage=$((health_score * 100 / max_score))
    TUNNEL_STATE[health_score]="$health_score"
    TUNNEL_STATE[health_percentage]="$health_percentage"
    
    # Determine overall status
    if [ $health_score -eq $max_score ]; then
        TUNNEL_STATE[status]="healthy"
        TUNNEL_STATE[consecutive_failures]="0"
        TUNNEL_STATE[last_success]="$current_time"
        TUNNEL_METRICS[successful_checks]=$((${TUNNEL_METRICS[successful_checks]} + 1))
        log_success "Tunnel health check passed (${health_percentage}%)"
        return 0
    elif [ $health_score -ge 2 ]; then
        TUNNEL_STATE[status]="degraded"
        TUNNEL_STATE[consecutive_failures]=$((${TUNNEL_STATE[consecutive_failures]} + 1))
        TUNNEL_METRICS[failed_checks]=$((${TUNNEL_METRICS[failed_checks]} + 1))
        log_warn "Tunnel health degraded (${health_percentage}%): ${issues[*]}"
        return 1
    else
        TUNNEL_STATE[status]="failed"
        TUNNEL_STATE[consecutive_failures]=$((${TUNNEL_STATE[consecutive_failures]} + 1))
        TUNNEL_METRICS[failed_checks]=$((${TUNNEL_METRICS[failed_checks]} + 1))
        log_error "Tunnel health check failed (${health_percentage}%): ${issues[*]}"
        return 2
    fi
}

# Attempt to restart tunnel service
restart_tunnel_service() {
    log_info "Attempting to restart tunnel service..."
    set_error_context "operation" "tunnel-service-restart"
    
    local restart_start=$(date +%s)
    
    # Stop the service first
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log_info "Stopping cloudflared service..."
        if ! systemctl stop cloudflared; then
            log_error "Failed to stop cloudflared service"
            return 1
        fi
        sleep 2
    fi
    
    # Start the service
    log_info "Starting cloudflared service..."
    if ! systemctl start cloudflared; then
        log_error "Failed to start cloudflared service"
        return 1
    fi
    
    # Wait for service to stabilize
    sleep 5
    
    # Verify service is running
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        local restart_duration=$(($(date +%s) - restart_start))
        log_success "Tunnel service restarted successfully (${restart_duration}s)"
        
        # Log the restart event
        log_system_event "tunnel_service_restart" "cloudflared" "success" "Restart duration: ${restart_duration}s"
        
        return 0
    else
        log_error "Tunnel service failed to start after restart attempt"
        return 1
    fi
}

# Perform automatic tunnel reconnection
perform_tunnel_reconnection() {
    local reason="$1"
    
    log_info "Initiating tunnel reconnection (reason: $reason)..."
    set_error_context "operation" "tunnel-reconnection"
    
    local reconnect_start=$(date +%s)
    local attempt=1
    
    TUNNEL_STATE[reconnect_count]=$((${TUNNEL_STATE[reconnect_count]} + 1))
    TUNNEL_METRICS[reconnections]=$((${TUNNEL_METRICS[reconnections]} + 1))
    
    # Record reconnection attempt
    RECONNECT_HISTORY["$reconnect_start"]="$reason"
    
    while [ $attempt -le $TUNNEL_RECONNECT_ATTEMPTS ]; do
        log_info "Reconnection attempt $attempt/$TUNNEL_RECONNECT_ATTEMPTS..."
        
        # Wait before retry (except first attempt)
        if [ $attempt -gt 1 ]; then
            local delay=$((TUNNEL_RECONNECT_DELAY * attempt))
            log_info "Waiting ${delay}s before retry..."
            sleep $delay
        fi
        
        # Check network connectivity first
        if ! test_network_connectivity >/dev/null 2>&1; then
            log_warn "Network connectivity issues detected, waiting longer..."
            sleep $((TUNNEL_RECONNECT_DELAY * 2))
            ((attempt++))
            continue
        fi
        
        # Attempt service restart
        if restart_tunnel_service; then
            # Wait for tunnel to establish
            log_info "Waiting for tunnel to establish connection..."
            sleep 10
            
            # Verify tunnel health
            if perform_tunnel_health_check >/dev/null 2>&1; then
                local reconnect_duration=$(($(date +%s) - reconnect_start))
                log_success "Tunnel reconnection successful after ${reconnect_duration}s (attempt $attempt)"
                
                # Log successful reconnection
                log_system_event "tunnel_reconnection" "cloudflared" "success" "Duration: ${reconnect_duration}s, Attempts: $attempt"
                
                return 0
            else
                log_warn "Tunnel health check failed after restart"
            fi
        else
            log_warn "Service restart failed"
        fi
        
        ((attempt++))
    done
    
    local reconnect_duration=$(($(date +%s) - reconnect_start))
    log_error "Tunnel reconnection failed after $TUNNEL_RECONNECT_ATTEMPTS attempts (${reconnect_duration}s)"
    
    # Log failed reconnection
    log_system_event "tunnel_reconnection" "cloudflared" "failed" "Duration: ${reconnect_duration}s, Attempts: $TUNNEL_RECONNECT_ATTEMPTS"
    
    # Send critical alert
    send_alert "TUNNEL RECONNECTION FAILED" "Failed to reconnect tunnel after $TUNNEL_RECONNECT_ATTEMPTS attempts. Manual intervention required."
    
    return 1
}

# Test connection stability over time
test_connection_stability() {
    local test_duration="${1:-$TUNNEL_STABILITY_WINDOW}"
    local test_interval="${2:-10}"
    
    log_info "Testing connection stability for ${test_duration}s (interval: ${test_interval}s)..."
    set_error_context "operation" "stability-test"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + test_duration))
    local test_count=0
    local success_count=0
    local failure_count=0
    local stability_issues=()
    
    while [ $(date +%s) -lt $end_time ]; do
        ((test_count++))
        log_debug "Stability test $test_count - $(date)"
        
        if perform_tunnel_health_check >/dev/null 2>&1; then
            ((success_count++))
            log_debug "Stability test $test_count: PASS"
        else
            ((failure_count++))
            stability_issues+=("Test $test_count failed at $(date)")
            log_debug "Stability test $test_count: FAIL"
        fi
        
        sleep $test_interval
    done
    
    local success_rate=$((success_count * 100 / test_count))
    local actual_duration=$(($(date +%s) - start_time))
    
    # Store stability metrics
    TUNNEL_METRICS[stability_test_duration]="$actual_duration"
    TUNNEL_METRICS[stability_test_count]="$test_count"
    TUNNEL_METRICS[stability_success_rate]="$success_rate"
    
    log_info "Stability test completed: $success_count/$test_count successful (${success_rate}%)"
    
    if [ $success_rate -ge 95 ]; then
        log_success "Connection stability: EXCELLENT (${success_rate}%)"
        return 0
    elif [ $success_rate -ge 85 ]; then
        log_success "Connection stability: GOOD (${success_rate}%)"
        return 0
    elif [ $success_rate -ge 70 ]; then
        log_warn "Connection stability: FAIR (${success_rate}%)"
        return 1
    else
        log_error "Connection stability: POOR (${success_rate}%)"
        log_error "Stability issues detected: ${#stability_issues[@]} failures"
        return 2
    fi
}

# Handle network interruption detection and recovery
handle_network_interruption() {
    log_warn "Network interruption detected, initiating recovery procedures..."
    set_error_context "operation" "network-interruption-handling"
    
    local interruption_start=$(date +%s)
    local recovery_attempts=0
    local max_recovery_attempts=10
    local recovery_delay=30
    
    # Log the interruption
    log_system_event "network_interruption" "network" "detected" "Starting recovery procedures"
    
    while [ $recovery_attempts -lt $max_recovery_attempts ]; do
        ((recovery_attempts++))
        log_info "Network recovery attempt $recovery_attempts/$max_recovery_attempts..."
        
        # Wait for network to potentially recover
        sleep $recovery_delay
        
        # Test network connectivity
        local network_result
        test_network_connectivity >/dev/null 2>&1
        network_result=$?
        
        if [ $network_result -eq 0 ]; then
            local recovery_duration=$(($(date +%s) - interruption_start))
            log_success "Network connectivity restored after ${recovery_duration}s"
            
            # Test tunnel health after network recovery
            sleep 10  # Give tunnel time to reconnect
            if perform_tunnel_health_check >/dev/null 2>&1; then
                log_success "Tunnel automatically recovered after network restoration"
                log_system_event "network_recovery" "network" "success" "Duration: ${recovery_duration}s"
                return 0
            else
                log_warn "Tunnel needs manual reconnection after network recovery"
                if perform_tunnel_reconnection "network_recovery"; then
                    log_success "Tunnel reconnected successfully after network recovery"
                    log_system_event "network_recovery" "tunnel" "success" "Duration: ${recovery_duration}s"
                    return 0
                fi
            fi
        elif [ $network_result -eq 1 ]; then
            log_info "Partial network connectivity detected, continuing recovery..."
        else
            log_debug "Network still unavailable, continuing recovery attempts..."
        fi
        
        # Increase delay for subsequent attempts
        recovery_delay=$((recovery_delay + 10))
    done
    
    local interruption_duration=$(($(date +%s) - interruption_start))
    log_error "Network recovery failed after $max_recovery_attempts attempts (${interruption_duration}s)"
    
    # Send critical alert
    send_alert "NETWORK RECOVERY FAILED" "Network interruption lasted ${interruption_duration}s. Manual intervention required."
    
    log_system_event "network_recovery" "network" "failed" "Duration: ${interruption_duration}s"
    return 1
}

# Generate tunnel reliability report
generate_tunnel_reliability_report() {
    local report_file="/tmp/jules-tunnel-reliability-report-$(date +%s).txt"
    
    log_info "Generating tunnel reliability report: $report_file"
    
    local current_time=$(date +%s)
    local uptime_duration=$((current_time - ${TUNNEL_METRICS[uptime_start]}))
    local uptime_hours=$((uptime_duration / 3600))
    local uptime_minutes=$(((uptime_duration % 3600) / 60))
    
    # Calculate reliability percentage
    local total_checks=${TUNNEL_METRICS[total_checks]}
    local successful_checks=${TUNNEL_METRICS[successful_checks]}
    local reliability_pct=0
    
    if [ $total_checks -gt 0 ]; then
        reliability_pct=$((successful_checks * 100 / total_checks))
    fi
    
    cat > "$report_file" << EOF
Jules Endpoint Agent - Tunnel Reliability Report
===============================================
Generated: $(date)
Monitoring Duration: ${uptime_hours}h ${uptime_minutes}m

Current Status:
--------------
Tunnel Status: ${TUNNEL_STATE[status]^^}
Health Score: ${TUNNEL_STATE[health_score]:-0}/4 (${TUNNEL_STATE[health_percentage]:-0}%)
Service Running: ${TUNNEL_STATE[service_running]:-unknown}
Network Connectivity: ${TUNNEL_STATE[network_connectivity]:-0}%
Tunnel Hostname: ${TUNNEL_STATE[hostname]:-unknown}
Last Successful Check: $(date -d "@${TUNNEL_STATE[last_success]}" 2>/dev/null || echo "Never")
Consecutive Failures: ${TUNNEL_STATE[consecutive_failures]:-0}

Reliability Metrics:
-------------------
Overall Reliability: ${reliability_pct}%
Total Health Checks: ${TUNNEL_METRICS[total_checks]}
Successful Checks: ${TUNNEL_METRICS[successful_checks]}
Failed Checks: ${TUNNEL_METRICS[failed_checks]}
Reconnection Attempts: ${TUNNEL_METRICS[reconnections]}
Network Interruptions: ${TUNNEL_METRICS[network_interruptions]}

Stability Test Results:
----------------------
EOF

    if [ -n "${TUNNEL_METRICS[stability_test_duration]:-}" ]; then
        cat >> "$report_file" << EOF
Last Test Duration: ${TUNNEL_METRICS[stability_test_duration]}s
Test Count: ${TUNNEL_METRICS[stability_test_count]}
Success Rate: ${TUNNEL_METRICS[stability_success_rate]}%
EOF
    else
        echo "No stability tests performed yet" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

Recent Reconnection History:
---------------------------
EOF

    # Add recent reconnection history
    local reconnect_count=0
    for timestamp in "${!RECONNECT_HISTORY[@]}"; do
        if [ $reconnect_count -lt 10 ]; then
            local reconnect_time=$(date -d "@$timestamp" 2>/dev/null || echo "Unknown time")
            echo "$reconnect_time: ${RECONNECT_HISTORY[$timestamp]}" >> "$report_file"
            ((reconnect_count++))
        fi
    done
    
    if [ $reconnect_count -eq 0 ]; then
        echo "No recent reconnections" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

System Information:
------------------
Cloudflared Version: $(cloudflared --version 2>/dev/null | head -1 || echo "Unknown")
SSH Service Status: $(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null || echo "Unknown")
Tunnel Configuration: $([ -f "/etc/cloudflared/config.yml" ] && echo "Present" || echo "Missing")
Tunnel UUID: ${TUNNEL_STATE[tunnel_uuid]:-unknown}

Recommendations:
---------------
EOF

    # Add recommendations based on current state
    if [ "${TUNNEL_STATE[status]}" = "failed" ]; then
        echo "- CRITICAL: Tunnel is currently failed, immediate attention required" >> "$report_file"
        echo "- Check network connectivity and service logs" >> "$report_file"
    elif [ "${TUNNEL_STATE[status]}" = "degraded" ]; then
        echo "- WARNING: Tunnel performance is degraded" >> "$report_file"
        echo "- Monitor for improvement or consider manual intervention" >> "$report_file"
    fi
    
    if [ $reliability_pct -lt 95 ]; then
        echo "- Reliability is below 95%, investigate recurring issues" >> "$report_file"
    fi
    
    if [ ${TUNNEL_METRICS[reconnections]} -gt 5 ]; then
        echo "- High number of reconnections detected, check network stability" >> "$report_file"
    fi
    
    if [ ${TUNNEL_METRICS[network_interruptions]} -gt 2 ]; then
        echo "- Multiple network interruptions detected, check network infrastructure" >> "$report_file"
    fi
    
    echo "- Run stability test: $0 stability-test" >> "$report_file"
    echo "- Monitor logs: journalctl -u cloudflared -f" >> "$report_file"
    echo "- Check tunnel status: cloudflared tunnel info ${TUNNEL_STATE[tunnel_uuid]:-UUID}" >> "$report_file"
    
    log_success "Tunnel reliability report saved to: $report_file"
    echo
    log_info "To view the full report: cat $report_file"
}

# Run continuous tunnel monitoring
run_tunnel_monitoring() {
    local duration="${1:-0}"  # 0 means run indefinitely
    local interval="${2:-$TUNNEL_CHECK_INTERVAL}"
    
    init_tunnel_reliability
    
    log_info "Starting tunnel reliability monitoring..."
    if [ "$duration" -gt 0 ]; then
        log_info "Monitoring duration: ${duration} seconds (interval: ${interval}s)"
    else
        log_info "Running indefinitely (interval: ${interval}s)"
    fi
    
    MONITORING_ACTIVE=true
    local start_time=$(date +%s)
    local check_count=0
    
    # Set up signal handlers for graceful shutdown
    trap 'MONITORING_ACTIVE=false; log_info "Tunnel monitoring stopped by signal"' INT TERM
    
    while $MONITORING_ACTIVE; do
        ((check_count++))
        log_debug "Tunnel monitoring check #$check_count - $(date)"
        
        # Perform health check
        local health_result
        perform_tunnel_health_check
        health_result=$?
        
        # Handle failures
        if [ $health_result -ne 0 ]; then
            local consecutive_failures=${TUNNEL_STATE[consecutive_failures]}
            
            if [ $consecutive_failures -ge $TUNNEL_FAILURE_THRESHOLD ]; then
                log_warn "Tunnel failure threshold reached ($consecutive_failures failures)"
                
                # Check if it's a network issue
                local network_result
                test_network_connectivity >/dev/null 2>&1
                network_result=$?
                
                if [ $network_result -eq 2 ]; then
                    # Complete network failure
                    handle_network_interruption
                else
                    # Tunnel-specific issue
                    perform_tunnel_reconnection "health_check_failure"
                fi
            else
                log_info "Tunnel health degraded, monitoring for improvement..."
            fi
        fi
        
        # Generate periodic reports
        if [ $((check_count % 20)) -eq 0 ]; then  # Every 20 checks
            generate_tunnel_reliability_report
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
    
    MONITORING_ACTIVE=false
    log_success "Tunnel monitoring completed"
    return 0
}

# Command line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-monitor}" in
        "init")
            init_tunnel_reliability
            ;;
        "health-check")
            init_tunnel_reliability
            perform_tunnel_health_check
            ;;
        "reconnect")
            init_tunnel_reliability
            perform_tunnel_reconnection "${2:-manual}"
            ;;
        "stability-test")
            init_tunnel_reliability
            local duration="${2:-300}"
            local interval="${3:-10}"
            test_connection_stability "$duration" "$interval"
            ;;
        "monitor")
            local duration="${2:-0}"
            local interval="${3:-$TUNNEL_CHECK_INTERVAL}"
            run_tunnel_monitoring "$duration" "$interval"
            ;;
        "report")
            init_tunnel_reliability
            generate_tunnel_reliability_report
            ;;
        "--help"|"-h")
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo "Commands:"
            echo "  init                     Initialize tunnel reliability system"
            echo "  health-check             Perform single tunnel health check"
            echo "  reconnect [reason]       Force tunnel reconnection"
            echo "  stability-test [duration] [interval]  Test connection stability"
            echo "  monitor [duration] [interval]  Run continuous monitoring"
            echo "  report                   Generate reliability report"
            echo "Options:"
            echo "  duration                 Test/monitoring duration in seconds (0 = indefinite)"
            echo "  interval                 Check interval in seconds (default: $TUNNEL_CHECK_INTERVAL)"
            echo "  reason                   Reason for manual reconnection"
            echo "Examples:"
            echo "  $0 health-check          # Single health check"
            echo "  $0 stability-test 600 15 # Test stability for 10 minutes"
            echo "  $0 monitor               # Monitor indefinitely"
            echo "  $0 monitor 3600 60       # Monitor for 1 hour, check every minute"
            echo "  $0 reconnect network-issue # Force reconnection"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi