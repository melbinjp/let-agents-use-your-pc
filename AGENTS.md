# AI Agent Hardware Access - Agent Integration Guide

## Overview
This project provides **secure remote hardware access** for AI agents like Jules, Claude, GPT, and others through an MCP (Model Context Protocol) server. It enables AI agents to execute commands, manage containers, access GPUs, and perform system administration tasks on user-provided hardware.

## What This System Does

### Core Functionality
- **Secure SSH Tunnel**: Cloudflare-based encrypted tunnel with no port forwarding required
- **Full Hardware Access**: CPU, GPU, memory, storage, and network resources
- **Command Execution**: Unrestricted command execution with security bypass for AI agents
- **Docker Management**: Complete container lifecycle management
- **Environment Setup**: Automated setup for Python, Node.js, Docker, and custom environments
- **File Operations**: Bulk file transfer, sync, and management
- **System Monitoring**: Real-time CPU, memory, GPU, disk, and network monitoring

### Architecture
```
Jules Agent → MCP Client → Enhanced MCP Server → SSH Tunnel → User Hardware
                                ↓
                        Security Validation
                        Rate Limiting
                        Audit Logging
```

## How Jules Should Use This System

### 1. Initial Connection
When Jules receives the connection file (`ai_agent_connection.json`), it contains:
- SSH hostname (Cloudflare tunnel URL)
- SSH username (typically "jules")
- SSH private key for authentication
- MCP server capabilities and configuration

**Jules should:**
1. Parse the connection JSON file
2. Establish SSH connection using provided credentials
3. Verify hardware access with a test command
4. Cache the connection for the session

### 2. Available MCP Tools

#### Command Execution
```json
{
  "tool": "execute_command",
  "arguments": {
    "command": "python train_model.py --gpu --epochs 100",
    "working_directory": "/tmp/ml_project",
    "environment": {"CUDA_VISIBLE_DEVICES": "0"},
    "use_sudo": false,
    "timeout": 3600,
    "bypass_security": true
  }
}
```
**Use for:** Running scripts, compiling code, system administration, data processing

#### Docker Operations
```json
{
  "tool": "docker_operations",
  "arguments": {
    "operation": "run",
    "image": "python:3.9",
    "command": "python script.py",
    "options": {
      "detach": false,
      "volumes": {"/tmp/data": "/data"},
      "environment": {"API_KEY": "value"}
    }
  }
}
```
**Operations:** list, run, exec, stop, remove, build, pull, logs, inspect
**Use for:** Containerized workflows, isolated environments, reproducible builds

#### Environment Setup
```json
{
  "tool": "environment_setup",
  "arguments": {
    "environment_type": "python",
    "requirements": ["torch", "transformers", "datasets"],
    "workspace_path": "/tmp/jules_workspace",
    "configuration": {
      "python_version": "3.9",
      "create_venv": true
    }
  }
}
```
**Types:** python, node, docker, conda, custom
**Use for:** Setting up development environments, installing dependencies

#### Bulk File Transfer
```json
{
  "tool": "bulk_file_transfer",
  "arguments": {
    "operation": "upload",
    "source": "file-content-here",
    "destination": "/tmp/jules_workspace/script.py",
    "compress": true
  }
}
```
**Operations:** upload, download, sync
**Use for:** Transferring code, data files, configuration files

#### System Monitoring
```json
{
  "tool": "system_monitoring",
  "arguments": {
    "metrics": ["cpu", "memory", "gpu", "disk"],
    "duration": 60
  }
}
```
**Use for:** Checking resource availability, monitoring long-running tasks

#### Terminal Sessions
```json
{
  "tool": "create_terminal_session",
  "arguments": {
    "session_name": "jules_session_1"
  }
}
```
**Use for:** Persistent sessions, stateful interactions, long-running processes

### 3. Common Workflows for Jules

