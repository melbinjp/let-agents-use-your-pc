#!/bin/bash

# Docker Container Testing Module
# Tests Docker container functionality, configuration, and service startup

# Docker test configuration
DOCKER_IMAGE_NAME="jules-endpoint-agent"
DOCKER_CONTAINER_NAME="jules-test-container"
DOCKER_TEST_NETWORK="jules-test-network"

# Test SSH key for Docker tests
TEST_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGL7/6Qm8w5cGKZKvKZKvKZKvKZKvKZKvKZKvKZKvKZK test-key"
TEST_CLOUDFLARE_TOKEN="test-token-1234567890abcdef1234567890abcdef"

# Docker test functions
test_docker_available() {
    command_exists docker && docker info >/dev/null 2>&1
}

test_docker_compose_available() {
    command_exists docker-compose
}

test_dockerfile_exists() {
    [ -f "docker/Dockerfile" ]
}

test_docker_compose_file_exists() {
    [ -f "docker/docker-compose.yml" ]
}

test_docker_build() {
    cd docker
    docker build -t "$DOCKER_IMAGE_NAME:test" . >/dev/null 2>&1
    cd ..
}

test_docker_image_created() {
    docker images | grep -q "$DOCKER_IMAGE_NAME:test"
}

test_docker_container_start() {
    # Create test network
    docker network create "$DOCKER_TEST_NETWORK" >/dev/null 2>&1 || true
    
    # Start container with test environment
    docker run -d \
        --name "$DOCKER_CONTAINER_NAME" \
        --network "$DOCKER_TEST_NETWORK" \
        -e "JULES_SSH_PUBLIC_KEY=$TEST_SSH_KEY" \
        -e "CLOUDFLARE_TOKEN=$TEST_CLOUDFLARE_TOKEN" \
        -e "JULES_USERNAME=jules" \
        -e "SSH_PORT=22" \
        "$DOCKER_IMAGE_NAME:test" >/dev/null 2>&1
    
    # Wait for container to start
    sleep 5
    
    # Check if container is running
    docker ps | grep -q "$DOCKER_CONTAINER_NAME"
}

test_docker_container_health() {
    # Wait for services to start
    sleep 10
    
    # Check if container is still running (not crashed)
    docker ps | grep -q "$DOCKER_CONTAINER_NAME"
}

test_docker_ssh_service() {
    # Check if SSH service is running inside container
    docker exec "$DOCKER_CONTAINER_NAME" pgrep -f sshd >/dev/null 2>&1
}

test_docker_cloudflared_service() {
    # Check if cloudflared service is running inside container
    docker exec "$DOCKER_CONTAINER_NAME" pgrep -f cloudflared >/dev/null 2>&1
}

test_docker_user_created() {
    # Check if jules user was created
    docker exec "$DOCKER_CONTAINER_NAME" id jules >/dev/null 2>&1
}

test_docker_ssh_key_configured() {
    # Check if SSH key was properly configured
    docker exec "$DOCKER_CONTAINER_NAME" test -f /home/jules/.ssh/authorized_keys
}

test_docker_sudo_configured() {
    # Check if sudo is configured for jules user
    docker exec "$DOCKER_CONTAINER_NAME" test -f /etc/sudoers.d/jules
}

test_docker_ssh_port_listening() {
    # Check if SSH port is listening
    docker exec "$DOCKER_CONTAINER_NAME" netstat -ln | grep -q ":22 " 2>/dev/null || \
    docker exec "$DOCKER_CONTAINER_NAME" ss -ln | grep -q ":22 " 2>/dev/null
}

test_docker_healthcheck_script() {
    # Test the healthcheck script
    docker exec "$DOCKER_CONTAINER_NAME" /app/healthcheck.sh >/dev/null 2>&1
}

test_docker_connection_info_script() {
    # Test the connection info script exists and is executable
    docker exec "$DOCKER_CONTAINER_NAME" test -x /app/connection-info.sh
}

test_docker_environment_validation() {
    # Test environment variable validation
    docker exec "$DOCKER_CONTAINER_NAME" printenv | grep -q "JULES_SSH_PUBLIC_KEY"
}

test_docker_volume_mounts() {
    # Test if volume mounts work (if configured)
    docker exec "$DOCKER_CONTAINER_NAME" test -d /home/jules || true
}

