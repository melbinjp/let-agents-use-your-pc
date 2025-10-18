#!/bin/bash

# Configuration validation script for Jules Endpoint Agent Docker setup
# This script helps users validate their docker-compose.yml configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate docker-compose.yml exists
check_compose_file() {
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in current directory"
        log_info "Please run this script from the docker directory"
        return 1
    fi
    log_success "docker-compose.yml found"
    return 0
}

# Function to extract environment variable from docker-compose.yml
get_env_var() {
    local var_name="$1"
    grep -E "^\s*-\s*${var_name}=" docker-compose.yml | sed -E "s/^\s*-\s*${var_name}=(.*)$/\1/" | tr -d '"' || echo ""
}

# Function to validate Cloudflare token
validate_cloudflare_token() {
    local token=$(get_env_var "CLOUDFLARE_TOKEN")
    
    if [ -z "$token" ] || [ "$token" = "YOUR_CLOUDFLARE_TOKEN_HERE" ]; then
        log_error "CLOUDFLARE_TOKEN is not set or still has placeholder value"
        log_info "Please set a valid Cloudflare tunnel token in docker-compose.yml"
        return 1
    fi
    
    if [ ${#token} -lt 32 ]; then
        log_error "CLOUDFLARE_TOKEN appears to be too short (${#token} characters)"
        log_info "Expected a token of at least 32 characters"
        return 1
    fi
    
    log_success "CLOUDFLARE_TOKEN format appears valid (${#token} characters)"
    return 0
}

# Function to validate SSH public key
validate_ssh_key() {
    local key=$(get_env_var "JULES_SSH_PUBLIC_KEY")
    
    if [ -z "$key" ] || echo "$key" | grep -q "your_agent_public_key"; then
        log_error "JULES_SSH_PUBLIC_KEY is not set or still has placeholder value"
        log_info "Please set a valid SSH public key in docker-compose.yml"
        return 1
    fi
    
    if ! echo "$key" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) '; then
        log_error "JULES_SSH_PUBLIC_KEY does not appear to be a valid SSH public key"
        log_info "Expected format: ssh-rsa AAAAB3... or ssh-ed25519 AAAAC3..."
        return 1
    fi
    
    local key_type=$(echo "$key" | awk '{print $1}')
    log_success "JULES_SSH_PUBLIC_KEY format appears valid ($key_type)"
    return 0
}

# Function to check Docker availability
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        log_info "Please install Docker Desktop or Docker Engine"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or not accessible"
        log_info "Please start Docker Desktop or Docker daemon"
        return 1
    fi
    
    log_success "Docker is available and running"
    return 0
}

# Function to check docker-compose availability
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose is not installed or not in PATH"
        log_info "Please install docker-compose"
        return 1
    fi
    
    log_success "docker-compose is available"
    return 0
}

# Function to validate docker-compose.yml syntax
validate_compose_syntax() {
    if ! docker-compose config &> /dev/null; then
        log_error "docker-compose.yml has syntax errors"
        log_info "Run 'docker-compose config' to see detailed error information"
        return 1
    fi
    
    log_success "docker-compose.yml syntax is valid"
    return 0
}

# Main validation function
main() {
    echo "Jules Endpoint Agent Configuration Validator"
    echo "==========================================="
    echo
    
    local exit_code=0
    
    # Run all validations
    check_compose_file || exit_code=1
    check_docker || exit_code=1
    check_docker_compose || exit_code=1
    
    if [ $exit_code -eq 0 ]; then
        validate_compose_syntax || exit_code=1
        validate_cloudflare_token || exit_code=1
        validate_ssh_key || exit_code=1
    fi
    
    echo
    if [ $exit_code -eq 0 ]; then
        log_success "All validations passed! Your configuration appears to be ready."
        log_info "You can now run: docker-compose up --build -d"
    else
        log_error "Some validations failed. Please fix the issues above before proceeding."
    fi
    
    exit $exit_code
}

main "$@"