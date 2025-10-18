#!/bin/bash

# Performance Optimization Script for Hardware-Intensive Tasks
# Configures system for optimal performance with Jules

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root or with sudo
check_privileges() {
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        log_error "This script requires root privileges or passwordless sudo"
        exit 1
    fi
}

# CPU Performance Optimizations
optimize_cpu() {
    log_header "CPU Performance Optimization"
    
    # Set CPU governor to performance mode
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        log_info "Setting CPU governor to performance mode..."
        
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [ -w "$cpu" ]; then
                echo "performance" | sudo tee "$cpu" >/dev/null 2>&1 || true
            fi
        done
        
        # Verify governor setting
        local current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
        if [ "$current_governor" = "performance" ]; then
            log_success "CPU governor set to performance mode"
        else
            log_warning "Could not set CPU governor to performance mode (current: $current_governor)"
        fi
    else
        log_warning "CPU frequency scaling not available"
    fi
    
    # Disable CPU idle states for maximum performance (if available)
    if [ -f /sys/devices/system/cpu/cpu0/cpuidle/state1/disable ]; then
        log_info "Disabling deep CPU idle states for lower latency..."
        for state in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
            if [[ "$state" =~ state[2-9] ]] && [ -w "$state" ]; then
                echo 1 | sudo tee "$state" >/dev/null 2>&1 || true
            fi
        done
        log_success "Deep CPU idle states disabled"
    fi
    
    # Set CPU affinity recommendations
    local cpu_count=$(nproc)
    log_info "Available CPU cores: $cpu_count"
    log_info "Use 'taskset -c 0-$((cpu_count-1)) <command>' for CPU affinity"
    
    echo
}

# Memory Performance Optimizations
optimize_memory() {
    log_header "Memory Performance Optimization"
    
    # Configure swappiness for better performance
    log_info "Configuring memory swappiness..."
    local current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    
    if [ "$current_swappiness" -gt 10 ]; then
        echo 10 | sudo tee /proc/sys/vm/swappiness >/dev/null 2>&1 || true
        log_success "Swappiness set to 10 (was $current_swappiness)"
    else
        log_info "Swappiness already optimized: $current_swappiness"
    fi
    
    # Configure dirty page writeback for better I/O performance
    log_info "Optimizing dirty page writeback..."
    echo 15 | sudo tee /proc/sys/vm/dirty_background_ratio >/dev/null 2>&1 || true
    echo 30 | sudo tee /proc/sys/vm/dirty_ratio >/dev/null 2>&1 || true
    log_success "Dirty page writeback optimized"
    
    # Enable transparent huge pages if available
    if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
        log_info "Enabling transparent huge pages..."
        echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
        echo always | sudo tee /sys/kernel/mm/transparent_hugepage/defrag >/dev/null 2>&1 || true
        log_success "Transparent huge pages enabled"
    fi
    
    # Memory information
    local total_mem_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    log_info "Total memory: ${total_mem_gb}GB"
    
    if [ $total_mem_gb -gt 8 ]; then
        log_info "Consider using tmpfs for temporary files: mount -t tmpfs -o size=4G tmpfs /tmp"
    fi
    
    echo
}