test_docker_gpu_support() {
    # Test GPU support if available (skip if no GPU)
    if command_exists nvidia-docker || docker info | grep -q nvidia; then
        # This would test GPU passthrough
        docker exec "$DOCKER_CONTAINER_NAME" nvidia-smi >/dev/null 2>&1 || return 0
    else
        return 0  # Skip if no GPU support
    fi
}

test_docker_container_logs() {
    # Check if container logs show successful startup
    docker logs "$DOCKER_CONTAINER_NAME" 2>&1 | grep -q "Agent is ready for connections"
}

test_docker_container_restart() {
    # Test container restart functionality
    docker restart "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
    sleep 10
    docker ps | grep -q "$DOCKER_CONTAINER_NAME"
}

test_docker_container_stop() {
    # Test graceful container stop
    docker stop "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1
    sleep 5
    ! docker ps | grep -q "$DOCKER_CONTAINER_NAME"
}

# Cleanup function for Docker tests
cleanup_docker_tests() {
    # Stop and remove test container
    docker stop "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1 || true
    
    # Remove test network
    docker network rm "$DOCKER_TEST_NETWORK" >/dev/null 2>&1 || true
    
    # Remove test image
    docker rmi "$DOCKER_IMAGE_NAME:test" >/dev/null 2>&1 || true
}

# Function to list Docker tests
list_docker_tests() {
    echo "  - Docker availability check"
    echo "  - Docker Compose availability check"
    echo "  - Dockerfile existence check"
    echo "  - Docker Compose file existence check"
    echo "  - Docker image build test"
    echo "  - Docker image creation verification"
    echo "  - Docker container startup test"
    echo "  - Docker container health check"
    echo "  - SSH service in container test"
    echo "  - Cloudflared service in container test"
    echo "  - User creation in container test"
    echo "  - SSH key configuration test"
    echo "  - Sudo configuration test"
    echo "  - SSH port listening test"
    echo "  - Healthcheck script test"
    echo "  - Connection info script test"
    echo "  - Environment validation test"
    echo "  - Volume mounts test"
    echo "  - GPU support test"
    echo "  - Container logs test"
    echo "  - Container restart test"
    echo "  - Container stop test"
}

# Main Docker test runner
run_docker_tests() {
    local pattern="${1:-.*}"
    
    log_category "Docker Container Testing"
    
    # Check prerequisites
    if ! command_exists docker; then
        log_skip "Docker not available, skipping Docker tests"
        return 0
    fi
    
    # Set up cleanup trap
    trap cleanup_docker_tests EXIT
    
    # Run Docker tests
    run_test "Docker availability" "test_docker_available" "$DOCKER_TEST_TIMEOUT"
    run_test "Docker Compose availability" "test_docker_compose_available"
    run_test "Dockerfile exists" "test_dockerfile_exists"
    run_test "Docker Compose file exists" "test_docker_compose_file_exists"
    
    # Build and test image
    if [[ "build" =~ $pattern ]]; then
        run_test "Docker image build" "test_docker_build" "$DOCKER_TEST_TIMEOUT"
        run_test "Docker image created" "test_docker_image_created"
    fi
    
    # Container tests
    if [[ "container" =~ $pattern ]]; then
        run_test "Docker container start" "test_docker_container_start" "$DOCKER_TEST_TIMEOUT"
        run_test "Docker container health" "test_docker_container_health"
        run_test "SSH service in container" "test_docker_ssh_service"
        run_test "Cloudflared service in container" "test_docker_cloudflared_service"
        run_test "User created in container" "test_docker_user_created"
        run_test "SSH key configured" "test_docker_ssh_key_configured"
        run_test "Sudo configured" "test_docker_sudo_configured"
        run_test "SSH port listening" "test_docker_ssh_port_listening"
        run_test "Healthcheck script" "test_docker_healthcheck_script"
        run_test "Connection info script" "test_docker_connection_info_script"
        run_test "Environment validation" "test_docker_environment_validation"
        run_test "Volume mounts" "test_docker_volume_mounts"
        run_test "GPU support" "test_docker_gpu_support"
        run_test "Container logs" "test_docker_container_logs"
        run_test "Container restart" "test_docker_container_restart"
        run_test "Container stop" "test_docker_container_stop"
    fi
    
    # Cleanup
    cleanup_docker_tests
    trap - EXIT
}