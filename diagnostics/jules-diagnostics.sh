#!/bin/bash

# Jules Endpoint Agent - Comprehensive Diagnostics Tool
# Main diagnostic script that orchestrates all diagnostic modules

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source all diagnostic modules
source "$SCRIPT_DIR/error-handler.sh"
source "$SCRIPT_DIR/connection-troubleshooter.sh"
source "$SCRIPT_DIR/system-health-check.sh"
source "$SCRIPT_DIR/logging-monitor.sh"

# Diagnostic configuration
DIAGNOSTIC_MODE="interactive"
OUTPUT_FORMAT="text"
SAVE_REPORTS=true
REPORT_DIR="/tmp/jules-diagnostics-$(date +%Y%m%d-%H%M%S)"

# Initialize comprehensive diagnostics
init_diagnostics() {
    log_info "Initializing Jules Endpoint Agent Diagnostics..."
    set_error_context "component" "diagnostics-main"
    
    # Create report directory
    if [ "$SAVE_REPORTS" = true ]; then
        mkdir -p "$REPORT_DIR"
        log_info "Diagnostic reports will be saved to: $REPORT_DIR"
    fi
    
    # Initialize all diagnostic modules
    init_logging_system
    init_health_monitor
    init_troubleshooter
    
    log_success "Diagnostics initialized successfully"
}

# Run quick diagnostic check
run_quick_check() {
    log_info "Running quick diagnostic check..."
    echo
    
    local issues_found=0
    
    # Quick system checks
    log_info "=== Quick System Check ==="
    
    # Check if running as root when needed
    if [ "$EUID" -eq 0 ]; then
        log_success "✓ Running with administrative privileges"
    else
        log_warn "⚠ Not running as root (some checks may be limited)"
    fi
    
    # Check basic connectivity
    if timeout 5 ping -c 1 8.8.8.8 &>/dev/null; then
        log_success "✓ Internet connectivity available"
    else
        log_error "✗ No internet connectivity"
        ((issues_found++))
    fi
    
    # Check SSH service
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        log_success "✓ SSH service is running"
    else
        log_error "✗ SSH service is not running"
        ((issues_found++))
    fi
    
    # Check cloudflared service
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        log_success "✓ Cloudflared service is running"
    else
        log_warn "⚠ Cloudflared service is not running"
        ((issues_found++))
    fi
    
    # Check jules user
    if id "jules" &>/dev/null; then
        log_success "✓ Jules user account exists"
    else
        log_error "✗ Jules user account not found"
        ((issues_found++))
    fi
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        log_success "✓ Sufficient disk space ($disk_usage% used)"
    else
        log_warn "⚠ Low disk space ($disk_usage% used)"
        ((issues_found++))
    fi
    
    echo
    if [ $issues_found -eq 0 ]; then
        log_success "Quick check completed - No critical issues found"
        return 0
    else
        log_warn "Quick check completed - $issues_found issues found"
        log_info "Run 'jules-diagnostics.sh full' for detailed analysis"
        return 1
    fi
}

# Run comprehensive diagnostic check
run_full_check() {
    log_info "Running comprehensive diagnostic check..."
    echo
    
    local overall_status=0
    
    # System health check
    log_info "=== System Health Check ==="
    if ! run_health_monitor 0; then
        overall_status=1
    fi
    echo
    
    # Connection troubleshooting
    log_info "=== Connection Troubleshooting ==="
    if ! run_connection_troubleshooter "all"; then
        overall_status=1
    fi
    echo
    
    # Generate comprehensive report
    generate_comprehensive_report
    
    return $overall_status
}

# Run specific diagnostic category
run_category_check() {
    local category="$1"
    
    log_info "Running diagnostic check for category: $category"
    echo
    
    case "$category" in
        "health"|"system")
            run_health_monitor 0
            ;;
        "connection"|"network")
            run_connection_troubleshooter "all"
            ;;
        "ssh")
            run_connection_troubleshooter "ssh"
            ;;
        "tunnel"|"cloudflare")
            run_connection_troubleshooter "tunnel"
            ;;
        "logs"|"logging")
            analyze_log_patterns "$MAIN_LOG_FILE" 24
            ;;
        "security")
            check_security_health
            ;;
        *)
            log_error "Unknown diagnostic category: $category"
            return 1
            ;;
    esac
}

