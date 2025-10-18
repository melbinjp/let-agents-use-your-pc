#!/bin/bash

# Hardware Detection and Reporting Script
# Provides comprehensive hardware information for Jules

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

# CPU Information
detect_cpu() {
    log_header "CPU Information"
    
    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        local cpu_threads=$(nproc)
        
        echo "Model: $cpu_model"
        echo "Physical Cores: $cpu_cores"
        echo "Threads: $cpu_threads"
        
        if command_exists lscpu; then
            echo
            echo "Detailed CPU Information:"
            lscpu | grep -E "(Architecture|CPU op-mode|Byte Order|CPU\(s\)|Thread|Core|Socket|NUMA|Vendor ID|CPU family|Model|Model name|Stepping|CPU MHz|CPU max MHz|CPU min MHz|BogoMIPS|Virtualization|L1d cache|L1i cache|L2 cache|L3 cache|Flags)"
        fi
    else
        log_warning "CPU information not available"
    fi
    echo
}

# Memory Information
detect_memory() {
    log_header "Memory Information"
    
    if [ -f /proc/meminfo ]; then
        local total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local available_mem=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null || grep "MemFree" /proc/meminfo | awk '{print $2}')
        
        echo "Total Memory: $((total_mem / 1024)) MB"
        echo "Available Memory: $((available_mem / 1024)) MB"
        
        echo
        echo "Detailed Memory Information:"
        grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree)" /proc/meminfo
    else
        log_warning "Memory information not available"
    fi
    echo
}

# GPU Information
detect_gpu() {
    log_header "GPU Information"
    
    local gpu_found=false
    
    # Check for NVIDIA GPUs
    if command_exists nvidia-smi; then
        echo "NVIDIA GPU detected:"
        nvidia-smi --query-gpu=name,memory.total,driver_version,cuda_version --format=csv,noheader,nounits 2>/dev/null || \
        nvidia-smi -L 2>/dev/null || \
        echo "NVIDIA GPU present but nvidia-smi failed"
        gpu_found=true
        echo
    fi
    
    # Check for AMD GPUs
    if command_exists rocm-smi; then
        echo "AMD GPU detected:"
        rocm-smi --showproductname --showmeminfo --showdriverversion 2>/dev/null || \
        echo "AMD GPU tools present but rocm-smi failed"
        gpu_found=true
        echo
    fi
    
    # Check via lspci
    if command_exists lspci; then
        local gpu_devices=$(lspci | grep -i "vga\|3d\|display")
        if [ -n "$gpu_devices" ]; then
            echo "GPU devices detected via PCI:"
            echo "$gpu_devices"
            gpu_found=true
            echo
        fi
    fi
    
    # Check via lshw
    if command_exists lshw; then
        local display_info=$(lshw -c display 2>/dev/null | grep -E "(product|vendor|driver|capabilities)")
        if [ -n "$display_info" ]; then
            echo "Display hardware information:"
            echo "$display_info"
            gpu_found=true
            echo
        fi
    fi
    
    # Check /dev/dri for GPU devices
    if [ -d /dev/dri ]; then
        local dri_devices=$(ls -la /dev/dri/ 2>/dev/null)
        if [ -n "$dri_devices" ]; then
            echo "DRI devices available:"
            echo "$dri_devices"
            gpu_found=true
            echo
        fi
    fi
    
    if [ "$gpu_found" = false ]; then
        log_warning "No GPU devices detected"
    fi
    echo
}

# Storage Information
detect_storage() {
    log_header "Storage Information"
    
    echo "Disk Usage:"
    df -h 2>/dev/null || log_warning "Disk usage information not available"
    echo
    
    if command_exists lsblk; then
        echo "Block Devices:"
        lsblk 2>/dev/null || log_warning "Block device information not available"
        echo
    fi
    
    if command_exists smartctl; then
        echo "SMART Status (first few drives):"
        for device in /dev/sd[a-c] /dev/nvme[0-2]; do
            if [ -e "$device" ]; then
                echo "Device: $device"
                smartctl -H "$device" 2>/dev/null | grep -E "(overall-health|SMART Health Status)" || echo "  SMART not available"
            fi
        done
        echo
    fi
}

# Network Information
detect_network() {
    log_header "Network Information"
    
    if command_exists ip; then
        echo "Network Interfaces:"
        ip addr show 2>/dev/null | grep -E "(inet |inet6 )" | awk '{print $NF ": " $2}' || log_warning "Network interface information not available"
        echo
    elif command_exists ifconfig; then
        echo "Network Interfaces:"
        ifconfig 2>/dev/null | grep -E "(inet |inet6 )" || log_warning "Network interface information not available"
        echo
    fi
}

# USB Devices
detect_usb() {
    log_header "USB Devices"
    
    if command_exists lsusb; then
        lsusb 2>/dev/null || log_warning "USB device information not available"
    else
        log_warning "lsusb command not available"
    fi
    echo
}

# PCI Devices
detect_pci() {
    log_header "PCI Devices"
    
    if command_exists lspci; then
        echo "Key PCI Devices:"
        lspci 2>/dev/null | grep -E "(VGA|Audio|Ethernet|Network|USB|SATA|NVMe)" || log_warning "PCI device information not available"
    else
        log_warning "lspci command not available"
    fi
    echo
}

# System Information
detect_system() {
    log_header "System Information"
    
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo "Unknown")"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo
}

# Performance Capabilities
detect_performance() {
    log_header "Performance Capabilities"
    
    # CPU frequency information
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        echo "CPU Frequency Scaling:"
        local current_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
        local min_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null)
        
        [ -n "$current_freq" ] && echo "  Current: $((current_freq / 1000)) MHz"
        [ -n "$max_freq" ] && echo "  Maximum: $((max_freq / 1000)) MHz"
        [ -n "$min_freq" ] && echo "  Minimum: $((min_freq / 1000)) MHz"
    fi
    
    # Available performance tools
    echo
    echo "Available Performance Tools:"
    command_exists stress-ng && echo "  ✓ stress-ng (CPU/memory stress testing)"
    command_exists memtester && echo "  ✓ memtester (memory testing)"
    command_exists iotop && echo "  ✓ iotop (I/O monitoring)"
    command_exists iostat && echo "  ✓ iostat (I/O statistics)"
    command_exists vmstat && echo "  ✓ vmstat (virtual memory statistics)"
    command_exists sar && echo "  ✓ sar (system activity reporter)"
    command_exists htop && echo "  ✓ htop (interactive process viewer)"
    command_exists top && echo "  ✓ top (process viewer)"
    echo
}

# Hardware Access Permissions
check_hardware_permissions() {
    log_header "Hardware Access Permissions"
    
    echo "Device Access:"
    [ -r /dev/mem ] && echo "  ✓ /dev/mem (physical memory)" || echo "  ✗ /dev/mem (physical memory)"
    [ -r /dev/kmem ] && echo "  ✓ /dev/kmem (kernel memory)" || echo "  ✗ /dev/kmem (kernel memory)"
    [ -d /dev/dri ] && echo "  ✓ /dev/dri (GPU devices)" || echo "  ✗ /dev/dri (GPU devices)"
    [ -c /dev/nvidia0 ] && echo "  ✓ /dev/nvidia0 (NVIDIA GPU)" || echo "  ✗ /dev/nvidia0 (NVIDIA GPU)"
    
    echo
    echo "System Access:"
    [ -r /proc/cpuinfo ] && echo "  ✓ CPU information" || echo "  ✗ CPU information"
    [ -r /proc/meminfo ] && echo "  ✓ Memory information" || echo "  ✗ Memory information"
    [ -r /sys/class/dmi/id/product_name ] && echo "  ✓ DMI information" || echo "  ✗ DMI information"
    
    echo
    echo "Sudo Access:"
    if sudo -n true 2>/dev/null; then
        echo "  ✓ Passwordless sudo available"
    else
        echo "  ✗ Passwordless sudo not available"
    fi
    echo
}

