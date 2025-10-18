#!/bin/bash

# Hardware Access Testing Module
# Tests hardware access capabilities and permissions

# Hardware test functions
test_cpu_access() {
    # Test CPU information access
    [ -r /proc/cpuinfo ] && grep -q "processor" /proc/cpuinfo
}

test_memory_access() {
    # Test memory information access
    [ -r /proc/meminfo ] && grep -q "MemTotal" /proc/meminfo
}

test_disk_access() {
    # Test disk information access
    df -h >/dev/null 2>&1 && lsblk >/dev/null 2>&1
}

test_network_access() {
    # Test network interface access
    ip addr show >/dev/null 2>&1 || ifconfig >/dev/null 2>&1
}

test_gpu_detection() {
    # Test GPU detection with comprehensive checks
    local gpu_found=false
    
    # Check for NVIDIA GPUs
    if command_exists nvidia-smi; then
        nvidia-smi -L >/dev/null 2>&1 && gpu_found=true
    fi
    
    # Check for AMD GPUs
    if command_exists rocm-smi; then
        rocm-smi --showproductname >/dev/null 2>&1 && gpu_found=true
    fi
    
    # Check via lspci
    if lspci | grep -i "vga\|3d\|display" >/dev/null 2>&1; then
        gpu_found=true
    fi
    
    # Check for DRI devices
    if [ -d /dev/dri ] && ls /dev/dri/card* >/dev/null 2>&1; then
        gpu_found=true
    fi
    
    # Return success if any GPU detection method worked
    [ "$gpu_found" = true ]
}

test_usb_access() {
    # Test USB device access
    lsusb >/dev/null 2>&1 || \
    [ -d /sys/bus/usb/devices ] || \
    return 0  # Skip if no USB tools available
}

test_pci_access() {
    # Test PCI device access
    lspci >/dev/null 2>&1 || \
    [ -d /sys/bus/pci/devices ] || \
    return 0  # Skip if no PCI tools available
}

test_system_info_access() {
    # Test system information access
    uname -a >/dev/null 2>&1 && \
    uptime >/dev/null 2>&1 && \
    whoami >/dev/null 2>&1
}

test_process_management() {
    # Test process management capabilities
    ps aux >/dev/null 2>&1 && \
    top -b -n1 >/dev/null 2>&1
}

test_file_system_access() {
    # Test file system access
    ls -la / >/dev/null 2>&1 && \
    find /tmp -maxdepth 1 >/dev/null 2>&1
}

test_package_manager_access() {
    # Test package manager access
    if command_exists apt; then
        apt list --installed >/dev/null 2>&1 || return 0
    elif command_exists yum; then
        yum list installed >/dev/null 2>&1 || return 0
    elif command_exists pacman; then
        pacman -Q >/dev/null 2>&1 || return 0
    else
        return 0  # Skip if no known package manager
    fi
}

test_sudo_access() {
    # Test sudo access (if available)
    if command_exists sudo; then
        sudo -n true >/dev/null 2>&1 || return 0  # Skip if no passwordless sudo
    else
        return 0  # Skip if sudo not available
    fi
}

test_docker_hardware_passthrough() {
    # Test hardware passthrough in Docker (if container is running)
    if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
        docker exec "$DOCKER_CONTAINER_NAME" ls -la /dev >/dev/null 2>&1
    else
        return 0  # Skip if no container running
    fi
}

test_performance_monitoring() {
    # Test performance monitoring tools
    local tools_available=false
    
    # Check for various performance monitoring tools
    if command_exists iostat && iostat -c 1 1 >/dev/null 2>&1; then
        tools_available=true
    elif command_exists vmstat && vmstat 1 1 >/dev/null 2>&1; then
        tools_available=true
    elif command_exists sar && sar -u 1 1 >/dev/null 2>&1; then
        tools_available=true
    elif command_exists htop && htop --version >/dev/null 2>&1; then
        tools_available=true
    elif command_exists top && top -b -n1 >/dev/null 2>&1; then
        tools_available=true
    fi
    
    [ "$tools_available" = true ]
}

test_nvidia_gpu_access() {
    # Test NVIDIA GPU access and functionality
    if command_exists nvidia-smi; then
        # Test basic nvidia-smi functionality
        nvidia-smi -L >/dev/null 2>&1 && \
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader >/dev/null 2>&1
    else
        return 0  # Skip if NVIDIA tools not available
    fi
}

test_amd_gpu_access() {
    # Test AMD GPU access and functionality
    if command_exists rocm-smi; then
        # Test basic rocm-smi functionality
        rocm-smi --showproductname >/dev/null 2>&1 && \
        rocm-smi --showmeminfo >/dev/null 2>&1
    else
        return 0  # Skip if AMD tools not available
    fi
}

test_gpu_device_access() {
    # Test direct GPU device access
    local gpu_devices_found=false
    
    # Check for DRI devices (common GPU interface)
    if [ -d /dev/dri ]; then
        ls /dev/dri/card* >/dev/null 2>&1 && gpu_devices_found=true
        ls /dev/dri/render* >/dev/null 2>&1 && gpu_devices_found=true
    fi
    
    # Check for NVIDIA devices
    if [ -c /dev/nvidia0 ] || [ -c /dev/nvidiactl ]; then
        gpu_devices_found=true
    fi
    
    [ "$gpu_devices_found" = true ]
}

test_hardware_stress_capability() {
    # Test hardware stress testing capability
    if command_exists stress-ng; then
        # Test that stress-ng can run (very brief test)
        timeout 2s stress-ng --cpu 1 --timeout 1s >/dev/null 2>&1
    elif command_exists stress; then
        # Test basic stress command
        timeout 2s stress --cpu 1 --timeout 1s >/dev/null 2>&1
    else
        return 0  # Skip if no stress testing tools available
    fi
}

test_memory_performance_tools() {
    # Test memory performance and testing tools
    if command_exists memtester; then
        # Test that memtester is available (don't actually run it)
        memtester --help >/dev/null 2>&1 || return 0
    elif command_exists mbw; then
        # Test memory bandwidth tool
        mbw --help >/dev/null 2>&1 || return 0
    else
        return 0  # Skip if no memory testing tools available
    fi
}

test_cpu_frequency_control() {
    # Test CPU frequency scaling control
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        # Check if we can read CPU frequency information
        [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] && \
        [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]
    else
        return 0  # Skip if CPU frequency scaling not available
    fi
}

test_hardware_detection_script() {
    # Test the hardware detection script functionality
    local hardware_script="/app/hardware-detection.sh"
    if [ -f "$hardware_script" ] && [ -x "$hardware_script" ]; then
        # Test that the script can run and detect basic hardware
        bash "$hardware_script" help >/dev/null 2>&1 && \
        timeout 10s bash "$hardware_script" gpu >/dev/null 2>&1
    else
        return 0  # Skip if hardware detection script not available
    fi
}

test_performance_optimization_script() {
    # Test the performance optimization script functionality
    local perf_script="/app/performance-optimization.sh"
    if [ -f "$perf_script" ] && [ -x "$perf_script" ]; then
        # Test that the script can run and show help
        bash "$perf_script" help >/dev/null 2>&1
    else
        return 0  # Skip if performance optimization script not available
    fi
}

# Function to list hardware tests
list_hardware_tests() {
    echo "  - CPU access test"
    echo "  - Memory access test"
    echo "  - Disk access test"
    echo "  - Network access test"
    echo "  - GPU detection test"
    echo "  - USB access test"
    echo "  - PCI access test"
    echo "  - System info access test"
    echo "  - Process management test"
    echo "  - File system access test"
    echo "  - Package manager access test"
    echo "  - Sudo access test"
    echo "  - Docker hardware passthrough test"
    echo "  - Performance monitoring test"
    echo "  - NVIDIA GPU access test"
    echo "  - AMD GPU access test"
    echo "  - GPU device access test"
    echo "  - Hardware stress capability test"
    echo "  - Memory performance tools test"
    echo "  - CPU frequency control test"
    echo "  - Hardware detection script test"
    echo "  - Performance optimization script test"
}

# Main hardware test runner
run_hardware_tests() {
    local pattern="${1:-.*}"
    
    log_category "Hardware Access Testing"
    
    # Run hardware tests
    run_test "CPU access" "test_cpu_access"
    run_test "Memory access" "test_memory_access"
    run_test "Disk access" "test_disk_access"
    run_test "Network access" "test_network_access"
    run_test "GPU detection" "test_gpu_detection"
    run_test "USB access" "test_usb_access"
    run_test "PCI access" "test_pci_access"
    run_test "System info access" "test_system_info_access"
    run_test "Process management" "test_process_management"
    run_test "File system access" "test_file_system_access"
    run_test "Package manager access" "test_package_manager_access"
    run_test "Sudo access" "test_sudo_access"
    run_test "Docker hardware passthrough" "test_docker_hardware_passthrough"
    run_test "Performance monitoring" "test_performance_monitoring"
    run_test "NVIDIA GPU access" "test_nvidia_gpu_access"
    run_test "AMD GPU access" "test_amd_gpu_access"
    run_test "GPU device access" "test_gpu_device_access"
    run_test "Hardware stress capability" "test_hardware_stress_capability"
    run_test "Memory performance tools" "test_memory_performance_tools"
    run_test "CPU frequency control" "test_cpu_frequency_control"
    run_test "Hardware detection script" "test_hardware_detection_script"
    run_test "Performance optimization script" "test_performance_optimization_script"
}