# GPU Performance Optimizations
optimize_gpu() {
    log_header "GPU Performance Optimization"
    
    # NVIDIA GPU optimizations
    if command_exists nvidia-smi; then
        log_info "NVIDIA GPU detected, applying optimizations..."
        
        # Set persistence mode
        sudo nvidia-smi -pm 1 >/dev/null 2>&1 && log_success "NVIDIA persistence mode enabled" || log_warning "Could not enable NVIDIA persistence mode"
        
        # Set maximum performance mode
        sudo nvidia-smi -ac $(nvidia-smi --query-gpu=clocks.max.memory,clocks.max.sm --format=csv,noheader,nounits | tr ',' ' ') >/dev/null 2>&1 && \
            log_success "NVIDIA GPU clocks set to maximum" || log_warning "Could not set NVIDIA GPU clocks"
        
        # Display GPU information
        log_info "GPU Status:"
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null | \
            while IFS=, read -r name temp util mem_used mem_total; do
                echo "  GPU: $name"
                echo "  Temperature: $temp"
                echo "  Utilization: $util"
                echo "  Memory: $mem_used / $mem_total"
            done
    else
        log_warning "No NVIDIA GPU detected or nvidia-smi not available"
    fi
    
    # AMD GPU optimizations
    if command_exists rocm-smi; then
        log_info "AMD GPU detected, applying optimizations..."
        
        # Set performance level to high
        sudo rocm-smi --setperflevel high >/dev/null 2>&1 && log_success "AMD GPU performance level set to high" || log_warning "Could not set AMD GPU performance level"
        
        # Display GPU information
        log_info "AMD GPU Status:"
        rocm-smi --showproductname --showtemp --showuse --showmeminfo 2>/dev/null || log_warning "Could not retrieve AMD GPU status"
    else
        log_info "No AMD GPU detected or rocm-smi not available"
    fi
    
    # Check for GPU devices
    if [ -d /dev/dri ]; then
        log_info "DRI devices available:"
        ls -la /dev/dri/ 2>/dev/null | grep -E "(card|render)" | while read -r line; do
            echo "  $line"
        done
    fi
    
    echo
}