# Container-specific checks
check_container_hardware() {
    log_header "Container Hardware Access"
    
    echo "Container Environment:"
    [ -f /.dockerenv ] && echo "  ✓ Running in Docker container" || echo "  ✗ Not in Docker container"
    
    echo
    echo "Mounted Devices:"
    ls -la /dev/ 2>/dev/null | grep -E "(nvidia|dri|fb)" | head -10 || echo "  No special devices mounted"
    
    echo
    echo "Privileged Mode:"
    if [ -w /sys ]; then
        echo "  ✓ Write access to /sys (likely privileged)"
    else
        echo "  ✗ No write access to /sys"
    fi
    
    echo
    echo "Capabilities:"
    if command_exists capsh; then
        capsh --print 2>/dev/null | grep "Current:" || echo "  Capability information not available"
    else
        echo "  capsh not available for capability check"
    fi
    echo
}

# Generate hardware report
generate_hardware_report() {
    local output_file="${1:-/tmp/hardware_report.txt}"
    
    log_info "Generating comprehensive hardware report..."
    
    {
        echo "Hardware Detection Report"
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo
        
        detect_system
        detect_cpu
        detect_memory
        detect_gpu
        detect_storage
        detect_network
        detect_usb
        detect_pci
        detect_performance
        check_hardware_permissions
        check_container_hardware
        
    } > "$output_file"
    
    log_success "Hardware report saved to: $output_file"
    
    # Also display summary
    echo
    log_header "Hardware Summary"
    grep -E "(Model:|Total Memory:|NVIDIA|AMD|GPU|✓|✗)" "$output_file" | head -20
}

# Performance optimization suggestions
suggest_optimizations() {
    log_header "Performance Optimization Suggestions"
    
    # CPU optimizations
    local cpu_cores=$(nproc)
    echo "CPU Optimizations:"
    echo "  - Available cores: $cpu_cores"
    echo "  - Consider using 'taskset' for CPU affinity"
    echo "  - Use 'nice' and 'ionice' for process prioritization"
    
    # Memory optimizations
    local total_mem_gb=$(($(grep "MemTotal" /proc/meminfo | awk '{print $2}') / 1024 / 1024))
    echo
    echo "Memory Optimizations:"
    echo "  - Total memory: ${total_mem_gb}GB"
    if [ $total_mem_gb -gt 8 ]; then
        echo "  - Consider using tmpfs for temporary files"
        echo "  - Enable huge pages for memory-intensive applications"
    fi
    
    # GPU optimizations
    echo
    echo "GPU Optimizations:"
    if command_exists nvidia-smi; then
        echo "  - NVIDIA GPU detected - use CUDA for acceleration"
        echo "  - Set CUDA_VISIBLE_DEVICES for GPU selection"
        echo "  - Monitor GPU usage with nvidia-smi"
    else
        echo "  - No NVIDIA GPU detected"
        echo "  - Check for OpenCL support for general GPU computing"
    fi
    
    # Storage optimizations
    echo
    echo "Storage Optimizations:"
    echo "  - Use SSD for better I/O performance"
    echo "  - Consider using 'iotop' to monitor disk usage"
    echo "  - Use 'sync' and 'drop_caches' for memory management"
    
    echo
}

# Main function
main() {
    local action="${1:-detect}"
    
    case "$action" in
        "detect"|"")
            detect_system
            detect_cpu
            detect_memory
            detect_gpu
            detect_storage
            detect_network
            detect_usb
            detect_pci
            detect_performance
            check_hardware_permissions
            check_container_hardware
            ;;
        "report")
            generate_hardware_report "$2"
            ;;
        "optimize")
            suggest_optimizations
            ;;
        "gpu")
            detect_gpu
            ;;
        "permissions")
            check_hardware_permissions
            ;;
        "container")
            check_container_hardware
            ;;
        "help")
            echo "Usage: $0 [detect|report|optimize|gpu|permissions|container|help]"
            echo
            echo "Commands:"
            echo "  detect      - Show all hardware information (default)"
            echo "  report      - Generate detailed report file"
            echo "  optimize    - Show performance optimization suggestions"
            echo "  gpu         - Show only GPU information"
            echo "  permissions - Check hardware access permissions"
            echo "  container   - Check container-specific hardware access"
            echo "  help        - Show this help message"
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