#### Testing a Repository
```
1. Clone repository: execute_command("git clone <repo_url> /tmp/test_repo")
2. Setup environment: environment_setup(type="python", workspace="/tmp/test_repo")
3. Install dependencies: execute_command("pip install -r requirements.txt")
4. Run tests: execute_command("pytest tests/")
5. Monitor results: system_monitoring(metrics=["cpu", "memory"])
```

#### Building and Testing Code
```
1. Upload code: bulk_file_transfer(operation="upload", source=code, destination="/tmp/build")
2. Setup build environment: environment_setup(type="node", workspace="/tmp/build")
3. Build: execute_command("npm run build", working_directory="/tmp/build")
4. Run tests: execute_command("npm test", working_directory="/tmp/build")
5. Package: execute_command("npm pack", working_directory="/tmp/build")
```

#### GPU-Accelerated ML Training
```
1. Setup ML environment: environment_setup(type="python", requirements=["torch", "transformers"])
2. Upload training script: bulk_file_transfer(operation="upload", source=script)
3. Check GPU: execute_command("nvidia-smi")
4. Train model: execute_command("python train.py --gpu", timeout=7200)
5. Monitor GPU: system_monitoring(metrics=["gpu"], duration=300)
```

#### Docker-Based Testing
```
1. Build image: docker_operations(operation="build", options={"path": "/tmp/project"})
2. Run tests: docker_operations(operation="run", image="test-image", command="pytest")
3. Check logs: docker_operations(operation="logs", container="test-container")
4. Cleanup: docker_operations(operation="remove", container="test-container")
```

### 4. Security and Best Practices

#### Security Features
- **SSH Key Authentication**: No passwords, only SSH keys
- **Audit Logging**: All commands and operations are logged
- **Rate Limiting**: 120 requests/minute default (configurable)
- **Security Bypass**: Available for AI agents with `bypass_security: true`
- **Sudo Access**: Available when needed with `use_sudo: true`

#### Best Practices for Jules
1. **Always use bypass_security: true** for legitimate operations
2. **Set appropriate timeouts** for long-running tasks (default: 30s)
3. **Use working_directory** to organize files and avoid conflicts
4. **Monitor resources** before starting intensive tasks
5. **Clean up** temporary files and containers after use
6. **Use terminal sessions** for stateful workflows
7. **Check hardware info** before GPU-intensive tasks

#### What Jules Can Do
✅ Execute any system command
✅ Install and manage software packages
✅ Access and modify files anywhere
✅ Manage Docker containers
✅ Use GPU for ML/AI workloads
✅ Set up development environments
✅ Run long-running processes
✅ Perform system administration
✅ Monitor system resources

#### What Jules Should Avoid
⚠️ Destructive commands without user confirmation (e.g., `rm -rf /`)
⚠️ Exposing sensitive data in logs
⚠️ Exceeding rate limits (120 req/min)
⚠️ Leaving orphaned processes or containers
⚠️ Filling up disk space

### 5. Error Handling

#### Common Errors and Solutions

**Connection Refused**
- Check if SSH tunnel is active
- Verify SSH key permissions
- Test with: `execute_command("echo 'test'")`

**Authentication Failed**
- Verify SSH key format in connection file
- Check key permissions (should be 600)
- Ensure username matches configuration

**Command Timeout**
- Increase timeout parameter for long-running commands
- Use terminal sessions for very long processes
- Monitor with system_monitoring tool

**Rate Limit Exceeded**
- Wait 60 seconds before retrying
- Batch operations when possible
- Request rate limit increase if needed

**Permission Denied**
- Use `use_sudo: true` for system operations
- Verify user has sudo privileges
- Check file/directory permissions

### 6. Configuration Reference

