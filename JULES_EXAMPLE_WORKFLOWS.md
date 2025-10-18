# Jules Example Workflows

This document provides real-world examples of how Jules can use your hardware through the MCP server.

## Table of Contents
1. [Repository Testing](#repository-testing)
2. [ML Model Training](#ml-model-training)
3. [Docker-Based Development](#docker-based-development)
4. [Performance Benchmarking](#performance-benchmarking)
5. [Multi-Platform Testing](#multi-platform-testing)
6. [Continuous Integration](#continuous-integration)

---

## Repository Testing

### Scenario: Test a Python Package
**Your Prompt to Jules:**
```
I have hardware available for testing my Python package.

Connection: [provide ai_agent_connection.json]

Please:
1. Clone https://github.com/myuser/my-package to /tmp/jules_test
2. Set up Python 3.9 environment
3. Install dependencies from requirements.txt
4. Run pytest with coverage
5. Check for any platform-specific issues
6. Generate a detailed test report
```

**What Jules Does:**
```python
# Step 1: Clone repository
result = await mcp.call_tool("execute_command", {
    "command": "git clone https://github.com/myuser/my-package /tmp/jules_test",
    "bypass_security": True
})

# Step 2: Set up Python environment
result = await mcp.call_tool("environment_setup", {
    "environment_type": "python",
    "workspace_path": "/tmp/jules_test",
    "configuration": {
        "python_version": "3.9",
        "create_venv": True
    }
})

# Step 3: Install dependencies
result = await mcp.call_tool("execute_command", {
    "command": "source venv/bin/activate && pip install -e .[dev]",
    "working_directory": "/tmp/jules_test",
    "bypass_security": True
})

# Step 4: Run tests with coverage
result = await mcp.call_tool("execute_command", {
    "command": "source venv/bin/activate && pytest tests/ -v --cov=. --cov-report=html --cov-report=term",
    "working_directory": "/tmp/jules_test",
    "timeout": 600,
    "bypass_security": True
})

# Step 5: Check platform info
result = await mcp.call_tool("execute_command", {
    "command": "uname -a && python --version && pip list",
    "working_directory": "/tmp/jules_test",
    "bypass_security": True
})

# Step 6: Generate report (Jules analyzes all results)
```

**Jules Response:**
```
✅ Test Results Summary

Repository: my-package
Platform: Ubuntu 22.04 LTS (x86_64)
Python: 3.9.16

Test Results:
- Total Tests: 127
- Passed: 125 (98.4%)
- Failed: 2 (1.6%)
- Skipped: 0
- Coverage: 89%

Failed Tests:
1. test_network_timeout - Connection timeout (may be environment-specific)
2. test_gpu_acceleration - No GPU available on test system

Platform-Specific Issues:
- None detected

Recommendations:
1. The network timeout test may need adjustment for different environments
2. Consider adding GPU availability check before GPU tests
3. Overall code quality is excellent with high test coverage

Full coverage report saved to: /tmp/jules_test/htmlcov/index.html
```

---

## ML Model Training

### Scenario: Train a PyTorch Model on GPU
**Your Prompt to Jules:**
```
I need to train a neural network on my GPU.

Connection: [provide ai_agent_connection.json]

Hardware: NVIDIA RTX 3080, 32GB RAM

Please:
1. Check GPU availability and specs
2. Set up PyTorch environment with CUDA support
3. Upload my training script (I'll provide it)
4. Train the model for 100 epochs
5. Monitor GPU usage during training
6. Save the trained model
7. Generate training metrics report
```

**Training Script (you provide):**
```python
# train_model.py
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

# Model definition
class ConvNet(nn.Module):
    def __init__(self):
        super(ConvNet, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)
    
    def forward(self, x):
        x = torch.relu(self.conv1(x))
        x = torch.relu(self.conv2(x))
        x = torch.flatten(x, 1)
        x = torch.relu(self.fc1(x))
        return self.fc2(x)

# Training code
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = ConvNet().to(device)
# ... rest of training code
```

**What Jules Does:**
```python
# Step 1: Check GPU
gpu_result = await mcp.call_tool("execute_command", {
    "command": "nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv",
    "bypass_security": True
})

# Step 2: Set up PyTorch environment
env_result = await mcp.call_tool("environment_setup", {
    "environment_type": "python",
    "requirements": [
        "torch",
        "torchvision",
        "tensorboard",
        "numpy",
        "matplotlib"
    ],
    "workspace_path": "/tmp/jules_ml_training",
    "configuration": {
        "python_version": "3.9",
        "create_venv": True
    }
})

# Step 3: Upload training script
upload_result = await mcp.call_tool("bulk_file_transfer", {
    "operation": "upload",
    "source": training_script_content,
    "destination": "/tmp/jules_ml_training/train_model.py"
})

# Step 4: Start training (in background session)
session_result = await mcp.call_tool("create_terminal_session", {
    "session_name": "ml_training"
})

train_result = await mcp.call_tool("execute_in_terminal", {
    "session_id": session_result["session_id"],
    "command": "cd /tmp/jules_ml_training && source venv/bin/activate && python train_model.py --epochs 100 --gpu"
})

# Step 5: Monitor GPU usage (parallel monitoring)
monitor_result = await mcp.call_tool("system_monitoring", {
    "metrics": ["gpu", "memory"],
    "duration": 300  # Monitor for 5 minutes initially
})

# Step 6: Wait for training to complete and save model
# Jules periodically checks training progress

# Step 7: Generate report
```

**Jules Response:**
```
✅ Training Complete

GPU Information:
- Model: NVIDIA GeForce RTX 3080
- Memory: 10GB
- Driver: 525.105.17
- CUDA: 11.8

Training Results:
- Total Epochs: 100
- Training Time: 2h 34m
- Final Training Loss: 0.0234
- Final Validation Loss: 0.0456
- Best Validation Accuracy: 98.7% (epoch 87)
- Final Test Accuracy: 98.5%

GPU Utilization:
- Average GPU Usage: 87%
- Peak Memory Usage: 8.2GB / 10GB
- Average Temperature: 72°C
- Power Usage: 280W average

Model Saved:
- Location: /tmp/jules_ml_training/model_best.pth
- Size: 47.3 MB
- Checkpoints: Every 10 epochs

Training Metrics:
- TensorBoard logs: /tmp/jules_ml_training/runs/
- Training curves show good convergence
- No overfitting detected
- Early stopping triggered at epoch 87

Recommendations:
1. Model performed excellently on test set
2. GPU was well-utilized throughout training
3. Consider using mixed precision training for faster training
4. Model is ready for deployment
```

---

## Docker-Based Development

### Scenario: Build and Test Microservice
**Your Prompt to Jules:**
```
I'm developing a microservice that needs testing with Docker.

Connection: [provide ai_agent_connection.json]

Please:
1. Build the Docker image from my Dockerfile
2. Run the service with PostgreSQL database
3. Run integration tests
4. Check logs for any errors
5. Test API endpoints
6. Clean up containers
```

**What Jules Does:**
```python
# Step 1: Build Docker image
build_result = await mcp.call_tool("docker_operations", {
    "operation": "build",
    "options": {
        "path": "/tmp/jules_microservice",
        "tag": "my-service:test",
        "dockerfile": "Dockerfile"
    }
})

# Step 2: Start PostgreSQL
db_result = await mcp.call_tool("docker_operations", {
    "operation": "run",
    "image": "postgres:14",
    "options": {
        "name": "test-postgres",
        "detach": True,
        "environment": {
            "POSTGRES_PASSWORD": "testpass",
            "POSTGRES_DB": "testdb"
        },
        "ports": {"5432": "5432"}
    }
})

# Wait for database to be ready
await mcp.call_tool("execute_command", {
    "command": "sleep 5",
    "bypass_security": True
})

# Step 3: Run service
service_result = await mcp.call_tool("docker_operations", {
    "operation": "run",
    "image": "my-service:test",
    "options": {
        "name": "test-service",
        "detach": True,
        "environment": {
            "DATABASE_URL": "postgresql://postgres:testpass@test-postgres:5432/testdb"
        },
        "ports": {"8080": "8080"},
        "links": ["test-postgres"]
    }
})

# Step 4: Run integration tests
test_result = await mcp.call_tool("docker_operations", {
    "operation": "exec",
    "container": "test-service",
    "command": "pytest tests/integration -v"
})

# Step 5: Check logs
logs_result = await mcp.call_tool("docker_operations", {
    "operation": "logs",
    "container": "test-service",
    "options": {"tail": 100}
})

# Step 6: Test API endpoints
api_test = await mcp.call_tool("execute_command", {
    "command": "curl -f http://localhost:8080/health && curl -f http://localhost:8080/api/v1/status",
    "bypass_security": True
})

# Step 7: Clean up
cleanup_result = await mcp.call_tool("docker_operations", {
    "operation": "remove",
    "container": "test-service",
    "options": {"force": True}
})

await mcp.call_tool("docker_operations", {
    "operation": "remove",
    "container": "test-postgres",
    "options": {"force": True}
})
```

**Jules Response:**
```
✅ Microservice Testing Complete

Build Results:
- Image: my-service:test
- Size: 342 MB
- Build Time: 2m 34s
- Layers: 12

Integration Tests:
- Total Tests: 45
- Passed: 45 (100%)
- Failed: 0
- Duration: 1m 23s

API Endpoint Tests:
✓ GET /health - 200 OK (12ms)
✓ GET /api/v1/status - 200 OK (45ms)
✓ POST /api/v1/users - 201 Created (89ms)
✓ GET /api/v1/users/1 - 200 OK (23ms)
✓ PUT /api/v1/users/1 - 200 OK (67ms)
✓ DELETE /api/v1/users/1 - 204 No Content (34ms)

Database Integration:
✓ Connection successful
✓ Migrations applied
✓ Test data seeded
✓ Queries optimized

Logs Analysis:
- No errors detected
- All requests handled successfully
- Average response time: 45ms
- Database queries: avg 12ms

Container Cleanup:
✓ test-service removed
✓ test-postgres removed
✓ No orphaned volumes

Recommendations:
1. Service is production-ready
2. All integration tests pass
3. API performance is excellent
4. Consider adding load testing
5. Database connection pooling is working well
```

---

## Performance Benchmarking

### Scenario: Benchmark Application Performance
**Your Prompt to Jules:**
```
I need to benchmark my application's performance.

Connection: [provide ai_agent_connection.json]

Please:
1. Build optimized version of the application
2. Run performance benchmarks
3. Monitor system resources during benchmarks
4. Compare with baseline results
5. Generate performance report with graphs
```

**What Jules Does:**
```python
# Step 1: Build optimized version
build_result = await mcp.call_tool("execute_command", {
    "command": "gcc -O3 -march=native -flto app.c -o app_optimized",
    "working_directory": "/tmp/jules_benchmark",
    "bypass_security": True
})

# Step 2: Run benchmarks
benchmark_result = await mcp.call_tool("execute_command", {
    "command": "./run_benchmarks.sh --iterations 1000 --threads 8",
    "working_directory": "/tmp/jules_benchmark",
    "timeout": 600,
    "bypass_security": True
})

# Step 3: Monitor resources (parallel)
monitor_result = await mcp.call_tool("system_monitoring", {
    "metrics": ["cpu", "memory", "disk", "network"],
    "duration": 300
})

# Step 4: Compare with baseline
compare_result = await mcp.call_tool("execute_command", {
    "command": "python compare_results.py --current results.json --baseline baseline.json",
    "working_directory": "/tmp/jules_benchmark",
    "bypass_security": True
})

# Step 5: Generate report
report_result = await mcp.call_tool("execute_command", {
    "command": "python generate_report.py --output report.html",
    "working_directory": "/tmp/jules_benchmark",
    "bypass_security": True
})
```

**Jules Response:**
```
✅ Performance Benchmark Results

Build Configuration:
- Compiler: GCC 11.3.0
- Optimization: -O3 -march=native -flto
- Binary Size: 2.4 MB

Benchmark Results (1000 iterations):
┌─────────────────────┬──────────┬──────────┬──────────┐
│ Test                │ Current  │ Baseline │ Change   │
├─────────────────────┼──────────┼──────────┼──────────┤
│ String Processing   │ 45.2ms   │ 52.1ms   │ +13.2%   │
│ Array Operations    │ 23.8ms   │ 28.4ms   │ +16.2%   │
│ File I/O            │ 156.3ms  │ 178.9ms  │ +12.6%   │
│ Network Requests    │ 89.4ms   │ 95.2ms   │ +6.1%    │
│ Database Queries    │ 234.5ms  │ 245.8ms  │ +4.6%    │
└─────────────────────┴──────────┴──────────┴──────────┘

System Resource Usage:
- CPU: 78% average (8 cores fully utilized)
- Memory: 4.2GB peak (26% of total)
- Disk I/O: 145 MB/s read, 89 MB/s write
- Network: 234 Mbps average

Performance Improvements:
✓ 13.2% faster string processing
✓ 16.2% faster array operations
✓ 12.6% faster file I/O
✓ 6.1% faster network requests
✓ 4.6% faster database queries

Overall: 10.5% performance improvement over baseline

Bottlenecks Identified:
1. Database queries (slowest operation)
2. File I/O could be optimized with buffering
3. Network requests have high latency variance

Recommendations:
1. Consider database query optimization
2. Implement connection pooling
3. Add caching layer for frequent queries
4. Use async I/O for file operations
5. Optimize network request batching

Full report: /tmp/jules_benchmark/report.html
```

---

## Multi-Platform Testing

### Scenario: Test Across Different Platforms
**Your Prompt to Jules:**
```
I need to test my application on different platforms.

I have three hardware connections:
1. Ubuntu 22.04 (x86_64) - [connection1.json]
2. macOS 13 (arm64) - [connection2.json]
3. Windows 11 (x86_64) - [connection3.json]

Please test the application on all platforms and report any platform-specific issues.
```

**What Jules Does:**
```python
# Jules tests on each platform in parallel

# Platform 1: Ubuntu
ubuntu_result = await test_on_platform({
    "connection": connection1,
    "platform": "Ubuntu 22.04",
    "tests": ["unit", "integration", "performance"]
})

# Platform 2: macOS
macos_result = await test_on_platform({
    "connection": connection2,
    "platform": "macOS 13",
    "tests": ["unit", "integration", "performance"]
})

# Platform 3: Windows
windows_result = await test_on_platform({
    "connection": connection3,
    "platform": "Windows 11",
    "tests": ["unit", "integration", "performance"]
})
```

**Jules Response:**
```
✅ Multi-Platform Test Results

┌──────────────┬─────────┬─────────┬─────────┬──────────────┐
│ Platform     │ Unit    │ Integ.  │ Perf.   │ Issues       │
├──────────────┼─────────┼─────────┼─────────┼──────────────┤
│ Ubuntu 22.04 │ 100%    │ 100%    │ ✓       │ None         │
│ macOS 13     │ 98%     │ 100%    │ ✓       │ 2 minor      │
│ Windows 11   │ 95%     │ 97%     │ ⚠       │ 5 issues     │
└──────────────┴─────────┴─────────┴─────────┴──────────────┘

Platform-Specific Issues:

macOS (arm64):
1. test_file_permissions - Different default permissions
2. test_path_separator - Path handling needs adjustment

Windows:
1. test_file_locking - Windows file locking behavior differs
2. test_symlinks - Symlink support requires admin privileges
3. test_case_sensitivity - Filesystem is case-insensitive
4. test_line_endings - CRLF vs LF line ending issues
5. test_process_signals - Signal handling not supported

Performance Comparison:
- Ubuntu: Baseline (100%)
- macOS: 95% of Ubuntu performance (ARM architecture)
- Windows: 87% of Ubuntu performance (I/O overhead)

Recommendations:
1. Add platform-specific test skips for unsupported features
2. Normalize path handling across platforms
3. Handle line endings consistently
4. Document Windows admin requirements for symlinks
5. Consider platform-specific optimizations

All critical functionality works on all platforms.
Minor issues are documented and have workarounds.
```

---

## Continuous Integration

### Scenario: Set Up CI Pipeline on Hardware
**Your Prompt to Jules:**
```
I want to set up a CI pipeline on my hardware that:
1. Watches for GitHub commits
2. Automatically runs tests
3. Reports results back to GitHub
4. Cleans up after each run

Connection: [provide ai_agent_connection.json]
GitHub Token: [provide token]
Repository: myuser/myrepo
```

**What Jules Does:**
```python
# Set up CI environment
ci_setup = await mcp.call_tool("environment_setup", {
    "environment_type": "python",
    "requirements": ["pytest", "pytest-cov", "requests", "pygithub"],
    "workspace_path": "/tmp/jules_ci",
    "configuration": {
        "python_version": "3.9",
        "create_venv": True
    }
})

# Create CI script
ci_script = """
#!/bin/bash
set -e

# Clone repository
git clone https://github.com/myuser/myrepo /tmp/ci_build
cd /tmp/ci_build

# Get commit SHA
COMMIT_SHA=$(git rev-parse HEAD)

# Install dependencies
pip install -r requirements.txt

# Run tests
pytest tests/ -v --cov=. --cov-report=json > test_output.txt 2>&1
TEST_EXIT_CODE=$?

# Report to GitHub
python /tmp/jules_ci/report_to_github.py \
    --commit $COMMIT_SHA \
    --exit-code $TEST_EXIT_CODE \
    --output test_output.txt \
    --coverage coverage.json

# Cleanup
cd /tmp
rm -rf /tmp/ci_build

exit $TEST_EXIT_CODE
"""

# Upload CI script
await mcp.call_tool("bulk_file_transfer", {
    "operation": "upload",
    "source": ci_script,
    "destination": "/tmp/jules_ci/ci_runner.sh"
})

# Make executable
await mcp.call_tool("execute_command", {
    "command": "chmod +x /tmp/jules_ci/ci_runner.sh",
    "bypass_security": True
})

# Set up webhook listener or polling
# Jules creates a simple webhook server or polling script
```

**Jules Response:**
```
✅ CI Pipeline Configured

Setup Complete:
- CI Environment: /tmp/jules_ci
- Python: 3.9 with pytest, coverage
- GitHub Integration: Configured
- Cleanup: Automatic after each run

CI Pipeline Features:
✓ Automatic test execution on new commits
✓ Coverage reporting
✓ GitHub status updates
✓ Automatic cleanup
✓ Error notifications

Test Run Example:
Commit: abc123def
Status: ✓ Passed
Tests: 127/127 passed
Coverage: 89%
Duration: 2m 34s
GitHub Status: Updated

Next Steps:
1. Push a commit to trigger the pipeline
2. Check GitHub for status updates
3. Review test results in CI logs
4. Monitor /tmp/jules_ci/logs/ for details

The CI pipeline is now active and monitoring your repository.
```

---

## Summary

These workflows demonstrate how Jules can leverage your hardware for:

- **Real-world testing** on actual hardware
- **GPU-accelerated** ML/AI workloads
- **Docker-based** development and testing
- **Performance benchmarking** on real systems
- **Multi-platform** compatibility testing
- **Continuous integration** with your hardware

Each workflow shows:
1. What you ask Jules to do
2. How Jules uses the MCP tools
3. What results Jules provides

The MCP server provides Jules with the flexibility and power to handle complex workflows while maintaining security and auditability.

For more information:
- See [JULES_INTEGRATION_GUIDE.md](JULES_INTEGRATION_GUIDE.md) for setup
- See [AGENTS.md](AGENTS.md) for tool reference
- See [AI_AGENT_USAGE_GUIDE.md](AI_AGENT_USAGE_GUIDE.md) for detailed tool documentation