# Generate comprehensive diagnostic report
generate_comprehensive_report() {
    local report_file="$REPORT_DIR/comprehensive-diagnostic-report.txt"
    
    log_info "Generating comprehensive diagnostic report..."
    
    cat > "$report_file" << EOF
Jules Endpoint Agent - Comprehensive Diagnostic Report
=====================================================
Generated: $(date)
System: $(uname -a)
User: $(whoami)
Report Directory: $REPORT_DIR

Executive Summary:
-----------------
EOF

    # Add quick status summary
    local critical_issues=0
    local warning_issues=0
    
    # Check system health status
    if [[ "${HEALTH_STATUS[overall]:-unknown}" == "critical" ]]; then
        ((critical_issues++))
        echo "❌ System Health: CRITICAL" >> "$report_file"
    elif [[ "${HEALTH_STATUS[overall]:-unknown}" == "warning" ]]; then
        ((warning_issues++))
        echo "⚠️  System Health: WARNING" >> "$report_file"
    else
        echo "✅ System Health: OK" >> "$report_file"
    fi
    
    # Check connection status
    local connection_failures=0
    for test_name in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$test_name]}" == "failed" ]]; then
            ((connection_failures++))
        fi
    done
    
    if [ $connection_failures -gt 3 ]; then
        ((critical_issues++))
        echo "❌ Connection Status: CRITICAL ($connection_failures failures)" >> "$report_file"
    elif [ $connection_failures -gt 0 ]; then
        ((warning_issues++))
        echo "⚠️  Connection Status: WARNING ($connection_failures failures)" >> "$report_file"
    else
        echo "✅ Connection Status: OK" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

Overall Assessment:
- Critical Issues: $critical_issues
- Warning Issues: $warning_issues
- Status: $([ $critical_issues -eq 0 ] && [ $warning_issues -eq 0 ] && echo "HEALTHY" || ([ $critical_issues -gt 0 ] && echo "CRITICAL" || echo "WARNING"))

Detailed Reports:
----------------
The following detailed reports have been generated:

1. System Health Report: $(ls "$REPORT_DIR"/*health-report*.txt 2>/dev/null | tail -1 || echo "Not generated")
2. Connection Diagnostic Report: $(ls "$REPORT_DIR"/*connection-report*.txt 2>/dev/null | tail -1 || echo "Not generated")
3. Monitoring Report: $(ls "$REPORT_DIR"/*monitoring-report*.txt 2>/dev/null | tail -1 || echo "Not generated")
4. Troubleshooting Report: $(ls "$REPORT_DIR"/*troubleshooting*.txt 2>/dev/null | tail -1 || echo "Not generated")

System Configuration:
--------------------
SSH Service: $(systemctl is-active ssh 2>/dev/null || echo "unknown")
Cloudflared Service: $(systemctl is-active cloudflared 2>/dev/null || echo "unknown")
Jules User: $(id jules &>/dev/null && echo "exists" || echo "missing")
Disk Usage: $(df -h / | tail -1 | awk '{print $5}')
Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
Load Average: $(uptime | awk -F'load average:' '{print $2}')

Network Configuration:
---------------------
IP Address: $(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
DNS Servers: $(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\n' ' ')
Active Interfaces: $(ip link show up | grep -c "state UP" || echo "0")

Service Configuration:
---------------------
SSH Config: $([ -f /etc/ssh/sshd_config ] && echo "exists" || echo "missing")
Cloudflared Config: $([ -f /etc/cloudflared/config.yml ] && echo "exists" || echo "missing")
Log Directory: $([ -d /var/log/jules-endpoint ] && echo "exists" || echo "missing")

Recommendations:
---------------
EOF

    # Add recommendations based on findings
    if [ $critical_issues -gt 0 ]; then
        echo "🚨 IMMEDIATE ACTION REQUIRED:" >> "$report_file"
        echo "- Address all critical issues before using the system" >> "$report_file"
        echo "- Review detailed reports for specific remediation steps" >> "$report_file"
        echo "- Consider reinstalling if multiple critical issues persist" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    if [ $warning_issues -gt 0 ]; then
        echo "⚠️  RECOMMENDED ACTIONS:" >> "$report_file"
        echo "- Review and address warning issues for optimal performance" >> "$report_file"
        echo "- Monitor system regularly to prevent issues from becoming critical" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    echo "📋 GENERAL RECOMMENDATIONS:" >> "$report_file"
    echo "- Run diagnostics regularly: jules-diagnostics.sh quick" >> "$report_file"
    echo "- Monitor logs: tail -f /var/log/jules-endpoint/jules-endpoint.log" >> "$report_file"
    echo "- Keep system updated: sudo apt update && sudo apt upgrade" >> "$report_file"
    echo "- Backup configuration files before making changes" >> "$report_file"
    echo "- Review security settings periodically" >> "$report_file"
    
    cat >> "$report_file" << EOF

Support Information:
-------------------
If you need assistance:
1. Review this comprehensive report and detailed reports
2. Check the troubleshooting documentation
3. Ensure all system requirements are met
4. Provide this report when seeking support

Report Generation Completed: $(date)
EOF

    # Copy other reports to the main directory
    if [ -d "/tmp" ]; then
        find /tmp -name "*jules-endpoint*report*.txt" -newer "$report_file" -exec cp {} "$REPORT_DIR/" \; 2>/dev/null || true
        find /tmp -name "*troubleshooting*.txt" -newer "$report_file" -exec cp {} "$REPORT_DIR/" \; 2>/dev/null || true
    fi
    
    log_success "Comprehensive diagnostic report saved to: $report_file"
    echo
    log_info "All diagnostic reports saved in: $REPORT_DIR"
    
    # Show summary
    echo
    log_info "=== DIAGNOSTIC SUMMARY ==="
    if [ $critical_issues -eq 0 ] && [ $warning_issues -eq 0 ]; then
        log_success "✅ System appears to be healthy"
    elif [ $critical_issues -gt 0 ]; then
        log_error "❌ Critical issues found - immediate attention required"
    else
        log_warn "⚠️  Warning issues found - review recommended"
    fi
    
    echo
    log_info "To view the full report: cat $report_file"
}

# Interactive diagnostic mode
run_interactive_mode() {
    log_info "Jules Endpoint Agent - Interactive Diagnostics"
    log_info "=============================================="
    echo
    
    while true; do
        echo "Available diagnostic options:"
        echo "1. Quick Check (recommended for regular use)"
        echo "2. Full Comprehensive Check"
        echo "3. System Health Check"
        echo "4. Connection Troubleshooting"
        echo "5. SSH Diagnostics"
        echo "6. Tunnel Diagnostics"
        echo "7. Log Analysis"
        echo "8. Security Check"
        echo "9. Generate Report Only"
        echo "0. Exit"
        echo
        
        read -p "Select an option (0-9): " choice
        echo
        
        case "$choice" in
            1)
                run_quick_check
                ;;
            2)
                run_full_check
                ;;
            3)
                run_category_check "health"
                ;;
            4)
                run_category_check "connection"
                ;;
            5)
                run_category_check "ssh"
                ;;
            6)
                run_category_check "tunnel"
                ;;
            7)
                run_category_check "logs"
                ;;
            8)
                run_category_check "security"
                ;;
            9)
                generate_comprehensive_report
                ;;
            0)
                log_info "Exiting diagnostics"
                break
                ;;
            *)
                log_warn "Invalid option. Please select 0-9."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        echo
    done
}

# Show usage information
show_usage() {
    echo "Jules Endpoint Agent - Comprehensive Diagnostics Tool"
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  quick                    Run quick diagnostic check (default)"
    echo "  full                     Run comprehensive diagnostic check"
    echo "  interactive              Run in interactive mode"
    echo "  health                   Check system health only"
    echo "  connection               Check connection status only"
    echo "  ssh                      Check SSH configuration only"
    echo "  tunnel                   Check tunnel status only"
    echo "  logs                     Analyze log files only"
    echo "  security                 Check security configuration only"
    echo "  report                   Generate comprehensive report only"
    echo
    echo "Options:"
    echo "  --no-reports             Don't save diagnostic reports"
    echo "  --report-dir DIR         Save reports to specific directory"
    echo "  --json                   Output in JSON format"
    echo "  --quiet                  Minimal output"
    echo "  --verbose                Verbose output"
    echo "  --help, -h               Show this help message"
    echo
    echo "Examples:"
    echo "  $0                       # Quick check"
    echo "  $0 full                  # Comprehensive check"
    echo "  $0 interactive           # Interactive mode"
    echo "  $0 connection --verbose  # Detailed connection check"
    echo "  $0 report --json         # Generate JSON report"
}

# Main function
main() {
    local command="quick"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            quick|full|interactive|health|connection|ssh|tunnel|logs|security|report)
                command="$1"
                shift
                ;;
            --no-reports)
                SAVE_REPORTS=false
                shift
                ;;
            --report-dir)
                REPORT_DIR="$2"
                shift 2
                ;;
            --json)
                OUTPUT_FORMAT="json"
                shift
                ;;
            --quiet)
                LOG_LEVEL="ERROR"
                shift
                ;;
            --verbose)
                LOG_LEVEL="DEBUG"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Initialize diagnostics
    init_diagnostics
    
    # Execute command
    case "$command" in
        "quick")
            run_quick_check
            ;;
        "full")
            run_full_check
            ;;
        "interactive")
            run_interactive_mode
            ;;
        "health"|"connection"|"ssh"|"tunnel"|"logs"|"security")
            run_category_check "$command"
            ;;
        "report")
            generate_comprehensive_report
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi