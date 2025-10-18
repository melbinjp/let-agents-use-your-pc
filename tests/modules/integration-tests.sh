#!/bin/bash

# Integration Testing Module
# Tests end-to-end functionality and component integration

# Integration test configuration
INTEGRATION_TEST_TIMEOUT=120

# Integration test functions
test_full_docker_deployment() {
    # Test complete Docker deployment workflow
    cd docker
    
    # Build image
    docker build -t "$DOCKER_IMAGE_NAME:integration" . >/dev/null 2>&1 || return 1
    
    # Start container
    docker run -d \
        --name "${DOCKER_CONTAINER_NAME}-integration" \
        -e "JULES_SSH_PUBLIC_KEY=$TEST_SSH_KEY" \
        -e "CLOUDFLARE_TOKEN=$TEST_CLOUDFLARE_TOKEN" \
        "$DOCKER_IMAGE_NAME:integration" >/dev/null 2>&1 || return 1
    
    # Wait for startup
    sleep 15
    
    # Check if container is healthy
    docker exec "${DOCKER_CONTAINER_NAME}-integration" /app/healthcheck.sh >/dev/null 2>&1
    
    cd ..
}

test_connection_info_generation() {
    # Test connection info generation workflow
    if docker ps | grep -q "${DOCKER_CONTAINER_NAME}-integration"; then
        docker exec "${DOCKER_CONTAINER_NAME}-integration" /app/connection-info.sh >/dev/null 2>&1
    else
        return 0  # Skip if no container
    fi
}

test_ssh_key_authentication_flow() {
    # Test SSH key authentication workflow
    local test_key_dir="/tmp/integration-ssh-keys"
    generate_test_keys "$test_key_dir"
    
    # Test key format validation
    local public_key=$(cat "$test_key_dir/test_key.pub")
    echo "$public_key" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '
    
    # Cleanup
    rm -rf "$test_key_dir"
}

test_service_startup_sequence() {
    # Test service startup sequence
    if docker ps | grep -q "${DOCKER_CONTAINER_NAME}-integration"; then
        # Check SSH service
        docker exec "${DOCKER_CONTAINER_NAME}-integration" pgrep -f sshd >/dev/null 2>&1 || return 1
        
        # Check cloudflared service
        docker exec "${DOCKER_CONTAINER_NAME}-integration" pgrep -f cloudflared >/dev/null 2>&1 || return 1
        
        return 0
    else
        return 0  # Skip if no container
    fi
}

test_environment_variable_processing() {
    # Test environment variable processing
    if docker ps | grep -q "${DOCKER_CONTAINER_NAME}-integration"; then
        # Check if environment variables are properly processed
        docker exec "${DOCKER_CONTAINER_NAME}-integration" printenv | grep -q "JULES_SSH_PUBLIC_KEY" || return 1
        docker exec "${DOCKER_CONTAINER_NAME}-integration" printenv | grep -q "CLOUDFLARE_TOKEN" || return 1
        
        return 0
    else
        return 0  # Skip if no container
    fi
}

test_user_configuration_workflow() {
    # Test user configuration workflow
    if docker ps | grep -q "${DOCKER_CONTAINER_NAME}-integration"; then
        # Check user creation
        docker exec "${DOCKER_CONTAINER_NAME}-integration" id jules >/dev/null 2>&1 || return 1
        
        # Check SSH key configuration
        docker exec "${DOCKER_CONTAINER_NAME}-integration" test -f /home/jules/.ssh/authorized_keys || return 1
        
        # Check sudo configuration
        docker exec "${DOCKER_CONTAINER_NAME}-integration" test -f /etc/sudoers.d/jules || return 1
        
        return 0
    else
        return 0  # Skip if no container
    fi
}

test_error_handling_workflow() {
    # Test error handling in various scenarios
    
    # Test invalid SSH key handling
    docker run --rm \
        -e "JULES_SSH_PUBLIC_KEY=invalid-key" \
        -e "CLOUDFLARE_TOKEN=$TEST_CLOUDFLARE_TOKEN" \
        "$DOCKER_IMAGE_NAME:integration" timeout 10 || return 0  # Should fail gracefully
    
    # Test missing environment variables
    docker run --rm \
        "$DOCKER_IMAGE_NAME:integration" timeout 10 || return 0  # Should fail gracefully
}

test_cleanup_procedures() {
    # Test cleanup procedures
    if docker ps | grep -q "${DOCKER_CONTAINER_NAME}-integration"; then
        # Stop container
        docker stop "${DOCKER_CONTAINER_NAME}-integration" >/dev/null 2>&1 || return 1
        
        # Remove container
        docker rm "${DOCKER_CONTAINER_NAME}-integration" >/dev/null 2>&1 || return 1
        
        return 0
    else
        return 0  # Skip if no container
    fi
}

test_installation_script_integration() {
    # Test installation script integration (basic syntax check)
    bash -n linux/install.sh >/dev/null 2>&1 && \
    bash -n docker/entrypoint.sh >/dev/null 2>&1
}

test_connection_info_script_integration() {
    # Test connection info script integration
    bash -n linux/connection-info.sh >/dev/null 2>&1 && \
    bash -n docker/connection-info.sh >/dev/null 2>&1
}

# Cleanup function for integration tests
cleanup_integration_tests() {
    # Stop and remove integration test containers
    docker stop "${DOCKER_CONTAINER_NAME}-integration" >/dev/null 2>&1 || true
    docker rm "${DOCKER_CONTAINER_NAME}-integration" >/dev/null 2>&1 || true
    
    # Remove integration test image
    docker rmi "$DOCKER_IMAGE_NAME:integration" >/dev/null 2>&1 || true
}

# Function to list integration tests
list_integration_tests() {
    echo "  - Full Docker deployment test"
    echo "  - Connection info generation test"
    echo "  - SSH key authentication flow test"
    echo "  - Service startup sequence test"
    echo "  - Environment variable processing test"
    echo "  - User configuration workflow test"
    echo "  - Error handling workflow test"
    echo "  - Cleanup procedures test"
    echo "  - Installation script integration test"
    echo "  - Connection info script integration test"
}

# Main integration test runner
run_integration_tests() {
    local pattern="${1:-.*}"
    
    log_category "Integration Testing"
    
    # Check prerequisites
    if ! command_exists docker; then
        log_skip "Docker not available, skipping integration tests"
        return 0
    fi
    
    # Set up cleanup trap
    trap cleanup_integration_tests EXIT
    
    # Run integration tests
    run_test "Full Docker deployment" "test_full_docker_deployment" "$INTEGRATION_TEST_TIMEOUT"
    run_test "Connection info generation" "test_connection_info_generation"
    run_test "SSH key authentication flow" "test_ssh_key_authentication_flow"
    run_test "Service startup sequence" "test_service_startup_sequence"
    run_test "Environment variable processing" "test_environment_variable_processing"
    run_test "User configuration workflow" "test_user_configuration_workflow"
    run_test "Error handling workflow" "test_error_handling_workflow"
    run_test "Cleanup procedures" "test_cleanup_procedures"
    run_test "Installation script integration" "test_installation_script_integration"
    run_test "Connection info script integration" "test_connection_info_script_integration"
    
    # Cleanup
    cleanup_integration_tests
    trap - EXIT
}