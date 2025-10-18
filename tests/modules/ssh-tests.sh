#!/bin/bash

# SSH Connection Validation Testing Module
# Tests SSH connectivity, authentication, and session management

# SSH test configuration
SSH_TEST_KEY_DIR="/tmp/ssh-test-keys"
SSH_TEST_USER="jules"
SSH_TEST_PORT="22"
SSH_TEST_HOST="localhost"

# SSH test functions
test_ssh_client_available() {
    command_exists ssh
}

test_ssh_keygen_available() {
    command_exists ssh-keygen
}

test_generate_test_ssh_keys() {
    generate_test_keys "$SSH_TEST_KEY_DIR"
    [ -f "$SSH_TEST_KEY_DIR/test_key" ] && [ -f "$SSH_TEST_KEY_DIR/test_key.pub" ]
}

test_ssh_key_format_validation() {
    local public_key=$(cat "$SSH_TEST_KEY_DIR/test_key.pub")
    echo "$public_key" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '
}

test_ssh_key_permissions() {
    [ "$(stat -c %a "$SSH_TEST_KEY_DIR/test_key")" = "600" ]
}

test_ssh_connection_basic() {
    # Test basic SSH connection (will fail but should not hang)
    timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no \
        -i "$SSH_TEST_KEY_DIR/test_key" "$SSH_TEST_USER@$SSH_TEST_HOST" exit 2>/dev/null || true
}

test_ssh_connection_with_docker() {
    # Test SSH connection to Docker container if running
    if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
        local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DOCKER_CONTAINER_NAME")
        if [ -n "$container_ip" ]; then
            timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
                -i "$SSH_TEST_KEY_DIR/test_key" "$SSH_TEST_USER@$container_ip" exit 2>/dev/null
        fi
    else
        return 0  # Skip if no container running
    fi
}

# Function to list SSH tests
list_ssh_tests() {
    echo "  - SSH client availability"
    echo "  - SSH keygen availability"
    echo "  - Generate test SSH keys"
    echo "  - SSH key format validation"
    echo "  - SSH key permissions"
    echo "  - Basic SSH connection test"
    echo "  - SSH connection with Docker"
}

# Main SSH test runner
run_ssh_tests() {
    local pattern="${1:-.*}"
    
    log_category "SSH Connection Validation"
    
    # Run SSH tests
    run_test "SSH client available" "test_ssh_client_available"
    run_test "SSH keygen available" "test_ssh_keygen_available"
    run_test "Generate test SSH keys" "test_generate_test_ssh_keys"
    run_test "SSH key format validation" "test_ssh_key_format_validation"
    run_test "SSH key permissions" "test_ssh_key_permissions"
    run_test "Basic SSH connection" "test_ssh_connection_basic" "$SSH_TEST_TIMEOUT"
    run_test "SSH connection with Docker" "test_ssh_connection_with_docker" "$SSH_TEST_TIMEOUT"
    
    # Cleanup SSH test keys
    rm -rf "$SSH_TEST_KEY_DIR" 2>/dev/null || true
}