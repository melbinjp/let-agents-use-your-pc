# Remote Hardware Access System - Testing Framework

This comprehensive testing framework validates all aspects of the Remote Hardware Access System, including Docker containers, SSH connections, tunnel connectivity, and hardware access capabilities.

## Overview

The testing framework is organized into modular components that test different aspects of the system:

- **Docker Container Testing**: Validates Docker image building, container startup, service configuration, and health checks
- **SSH Connection Validation**: Tests SSH client functionality, key management, and connection establishment
- **Tunnel Connectivity Verification**: Validates Cloudflare tunnel functionality and network connectivity
- **Hardware Access Testing**: Verifies hardware detection, access permissions, and system resource availability
- **Integration Testing**: Tests end-to-end workflows and component interactions

## Quick Start

### Run All Tests
```bash
./tests/run-tests.sh all
```

### Run Specific Test Categories
```bash
# Docker tests only
./tests/run-tests.sh docker

# SSH tests only
./tests/run-tests.sh ssh

# Tunnel tests only
./tests/run-tests.sh tunnel

# Hardware tests only
./tests/run-tests.sh hardware

# Integration tests only
./tests/run-tests.sh integration
```

### Run Tests with Pattern Matching
```bash
# Run only Docker container tests
./tests/run-tests.sh docker container

# Run only SSH connection tests
./tests/run-tests.sh ssh connection

# Run only build-related tests
./tests/run-tests.sh docker build
```

## Test Categories

### Docker Container Testing

Tests Docker-based deployment and container functionality:

- Docker availability and version checks
- Dockerfile and docker-compose.yml validation
- Image building and container startup
- Service configuration (SSH, cloudflared)
- User account and permission setup
- Health checks and monitoring
- Container lifecycle management

**Requirements Covered**: 2.1, 2.2, 6.2, 6.3

### SSH Connection Validation

Tests SSH connectivity and authentication:

- SSH client and key generation tools
- SSH key format validation and permissions
- Connection establishment and authentication
- Session management and cleanup
- Integration with container environments

**Requirements Covered**: 2.1, 2.2

### Tunnel Connectivity Verification

Tests Cloudflare tunnel functionality:

- Cloudflared binary availability and version
- Tunnel configuration validation
- Network connectivity to Cloudflare services
- DNS resolution and port availability
- Process management and monitoring
- Log parsing and hostname extraction

**Requirements Covered**: 6.2, 6.3

### Hardware Access Testing

Tests hardware detection and access capabilities:

- CPU, memory, and disk access
- Network interface detection
- GPU and specialized hardware detection
- USB and PCI device access
- System information and process management
- Package manager and sudo access
- Performance monitoring tools

**Requirements Covered**: 6.2, 6.3

### Integration Testing

Tests end-to-end workflows and component integration:

- Complete Docker deployment workflow
- Connection information generation
- SSH key authentication flow
- Service startup sequencing
- Environment variable processing
- User configuration workflow
- Error handling and cleanup procedures

**Requirements Covered**: 2.1, 2.2, 6.2, 6.3

## Test Framework Architecture

### Main Components

- `test-framework.sh`: Core testing framework with common utilities
- `run-tests.sh`: Main test runner script
- `modules/`: Directory containing test modules for each category
- `README.md`: This documentation file

### Test Modules

Each test module is self-contained and provides:

- Individual test functions for specific functionality
- Test listing capabilities
- Cleanup procedures
- Pattern matching support

### Common Utilities

The framework provides common utilities for:

- Test execution with timeout handling
- Result tracking and reporting
- Logging with color-coded output
- Resource cleanup and error handling
- SSH key generation for testing

## Configuration

### Environment Variables

- `TEST_TIMEOUT`: Default timeout for individual tests (default: 30s)
- `DOCKER_TEST_TIMEOUT`: Timeout for Docker operations (default: 120s)
- `SSH_TEST_TIMEOUT`: Timeout for SSH operations (default: 15s)
- `TUNNEL_TEST_TIMEOUT`: Timeout for tunnel operations (default: 60s)

### Test Configuration

Tests can be configured by modifying the configuration variables at the top of each test module:

- Docker image and container names
- SSH test parameters
- Tunnel test settings
- Hardware test preferences

## Usage Examples

### Basic Usage
```bash
# Run all tests
./tests/run-tests.sh

# Run with verbose output
./tests/run-tests.sh -v all

# Set custom timeout
./tests/run-tests.sh -t 60 docker

# List available tests
./tests/run-tests.sh --list
```

### Advanced Usage
```bash
# Run only container-related Docker tests
./tests/run-tests.sh docker container

# Run SSH tests matching "connection"
./tests/run-tests.sh ssh connection

# Run integration tests with verbose output
./tests/run-tests.sh -v integration
```

## Prerequisites

### Required Tools

- `bash` (version 4.0+)
- `docker` (for Docker tests)
- `docker-compose` (for Docker Compose tests)
- `ssh` and `ssh-keygen` (for SSH tests)
- `curl` or `wget` (for connectivity tests)

### Optional Tools

- `cloudflared` (for tunnel tests)
- `jq` (for JSON validation)
- `nvidia-smi` (for GPU tests)
- Various system tools (`lspci`, `lsusb`, etc.)

## Troubleshooting

### Common Issues

1. **Docker not available**: Install Docker Desktop or Docker Engine
2. **Permission denied**: Ensure user is in docker group or run with sudo
3. **Network connectivity**: Check internet connection for tunnel tests
4. **Missing tools**: Install required system tools for hardware tests

### Test Failures

- Check test output for specific error messages
- Run individual test categories to isolate issues
- Use verbose mode (`-v`) for detailed debugging information
- Review container logs for Docker-related failures

### Cleanup

The framework automatically cleans up test resources, but manual cleanup may be needed:

```bash
# Remove test containers
docker rm -f $(docker ps -aq --filter "name=jules-test")

# Remove test images
docker rmi $(docker images --filter "reference=jules-endpoint-agent:*" -q)

# Remove test SSH keys
rm -rf /tmp/ssh-test-keys /tmp/integration-ssh-keys
```

## Contributing

When adding new tests:

1. Create test functions following the naming convention `test_*`
2. Add tests to the appropriate module or create a new module
3. Update the `list_*_tests` function to include new tests
4. Add cleanup procedures if needed
5. Update this documentation

## Requirements Mapping

This testing framework satisfies the following task requirements:

- **Create automated Docker container testing**: Comprehensive Docker test module with container lifecycle, service validation, and health checks
- **Develop SSH connection validation tests**: SSH test module with connection testing, key validation, and authentication flows
- **Implement tunnel connectivity verification**: Tunnel test module with Cloudflare connectivity, configuration validation, and process management
- **Add hardware access testing procedures**: Hardware test module with system resource access, device detection, and permission validation

The framework addresses requirements 2.1, 2.2, 6.2, and 6.3 from the system requirements document.