# Storage Performance Optimizations
optimize_storage() {
    log_header "Storage Performance Optimization"
    
    # I/O scheduler optimization
    log_info "Optimizing I/O schedulers..."
    
    for disk in /sys/block/sd* /sys/block/nvme*; do
        if [ -d "$disk" ] && [ -f "$disk/queue/scheduler" ]; then
            local disk_name=$(basename "$disk")
            local current_scheduler=$(cat "$disk/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]')
            
            # Set appropriate scheduler based on disk type
            if [[ "$disk_name" =~ nvme ]]; then
                # NVMe drives work best with none or mq-deadline
                if grep -q "none" "$disk/queue/scheduler"; then
                    echo none | sudo tee "$disk/queue/scheduler" >/dev/null 2>&1 || true
                    log_success "Set $disk_name scheduler to none (NVMe optimized)"
                elif grep -q "mq-deadline" "$disk/queue/scheduler"; then
                    echo mq-deadline | sudo tee "$disk/queue/scheduler" >/dev/null 2>&1 || true
                    log_success "Set $disk_name scheduler to mq-deadline"
                fi
            else
                # SATA drives work well with mq-deadline or deadline
                if grep -q "mq-deadline" "$disk/queue/scheduler"; then
                    echo mq-deadline | sudo tee "$disk/queue/scheduler" >/dev/null 2>&1 || true
                    log_success "Set $disk_name scheduler to mq-deadline"
                elif grep -q "deadline" "$disk/queue/scheduler"; then
                    echo deadline | sudo tee "$disk/queue/scheduler" >/dev/null 2>&1 || true
                    log_success "Set $disk_name scheduler to deadline"
                fi
            fi
        fi
    done
    
    # Increase read-ahead for better sequential performance
    log_info "Optimizing read-ahead settings..."
    for disk in /sys/block/sd* /sys/block/nvme*; do
        if [ -d "$disk" ] && [ -f "$disk/queue/read_ahead_kb" ]; then
            local disk_name=$(basename "$disk")
            echo 4096 | sudo tee "$disk/queue/read_ahead_kb" >/dev/null 2>&1 || true
            log_success "Set $disk_name read-ahead to 4MB"
        fi
    done
    
    # Display storage information
    log_info "Storage devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null || log_warning "Could not list block devices"
    
    echo
}

# Network Performance Optimizations
optimize_network() {
    log_header "Network Performance Optimization"
    
    # TCP buffer optimizations
    log_info "Optimizing TCP buffers..."
    
    # Increase TCP buffer sizes
    echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    echo 'net.ipv4.tcp_rmem = 4096 87380 134217728' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    echo 'net.ipv4.tcp_wmem = 4096 65536 134217728' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    
    # Apply settings immediately
    sudo sysctl -p >/dev/null 2>&1 || true
    
    log_success "TCP buffer sizes optimized"
    
    # Display network interfaces
    log_info "Network interfaces:"
    if command_exists ip; then
        ip addr show | grep -E "(inet |UP)" | head -10
    else
        log_warning "ip command not available"
    fi
    
    echo
}

# System-wide Performance Optimizations
optimize_system() {
    log_header "System Performance Optimization"
    
    # Increase file descriptor limits
    log_info "Optimizing file descriptor limits..."
    
    # Set limits for current session
    ulimit -n 65536 2>/dev/null || true
    
    # Configure system-wide limits
    if [ -d /etc/security/limits.d ]; then
        cat > /tmp/jules-limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
        sudo mv /tmp/jules-limits.conf /etc/security/limits.d/jules-limits.conf 2>/dev/null || true
        log_success "File descriptor limits increased"
    fi
    
    # Optimize kernel parameters
    log_info "Optimizing kernel parameters..."
    
    # Increase maximum number of memory map areas
    echo 'vm.max_map_count = 262144' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    
    # Optimize for performance over power saving
    echo 'kernel.sched_migration_cost_ns = 5000000' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
    
    # Apply settings
    sudo sysctl -p >/dev/null 2>&1 || true
    
    log_success "Kernel parameters optimized"
    
    echo
}

# Performance Monitoring Setup
setup_monitoring() {
    log_header "Performance Monitoring Setup"
    
    log_info "Available monitoring tools:"
    
    # Check for performance monitoring tools
    command_exists htop && echo "  ✓ htop - Interactive process viewer"
    command_exists iotop && echo "  ✓ iotop - I/O monitoring"
    command_exists iostat && echo "  ✓ iostat - I/O statistics"
    command_exists vmstat && echo "  ✓ vmstat - Virtual memory statistics"
    command_exists sar && echo "  ✓ sar - System activity reporter"
    command_exists nvidia-smi && echo "  ✓ nvidia-smi - NVIDIA GPU monitoring"
    command_exists rocm-smi && echo "  ✓ rocm-smi - AMD GPU monitoring"
    
    # Create monitoring aliases
    log_info "Creating performance monitoring aliases..."
    
    cat > /tmp/performance_aliases.sh << 'EOF'
# Performance monitoring aliases for Jules
alias gpu-status='nvidia-smi || rocm-smi || echo "No GPU monitoring available"'
alias cpu-freq='cat /proc/cpuinfo | grep "cpu MHz" | head -4'
alias mem-usage='free -h && echo && cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Cached|Buffers)"'
alias disk-usage='df -h && echo && iostat -x 1 1 2>/dev/null || echo "iostat not available"'
alias network-usage='ss -tuln | head -10 && echo && cat /proc/net/dev | head -5'
alias system-load='uptime && echo && vmstat 1 2 | tail -1 2>/dev/null || echo "vmstat not available"'
alias performance-summary='echo "=== System Performance Summary ===" && system-load && echo && mem-usage && echo && gpu-status'
EOF
    
    # Add to bashrc for jules user
    if [ -f "/home/jules/.bashrc" ]; then
        cat /tmp/performance_aliases.sh >> /home/jules/.bashrc
        log_success "Performance aliases added to jules user"
    fi
    
    rm -f /tmp/performance_aliases.sh
    
    echo
}

# Stress Testing Functions
run_stress_tests() {
    log_header "Performance Stress Testing"
    
    if ! command_exists stress-ng; then
        log_warning "stress-ng not available, skipping stress tests"
        return
    fi
    
    log_info "Running quick performance stress tests..."
    
    # CPU stress test (5 seconds)
    log_info "CPU stress test (5 seconds)..."
    stress-ng --cpu $(nproc) --timeout 5s --quiet 2>/dev/null && log_success "CPU stress test completed" || log_warning "CPU stress test failed"
    
    # Memory stress test (5 seconds)
    log_info "Memory stress test (5 seconds)..."
    stress-ng --vm 2 --vm-bytes 1G --timeout 5s --quiet 2>/dev/null && log_success "Memory stress test completed" || log_warning "Memory stress test failed"
    
    # I/O stress test (5 seconds)
    log_info "I/O stress test (5 seconds)..."
    stress-ng --io 4 --timeout 5s --quiet 2>/dev/null && log_success "I/O stress test completed" || log_warning "I/O stress test failed"
    
    echo
}

# Performance Report
generate_performance_report() {
    log_header "Performance Configuration Report"
    
    local report_file="/tmp/performance_report.txt"
    
    {
        echo "Performance Optimization Report"
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo
        
        echo "CPU Configuration:"
        echo "  Cores: $(nproc)"
        echo "  Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")"
        echo "  Current Frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{print $1/1000 " MHz"}' || echo "N/A")"
        echo
        
        echo "Memory Configuration:"
        echo "  Total: $(grep MemTotal /proc/meminfo | awk '{print $2/1024/1024 " GB"}')"
        echo "  Swappiness: $(cat /proc/sys/vm/swappiness)"
        echo "  Huge Pages: $(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "N/A")"
        echo
        
        echo "GPU Configuration:"
        if command_exists nvidia-smi; then
            nvidia-smi --query-gpu=name,persistence_mode,power.management --format=csv,noheader 2>/dev/null | while IFS=, read -r name persistence power; do
                echo "  NVIDIA GPU: $name"
                echo "  Persistence Mode: $persistence"
                echo "  Power Management: $power"
            done
        else
            echo "  No NVIDIA GPU detected"
        fi
        echo
        
        echo "Storage Configuration:"
        for disk in /sys/block/sd* /sys/block/nvme*; do
            if [ -d "$disk" ]; then
                local disk_name=$(basename "$disk")
                local scheduler=$(cat "$disk/queue/scheduler" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]' || echo "N/A")
                local readahead=$(cat "$disk/queue/read_ahead_kb" 2>/dev/null || echo "N/A")
                echo "  $disk_name: scheduler=$scheduler, read-ahead=${readahead}KB"
            fi
        done
        echo
        
    } > "$report_file"
    
    log_success "Performance report saved to: $report_file"
    cat "$report_file"
}