#### Connection File Format
```json
{
  "mcp_server_type": "hardware_access",
  "connection_method": "ssh_tunnel",
  "ssh_config": {
    "hostname": "tunnel-hostname.trycloudflare.com",
    "port": 22,
    "username": "jules",
    "private_key": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
  },
  "capabilities": [
    "command_execution",
    "file_operations",
    "docker_management",
    "environment_setup",
    "system_monitoring",
    "package_installation",
    "hardware_access"
  ],
  "security": {
    "ai_agent_mode": true,
    "bypass_security_available": true,
    "sudo_access": true,
    "rate_limit": "120 requests/minute"
  },
  "hardware_info": {
    "cpu_count": 8,
    "memory_gb": 16,
    "gpu_info": ["NVIDIA GeForce RTX 3080"],
    "disk_space_gb": 500,
    "platform": "Linux",
    "architecture": "x86_64"
  }
}
```

#### Environment Variables (Optional)
```bash
# For advanced configuration
export AI_AGENT_MODE="true"
export MAX_REQUESTS_PER_MINUTE="120"
export REQUEST_TIMEOUT="300"
export SESSION_TIMEOUT="7200"
```

### 7. Testing and Validation

#### Quick Connection Test
```json
{
  "tool": "execute_command",
  "arguments": {
    "command": "echo 'Jules connection test successful' && uname -a",
    "bypass_security": true
  }
}
```

#### Hardware Capability Test
```json
{
  "tool": "system_monitoring",
  "arguments": {
    "metrics": ["cpu", "memory", "gpu", "disk"],
    "duration": 10
  }
}
```

#### Full Workflow Test
Run the test script: `python test_ai_agent_flexibility.py`

### 8. Performance Optimization

#### Connection Pooling
- MCP server maintains connection pool (5 connections per endpoint)
- Reuses connections for better performance
- Automatic cleanup of idle connections

#### Session Management
- Terminal sessions persist for 1 hour of inactivity
- Background cleanup every 5 minutes
- Health checks every 5 minutes

#### Resource Efficiency
- Compressed file transfers when possible
- Streaming output for long-running commands
- Automatic resource cleanup

### 9. Monitoring and Observability

#### Audit Logs
Location: `mcp-hardware-server.log`
Contains:
- All command executions
- Security events and bypasses
- Connection attempts and failures
- Resource usage statistics
- Error messages and stack traces

#### Real-time Monitoring
```json
{
  "tool": "system_monitoring",
  "arguments": {
    "metrics": ["all"],
    "duration": 3600
  }
}
```

### 10. Support and Troubleshooting

#### Self-Diagnosis
1. Test basic connectivity: `execute_command("echo 'test'")`
2. Check hardware info: `system_monitoring(metrics=["all"])`
3. Verify permissions: `execute_command("sudo echo 'test'", use_sudo=true)`
4. Test Docker: `docker_operations(operation="list")`

#### Log Analysis
Check `mcp-hardware-server.log` for:
- Connection errors
- Authentication failures
- Command execution results
- Security events
- Performance metrics

#### Getting Help
- Review TROUBLESHOOTING.md
- Check AI_AGENT_USAGE_GUIDE.md
- Run test scripts: `python test_ai_agent_connection.py`
- Examine configuration: `mcp-server-config.json`

## Summary

This MCP hardware server is designed specifically for AI agents like Jules to have **maximum flexibility** with user hardware while maintaining security and auditability. Jules can treat the connected hardware as its own computer, with full command execution, Docker management, GPU access, and system administration capabilities.

**Key Points for Jules:**
- Use `bypass_security: true` for all legitimate operations
- Set appropriate timeouts for long-running tasks
- Monitor resources before intensive operations
- Clean up temporary files and containers
- All operations are logged for audit
- Rate limit: 120 requests/minute
- Full sudo access available
- GPU and hardware acceleration supported
- Docker and containerization fully supported
- Persistent terminal sessions available

**This system enables Jules to:**
- Clone and test repositories on real hardware
- Build and deploy applications
- Train ML models with GPU acceleration
- Perform system administration tasks
- Set up and manage development environments
- Process large datasets
- Run comprehensive test suites
- Deploy and manage containerized applications

The MCP server acts as a secure bridge between Jules and user hardware, providing the tools and flexibility needed for any computational task while maintaining security through SSH authentication, audit logging, and rate limiting.
