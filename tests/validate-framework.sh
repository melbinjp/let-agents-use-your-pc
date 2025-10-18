#!/bin/bash

# Validation script for the testing framework
# This script validates that all test components are properly configured

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation counters
VALIDATIONS_PASSED=0
VALIDATIONS_FAILED=0
VALIDATIONS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((VALIDATIONS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((VALIDATIONS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Validation functions
validate_file_exists() {
    local file="$1"
    local description="$2"
    
    ((VALIDATIONS_TOTAL++))
    if [ -f "$file" ]; then
        log_success "$description exists: $file"
        return 0
    else
        log_failure "$description missing: $file"
        return 1
    fi
}

validate_script_syntax() {
    local script="$1"
    local description="$2"
    
    ((VALIDATIONS_TOTAL++))
    if bash -n "$script" 2>/dev/null; then
        log_success "$description syntax valid"
        return 0
    else
        log_failure "$description syntax invalid"
        return 1
    fi
}

validate_function_exists() {
    local script="$1"
    local function_name="$2"
    local description="$3"
    
    ((VALIDATIONS_TOTAL++))
    if grep -q "^$function_name()" "$script" || grep -q "^function $function_name" "$script"; then
        log_success "$description function exists: $function_name"
        return 0
    else
        log_failure "$description function missing: $function_name"
        return 1
    fi
}

# Main validation
main() {
    log_info "Testing Framework Validation"
    log_info "============================"
    echo
    
    # Validate core framework files
    log_info "Validating core framework files..."
    validate_file_exists "tests/test-framework.sh" "Main test framework"
    validate_file_exists "tests/run-tests.sh" "Test runner script"
    validate_file_exists "tests/README.md" "Framework documentation"
    
    echo
    
    # Validate test modules
    log_info "Validating test modules..."
    validate_file_exists "tests/modules/docker-tests.sh" "Docker test module"
    validate_file_exists "tests/modules/ssh-tests.sh" "SSH test module"
    validate_file_exists "tests/modules/tunnel-tests.sh" "Tunnel test module"
    validate_file_exists "tests/modules/hardware-tests.sh" "Hardware test module"
    validate_file_exists "tests/modules/integration-tests.sh" "Integration test module"
    
    echo
    
    # Validate script syntax
    log_info "Validating script syntax..."
    validate_script_syntax "tests/test-framework.sh" "Main framework"
    validate_script_syntax "tests/run-tests.sh" "Test runner"
    
    for module in tests/modules/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module" .sh)
            validate_script_syntax "$module" "Module: $module_name"
        fi
    done
    
    echo
    
    # Validate required functions in modules
    log_info "Validating required functions..."
    
    # Docker module functions
    if [ -f "tests/modules/docker-tests.sh" ]; then
        validate_function_exists "tests/modules/docker-tests.sh" "run_docker_tests" "Docker module"
        validate_function_exists "tests/modules/docker-tests.sh" "list_docker_tests" "Docker module"
        validate_function_exists "tests/modules/docker-tests.sh" "cleanup_docker_tests" "Docker module"
    fi
    
    # SSH module functions
    if [ -f "tests/modules/ssh-tests.sh" ]; then
        validate_function_exists "tests/modules/ssh-tests.sh" "run_ssh_tests" "SSH module"
        validate_function_exists "tests/modules/ssh-tests.sh" "list_ssh_tests" "SSH module"
    fi
    
    # Tunnel module functions
    if [ -f "tests/modules/tunnel-tests.sh" ]; then
        validate_function_exists "tests/modules/tunnel-tests.sh" "run_tunnel_tests" "Tunnel module"
        validate_function_exists "tests/modules/tunnel-tests.sh" "list_tunnel_tests" "Tunnel module"
    fi
    
    # Hardware module functions
    if [ -f "tests/modules/hardware-tests.sh" ]; then
        validate_function_exists "tests/modules/hardware-tests.sh" "run_hardware_tests" "Hardware module"
        validate_function_exists "tests/modules/hardware-tests.sh" "list_hardware_tests" "Hardware module"
    fi
    
    # Integration module functions
    if [ -f "tests/modules/integration-tests.sh" ]; then
        validate_function_exists "tests/modules/integration-tests.sh" "run_integration_tests" "Integration module"
        validate_function_exists "tests/modules/integration-tests.sh" "list_integration_tests" "Integration module"
        validate_function_exists "tests/modules/integration-tests.sh" "cleanup_integration_tests" "Integration module"
    fi
    
    echo
    
    # Validate framework structure
    log_info "Validating framework structure..."
    
    ((VALIDATIONS_TOTAL++))
    if [ -d "tests/modules" ]; then
        log_success "Test modules directory exists"
    else
        log_failure "Test modules directory missing"
    fi
    
    ((VALIDATIONS_TOTAL++))
    local module_count=$(find tests/modules -name "*.sh" | wc -l)
    if [ "$module_count" -ge 5 ]; then
        log_success "All test modules present ($module_count modules)"
    else
        log_failure "Missing test modules (found $module_count, expected 5)"
    fi
    
    echo
    
    # Show validation summary
    log_info "Validation Summary"
    log_info "=================="
    echo "Total validations: $VALIDATIONS_TOTAL"
    echo -e "Passed: ${GREEN}$VALIDATIONS_PASSED${NC}"
    echo -e "Failed: ${RED}$VALIDATIONS_FAILED${NC}"
    
    local success_rate=0
    if [ $VALIDATIONS_TOTAL -gt 0 ]; then
        success_rate=$((VALIDATIONS_PASSED * 100 / VALIDATIONS_TOTAL))
    fi
    
    echo "Success rate: ${success_rate}%"
    
    if [ $VALIDATIONS_FAILED -eq 0 ]; then
        echo
        log_success "All validations passed! Testing framework is ready."
        echo
        log_info "You can now run tests using:"
        echo "  ./tests/run-tests.sh --list    # List available tests"
        echo "  ./tests/run-tests.sh all       # Run all tests"
        echo "  ./tests/run-tests.sh docker    # Run Docker tests"
        echo
        return 0
    else
        echo
        log_failure "Some validations failed. Please review the issues above."
        return 1
    fi
}

# Run validation
main "$@"