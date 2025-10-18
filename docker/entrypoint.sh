#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Load security validation modules and diagnostics
if [[ -f "/app/diagnostics/error-handler.sh" ]]; then
    source "/app/diagnostics/error-handler.sh"
    set_error_context "component" "docker-entrypoint"
fi

if [[ -f "/app/ssh-key-validator.sh" ]]; then
    source "/app/ssh-key-validator.sh"
fi

# Function to validate environment variables
validate_environment() {
    log_info "Validating environment variables..."
    
    local validation_failed=false
    
    # Check required environment variables
    if [ -z "$JULES_SSH_PUBLIC_KEY" ]; then
        log_error "JULES_SSH_PUBLIC_KEY environment variable is required"
        validation_failed=true
    fi
    
    if [ -z "$CLOUDFLARE_TOKEN" ]; then
        log_error "CLOUDFLARE_TOKEN environment variable is required"
        validation_failed=true
    fi
    
    # Enhanced SSH public key validation
    if [ -n "$JULES_SSH_PUBLIC_KEY" ]; then
        if command -v validate_ssh_key_comprehensive &> /dev/null; then
            log_info "Using enhanced SSH key validation..."
            if validate_ssh_key_comprehensive "$JULES_SSH_PUBLIC_KEY" 2048; then
                log_success "SSH public key validation passed (enhanced)"
            else
                log_error "SSH public key validation failed (enhanced)"
                validation_failed=true
            fi
        else
            # Fallback to basic validation
            if ! echo "$JULES_SSH_PUBLIC_KEY" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '; then
                log_error "JULES_SSH_PUBLIC_KEY does not appear to be a valid SSH public key"
                log_error "Expected format: ssh-rsa AAAAB3... or ssh-ed25519 AAAAC3..."
                validation_failed=true
            else
                log_success "SSH public key format validation passed (basic)"
            fi
        fi
    fi
    
    # Validate Cloudflare token format (basic check)
    if [ -n "$CLOUDFLARE_TOKEN" ]; then
        if [ ${#CLOUDFLARE_TOKEN} -lt 32 ]; then
            log_error "CLOUDFLARE_TOKEN appears to be too short (expected at least 32 characters)"
            validation_failed=true
        else
            log_success "Cloudflare token format validation passed"
        fi
    fi
    
    # Check optional environment variables and set defaults
    if [ -z "$SSH_PORT" ]; then
        export SSH_PORT=22
        log_info "SSH_PORT not set, using default: 22"
    fi
    
    if [ -z "$JULES_USERNAME" ]; then
        export JULES_USERNAME=jules
        log_info "JULES_USERNAME not set, using default: jules"
    fi
    
    if [ "$validation_failed" = true ]; then
        handle_error $E_CONFIG "Environment validation failed. Please check the required environment variables." "docker-entrypoint" "environment-validation"
    fi
    
    log_success "Environment validation completed successfully"
}

# Function to create and configure the jules user
setup_user() {
    log_info "Setting up user account for $JULES_USERNAME..."
    
    # Create user if it doesn't exist
    if ! id "$JULES_USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$JULES_USERNAME"
        log_success "Created user: $JULES_USERNAME"
    else
        log_info "User $JULES_USERNAME already exists"
    fi
    
    # Configure passwordless sudo access with enhanced security
    local sudoers_file="/etc/sudoers.d/jules-endpoint-agent"
    echo "$JULES_USERNAME ALL=(ALL) NOPASSWD:ALL" > "$sudoers_file"
    chmod 440 "$sudoers_file"
    
    # Verify sudoers file syntax
    if ! visudo -c -f "$sudoers_file"; then
        log_error "Failed to configure sudo access. Sudoers file syntax error."
        rm -f "$sudoers_file"
        exit 1
    fi
    
    log_success "Configured passwordless sudo for $JULES_USERNAME"
    
    # Set up SSH directory and keys with enhanced validation
    local ssh_dir="/home/$JULES_USERNAME/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    
    mkdir -p "$ssh_dir"
    
    # Sanitize SSH key before writing
    local sanitized_key="$JULES_SSH_PUBLIC_KEY"
    if command -v sanitize_ssh_key &> /dev/null; then
        sanitized_key=$(sanitize_ssh_key "$JULES_SSH_PUBLIC_KEY")
    fi
    
    echo "$sanitized_key" > "$auth_keys_file"
    
    # Set proper ownership and permissions
    chown -R "$JULES_USERNAME:$JULES_USERNAME" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys_file"
    
    # Validate SSH setup if validation function is available
    if command -v validate_ssh_setup &> /dev/null; then
        if validate_ssh_setup "$sanitized_key" "$JULES_USERNAME"; then
            log_success "SSH setup validation passed"
        else
            log_warning "SSH setup validation encountered issues"
        fi
    fi
    
    log_success "SSH key configured for $JULES_USERNAME"
}

# Function to configure SSH server
configure_ssh() {
    log_info "Configuring SSH server..."
    
    # Ensure SSH host keys exist
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        ssh-keygen -A
        log_success "Generated SSH host keys"
    fi
    
    # Create SSH run directory
    mkdir -p /run/sshd
    
    # Verify SSH configuration
    if ! /usr/sbin/sshd -t; then
        log_error "SSH configuration test failed"
        exit 1
    fi
    
    log_success "SSH server configuration validated"
}

# Function to start cloudflared tunnel with reliability monitoring
start_cloudflared() {
    log_info "Starting Cloudflare tunnel with reliability monitoring..."
    
    # Test cloudflared connectivity first
    if ! cloudflared tunnel --help &>/dev/null; then
        log_error "cloudflared binary is not working properly"
        exit 1
    fi
    
    # Start cloudflared tunnel with proper SSH protocol configuration
    cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TOKEN" &
    local cloudflared_pid=$!
    
    # Wait a moment for cloudflared to start
    sleep 3
    
    # Check if cloudflared is still running
    if ! kill -0 $cloudflared_pid 2>/dev/null; then
        log_error "cloudflared failed to start or exited immediately"
        log_error "Please check your CLOUDFLARE_TOKEN and ensure the tunnel is properly configured"
        exit 1
    fi
    
    log_success "Cloudflare tunnel started successfully (PID: $cloudflared_pid)"
    
    # Store PID for cleanup
    echo $cloudflared_pid > /var/run/cloudflared.pid
    
    # Start tunnel reliability monitoring in background
    if [ -f "/app/diagnostics/tunnel-reliability.sh" ]; then
        log_info "Starting tunnel reliability monitoring..."
        bash "/app/diagnostics/tunnel-reliability.sh" monitor &
        local monitor_pid=$!
        echo $monitor_pid > /var/run/tunnel-monitor.pid
        log_success "Tunnel reliability monitoring started (PID: $monitor_pid)"
    else
        log_warn "Tunnel reliability monitoring script not found"
    fi
}

# Function to generate connection information
generate_connection_info() {
    log_info "Generating connection information..."
    
    # Wait a moment for cloudflared to establish connection
    sleep 3
    
    # Try to run the connection info generator
    local connection_script="/app/connection-info.sh"
    if [ -f "$connection_script" ]; then
        log_info "Running connection information generator..."
        bash "$connection_script" || log_warning "Connection info generator failed, but continuing..."
    else
        log_warning "Connection info generator not found at $connection_script"
        log_info "You can manually check connection status after container starts"
    fi
    
    echo
    log_success "=== Container Ready ==="
    log_info "Jules can connect once the tunnel hostname is available"
    log_info "Run 'docker exec <container> /app/connection-info.sh' to get connection details"
    echo
}

# Function to detect and report hardware
detect_hardware() {
    log_info "Detecting available hardware..."
    
    local hardware_script="/app/hardware-detection.sh"
    if [ -f "$hardware_script" ]; then
        log_info "Running hardware detection..."
        bash "$hardware_script" gpu 2>/dev/null | head -20 || log_warning "Hardware detection failed, but continuing..."
    else
        log_warning "Hardware detection script not found"
    fi
    
    echo
}

# Function to apply performance optimizations
apply_performance_optimizations() {
    log_info "Applying performance optimizations for hardware-intensive tasks..."
    
    local perf_script="/app/performance-optimization.sh"
    if [ -f "$perf_script" ]; then
        # Apply basic optimizations that don't require extensive privileges
        bash "$perf_script" monitor 2>/dev/null || log_warning "Performance monitoring setup failed, but continuing..."
        
        # Try to apply CPU optimizations if possible
        if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] 2>/dev/null; then
            bash "$perf_script" cpu 2>/dev/null || log_warning "CPU optimization failed, but continuing..."
        fi
        
        log_success "Performance optimizations applied"
    else
        log_warning "Performance optimization script not found"
    fi
    
    echo
}

# Function to start SSH server
start_ssh() {
    log_info "Starting SSH server on port $SSH_PORT..."
    
    # Start SSH server in the foreground
    exec /usr/sbin/sshd -D -p "$SSH_PORT"
}

# Function to handle cleanup on exit
cleanup() {
    log_info "Shutting down services..."
    
    # Kill tunnel reliability monitor if it's running
    if [ -f /var/run/tunnel-monitor.pid ]; then
        local monitor_pid=$(cat /var/run/tunnel-monitor.pid)
        if kill -0 $monitor_pid 2>/dev/null; then
            kill $monitor_pid
            log_info "Stopped tunnel reliability monitor"
        fi
        rm -f /var/run/tunnel-monitor.pid
    fi
    
    # Kill cloudflared if it's running
    if [ -f /var/run/cloudflared.pid ]; then
        local cloudflared_pid=$(cat /var/run/cloudflared.pid)
        if kill -0 $cloudflared_pid 2>/dev/null; then
            kill $cloudflared_pid
            log_info "Stopped cloudflared tunnel"
        fi
        rm -f /var/run/cloudflared.pid
    fi
    
    log_info "Cleanup completed"
}

# Set up signal handlers for graceful shutdown
trap cleanup EXIT INT TERM

# Main execution flow
main() {
    log_info "Starting Jules Endpoint Agent (Docker)"
    log_info "======================================="
    
    # Step 1: Validate environment
    validate_environment
    
    # Step 2: Set up user account
    setup_user
    
    # Step 3: Configure SSH server
    configure_ssh
    
    # Step 4: Detect hardware capabilities
    detect_hardware
    
    # Step 5: Apply performance optimizations
    apply_performance_optimizations
    
    # Step 6: Start cloudflared tunnel
    start_cloudflared
    
    # Step 7: Generate connection information
    generate_connection_info
    
    # Step 8: Start SSH server (this will run in foreground)
    log_success "All services configured successfully"
    log_info "Agent is ready for connections with hardware access"
    start_ssh
}

# Run main function
main "$@"