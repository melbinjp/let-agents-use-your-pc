#!/bin/bash

# jules-endpoint-agent: Docker uninstall script
#
# This script removes Docker containers, images, and configurations
# for the Jules Endpoint Agent.

set -euo pipefail

# --- Constants ---
CONTAINER_NAME="jules-agent"
IMAGE_NAME="jules-endpoint-agent"
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="/tmp/jules-docker-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/jules-docker-uninstall-$(date +%Y%m%d-%H%M%S).log"

# --- Helper Functions ---
info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

warn() {
    echo "[WARN] $1" >&2 | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $1" >&2 | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo "[SUCCESS] $1" | tee -a "$LOG_FILE"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not in PATH"
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running or not accessible"
    fi
}

# Check if docker-compose is available
check_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        return 0
    elif docker compose version >/dev/null 2>&1; then
        return 0
    else
        warn "docker-compose not found, will use docker commands directly"
        return 1
    fi
}

# Backup Docker configurations
backup_docker_config() {
    info "Creating Docker configuration backup at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup docker-compose.yml if it exists
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "$BACKUP_DIR/"
        info "Backed up docker-compose.yml"
    fi
    
    # Backup any .env files
    if [ -f ".env" ]; then
        cp ".env" "$BACKUP_DIR/"
        info "Backed up .env file"
    fi
    
    # Export container configuration if running
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker inspect "$CONTAINER_NAME" > "$BACKUP_DIR/container-config.json" 2>/dev/null || true
        info "Backed up container configuration"
    fi
    
    # Create restoration guide
    cat > "$BACKUP_DIR/restore-guide.md" << 'EOF'
# Jules Agent Docker Restoration Guide

This backup contains the Docker configuration for your Jules Endpoint Agent.

## Files in this backup:
- `docker-compose.yml` - Docker Compose configuration
- `.env` - Environment variables (if present)
- `container-config.json` - Container inspection data (if container existed)

## To restore:
1. Copy the configuration files back to your project directory
2. Update environment variables in docker-compose.yml or .env file
3. Run: `docker-compose up -d`

## Important notes:
- You will need to reconfigure Cloudflare tokens and SSH keys
- The tunnel will need to be recreated in Cloudflare dashboard
- Make sure to update any changed hostnames or credentials
EOF
    
    info "Docker configuration backup completed"
}

# Stop and remove containers
cleanup_containers() {
    info "Cleaning up Docker containers..."
    
    # Stop and remove using docker-compose if available
    if check_docker_compose && [ -f "$COMPOSE_FILE" ]; then
        info "Using docker-compose to stop services..."
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
        else
            docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
        fi
        success "Docker Compose services stopped"
    fi
    
    # Stop container by name if it exists
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        info "Stopping container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        success "Container stopped"
    fi
    
    # Remove container by name if it exists
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        info "Removing container: $CONTAINER_NAME"
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
        success "Container removed"
    fi
    
    # Find and remove any containers based on our image
    local containers=$(docker ps -a --filter "ancestor=$IMAGE_NAME" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$containers" ]; then
        info "Found additional containers based on $IMAGE_NAME image:"
        echo "$containers" | while read -r container; do
            info "  Stopping and removing: $container"
            docker stop "$container" >/dev/null 2>&1 || true
            docker rm "$container" >/dev/null 2>&1 || true
        done
        success "Additional containers cleaned up"
    fi
}

# Remove Docker images
cleanup_images() {
    info "Cleaning up Docker images..."
    
    # Remove images with our specific name
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${IMAGE_NAME}" 2>/dev/null || true)
    if [ -n "$images" ]; then
        info "Found Jules Agent images to remove:"
        echo "$images" | while read -r image; do
            info "  Removing image: $image"
            docker rmi "$image" >/dev/null 2>&1 || true
        done
        success "Jules Agent images removed"
    else
        info "No Jules Agent images found"
    fi
    
    # Remove dangling images related to our build
    local dangling=$(docker images -f "dangling=true" -q 2>/dev/null || true)
    if [ -n "$dangling" ]; then
        info "Removing dangling images..."
        docker rmi $dangling >/dev/null 2>&1 || true
        success "Dangling images cleaned up"
    fi
}

# Clean up Docker networks
cleanup_networks() {
    info "Cleaning up Docker networks..."
    
    # Remove networks created by docker-compose
    if check_docker_compose && [ -f "$COMPOSE_FILE" ]; then
        local project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        local network_name="${project_name}_default"
        
        if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
            info "Removing Docker Compose network: $network_name"
            docker network rm "$network_name" >/dev/null 2>&1 || true
            success "Docker Compose network removed"
        fi
    fi
    
    # Clean up unused networks
    docker network prune -f >/dev/null 2>&1 || true
    info "Unused networks cleaned up"
}

# Clean up Docker volumes
cleanup_volumes() {
    info "Cleaning up Docker volumes..."
    
    # Remove volumes created by docker-compose
    if check_docker_compose && [ -f "$COMPOSE_FILE" ]; then
        local project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        local volumes=$(docker volume ls --format "{{.Name}}" | grep "^${project_name}_" 2>/dev/null || true)
        
        if [ -n "$volumes" ]; then
            info "Found project volumes to remove:"
            echo "$volumes" | while read -r volume; do
                info "  Removing volume: $volume"
                docker volume rm "$volume" >/dev/null 2>&1 || true
            done
            success "Project volumes removed"
        fi
    fi
    
    # Clean up unused volumes
    docker volume prune -f >/dev/null 2>&1 || true
    info "Unused volumes cleaned up"
}

# Verify complete removal
verify_docker_removal() {
    info "Verifying Docker cleanup..."
    local issues_found=0
    
    # Check for remaining containers
    if docker ps -a --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        warn "Container $CONTAINER_NAME still exists"
        ((issues_found++))
    fi
    
    # Check for remaining images
    if docker images --format "{{.Repository}}" | grep -q "$IMAGE_NAME"; then
        warn "Images with name $IMAGE_NAME still exist"
        ((issues_found++))
    fi
    
    # Check for running processes
    if docker ps --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        warn "Container $CONTAINER_NAME is still running"
        ((issues_found++))
    fi
    
    if [ $issues_found -eq 0 ]; then
        success "Docker cleanup verification passed"
        return 0
    else
        warn "Docker cleanup verification found $issues_found issues"
        return 1
    fi
}

# --- Main Script ---

info "Jules Endpoint Agent Docker Uninstaller started at $(date)"
info "Log file: $LOG_FILE"

# Pre-flight checks
check_docker

# Welcome message
info "This script will remove all Jules Endpoint Agent Docker components."
warn "This includes containers, images, networks, and volumes."

# Offer backup
read -p "Create configuration backup before removal? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    CREATE_BACKUP=true
else
    CREATE_BACKUP=false
fi

read -p "Continue with Docker cleanup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Docker cleanup cancelled."
    exit 0
fi

# Create backup if requested
if [ "$CREATE_BACKUP" = true ]; then
    backup_docker_config
fi

# Perform cleanup
cleanup_containers
cleanup_images
cleanup_networks
cleanup_volumes

# Verify removal
if verify_docker_removal; then
    echo ""
    success "=== DOCKER CLEANUP COMPLETE ==="
    success "All Jules Endpoint Agent Docker components have been removed."
    echo ""
    if [ "$CREATE_BACKUP" = true ]; then
        info "Configuration backup available at: $BACKUP_DIR"
        info "See restoration guide: $BACKUP_DIR/restore-guide.md"
    fi
    info "Cleanup log saved to: $LOG_FILE"
    echo ""
else
    echo ""
    warn "=== DOCKER CLEANUP COMPLETED WITH WARNINGS ==="
    warn "Some Docker components may not have been fully removed."
    warn "You may need to manually clean up remaining items."
    echo ""
    if [ "$CREATE_BACKUP" = true ]; then
        info "Configuration backup available at: $BACKUP_DIR"
    fi
    info "Cleanup log saved to: $LOG_FILE"
    echo ""
    exit 1
fi