# Restore default settings
restore_defaults() {
    log_header "Restoring Default Performance Settings"
    
    log_info "Restoring CPU governor to ondemand..."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -w "$cpu" ]; then
            echo "ondemand" | sudo tee "$cpu" >/dev/null 2>&1 || true
        fi
    done
    
    log_info "Restoring swappiness to default..."
    echo 60 | sudo tee /proc/sys/vm/swappiness >/dev/null 2>&1 || true
    
    log_info "Restoring NVIDIA GPU settings..."
    if command_exists nvidia-smi; then
        sudo nvidia-smi -pm 0 >/dev/null 2>&1 || true
        sudo nvidia-smi -rac >/dev/null 2>&1 || true
    fi
    
    log_success "Default settings restored"
    echo
}

# Main function
main() {
    local action="${1:-optimize}"
    
    case "$action" in
        "optimize"|"")
            check_privileges
            optimize_cpu
            optimize_memory
            optimize_gpu
            optimize_storage
            optimize_network
            optimize_system
            setup_monitoring
            log_success "Performance optimization completed!"
            ;;
        "test")
            run_stress_tests
            ;;
        "report")
            generate_performance_report
            ;;
        "restore")
            check_privileges
            restore_defaults
            ;;
        "cpu")
            check_privileges
            optimize_cpu
            ;;
        "memory")
            check_privileges
            optimize_memory
            ;;
        "gpu")
            check_privileges
            optimize_gpu
            ;;
        "storage")
            check_privileges
            optimize_storage
            ;;
        "network")
            check_privileges
            optimize_network
            ;;
        "monitor")
            setup_monitoring
            ;;
        "help")
            echo "Usage: $0 [optimize|test|report|restore|cpu|memory|gpu|storage|network|monitor|help]"
            echo
            echo "Commands:"
            echo "  optimize  - Apply all performance optimizations (default)"
            echo "  test      - Run performance stress tests"
            echo "  report    - Generate performance configuration report"
            echo "  restore   - Restore default performance settings"
            echo "  cpu       - Optimize CPU performance only"
            echo "  memory    - Optimize memory performance only"
            echo "  gpu       - Optimize GPU performance only"
            echo "  storage   - Optimize storage performance only"
            echo "  network   - Optimize network performance only"
            echo "  monitor   - Set up performance monitoring tools"
            echo "  help      - Show this help message"
            ;;
        *)
            log_error "Unknown action: $action"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"