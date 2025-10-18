#!/bin/bash

# Comprehensive Testing Framework for Remote Hardware Access System
# This framework implements automated testing for Docker containers, SSH connections,
# tunnel connectivity, and hardware access validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
TEST_TIMEOUT=30
DOCKER_TEST_TIMEOUT=120
SSH_TEST_TIMEOUT=15
TUNNEL_TEST_TIMEOUT=60

# Test result counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_TOTAL=0

# Test categories
declare -A TEST_CATEGORIES=(
    ["docker"]="Docker Container Testing"
    ["ssh"]="SSH Connection Validation"
    ["tunnel"]="Tunnel Connectivity Verification"
    ["hardware"]="Hardware Access Testing"
    ["integration"]="Integration Testing"
    ["security"]="Security and User Management"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_skip() {
    echo -e "${CYAN}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

log_category() {
    echo
    echo -e "${CYAN}=== $1 ===${NC}"
    echo
}

# Helper function to run a test with timeout and error handling
run_test() {
    local test_name="$1"
    local test_function="$2"
    local timeout_duration="${3:-$TEST_TIMEOUT}"
    
    ((TESTS_TOTAL++))
    log_info "Running: $test_name"
    
    if timeout "$timeout_duration" bash -c "$test_function" 2>/dev/null; then
        log_success "$test_name"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_failure "$test_name (timeout after ${timeout_duration}s)"
        else
            log_failure "$test_name (exit code: $exit_code)"
        fi
        return 1
    fi
}

# Helper function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Helper function to check if a port is open
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
}

# Helper function to generate test SSH key pair
generate_test_keys() {
    local key_dir="$1"
    mkdir -p "$key_dir"
    
    if [ ! -f "$key_dir/test_key" ]; then
        ssh-keygen -t ed25519 -f "$key_dir/test_key" -N "" -C "test-key-$(date +%s)" >/dev/null 2>&1
    fi
}

# Helper function to cleanup test resources
cleanup_test_resources() {
    local cleanup_function="$1"
    if [ -n "$cleanup_function" ]; then
        eval "$cleanup_function" 2>/dev/null || true
    fi
}

# Load test modules
source_test_modules() {
    local test_dir="$(dirname "$0")"
    
    # Source all test modules
    for module in "$test_dir"/modules/*.sh; do
        if [ -f "$module" ]; then
            source "$module"
        fi
    done
}

# Main test execution function
run_test_suite() {
    local category="$1"
    local test_pattern="${2:-.*}"
    
    case "$category" in
        "docker")
            run_docker_tests "$test_pattern"
            ;;
        "ssh")
            run_ssh_tests "$test_pattern"
            ;;
        "tunnel")
            run_tunnel_tests "$test_pattern"
            ;;
        "hardware")
            run_hardware_tests "$test_pattern"
            ;;
        "integration")
            run_integration_tests "$test_pattern"
            ;;
        "security")
            run_security_tests "$test_pattern"
            ;;
        "all")
            run_docker_tests "$test_pattern"
            run_ssh_tests "$test_pattern"
            run_tunnel_tests "$test_pattern"
            run_hardware_tests "$test_pattern"
            run_integration_tests "$test_pattern"
            run_security_tests "$test_pattern"
            ;;
        *)
            log_failure "Unknown test category: $category"
            return 1
            ;;
    esac
}

# Function to display test results summary
show_test_summary() {
    echo
    log_info "Test Results Summary"
    log_info "===================="
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped: ${CYAN}$TESTS_SKIPPED${NC}"
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo "Success rate: ${success_rate}%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo
        log_success "All tests passed!"
        return 0
    else
        echo
        log_failure "Some tests failed. Please review the issues above."
        return 1
    fi
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] [CATEGORY] [PATTERN]"
    echo
    echo "Test Categories:"
    for category in "${!TEST_CATEGORIES[@]}"; do
        echo "  $category - ${TEST_CATEGORIES[$category]}"
    done
    echo "  all - Run all test categories"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -t, --timeout  Set test timeout (default: $TEST_TIMEOUT)"
    echo "  --list         List available tests"
    echo
    echo "Examples:"
    echo "  $0 docker                    # Run all Docker tests"
    echo "  $0 ssh connection            # Run SSH tests matching 'connection'"
    echo "  $0 all                       # Run all tests"
    echo "  $0 --list                    # List all available tests"
}

# Function to list available tests
list_tests() {
    echo "Available Tests:"
    echo "================"
    
    for category in "${!TEST_CATEGORIES[@]}"; do
        echo
        echo "$category (${TEST_CATEGORIES[$category]}):"
        
        # This would be implemented by each test module
        case "$category" in
            "docker")
                list_docker_tests 2>/dev/null || echo "  (Docker tests module not loaded)"
                ;;
            "ssh")
                list_ssh_tests 2>/dev/null || echo "  (SSH tests module not loaded)"
                ;;
            "tunnel")
                list_tunnel_tests 2>/dev/null || echo "  (Tunnel tests module not loaded)"
                ;;
            "hardware")
                list_hardware_tests 2>/dev/null || echo "  (Hardware tests module not loaded)"
                ;;
            "integration")
                list_integration_tests 2>/dev/null || echo "  (Integration tests module not loaded)"
                ;;
            "security")
                list_security_tests 2>/dev/null || echo "  (Security tests module not loaded)"
                ;;
        esac
    done
}

# Main function
main() {
    local category="all"
    local pattern=".*"
    local verbose=false
    local list_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                set -x
                shift
                ;;
            -t|--timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --list)
                list_only=true
                shift
                ;;
            -*)
                log_failure "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$category" ] || [ "$category" = "all" ]; then
                    category="$1"
                else
                    pattern="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Show header
    echo -e "${CYAN}Remote Hardware Access System - Test Framework${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo
    
    # List tests if requested
    if [ "$list_only" = true ]; then
        list_tests
        exit 0
    fi
    
    # Load test modules
    source_test_modules
    
    # Validate category
    if [ "$category" != "all" ] && [ -z "${TEST_CATEGORIES[$category]:-}" ]; then
        log_failure "Invalid test category: $category"
        echo
        show_usage
        exit 1
    fi
    
    # Run tests
    log_info "Running tests for category: $category"
    if [ "$pattern" != ".*" ]; then
        log_info "Test pattern: $pattern"
    fi
    echo
    
    # Execute test suite
    if run_test_suite "$category" "$pattern"; then
        show_test_summary
        exit $?
    else
        show_test_summary
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi