# Jules Endpoint Agent: Docker Installation (SSH-based)

This directory contains the necessary files to run the Jules Endpoint Agent in a Docker container. This method is highly recommended for users who want a standardized, isolated, and high-performance Linux environment for the agent, regardless of their host operating system (Windows, macOS, or Linux).

This setup creates a secure SSH endpoint, accessible via a public URL, allowing an AI agent to connect and perform development tasks.

## File Descriptions

- `Dockerfile`: This file defines the Docker image. It builds a standard Ubuntu environment, installs `openssh-server` and `cloudflared`, and sets up an entrypoint script to manage the services.
- `docker-compose.yml`: This is the easiest way to run the agent. It defines the service and manages the environment variables required for the Cloudflare tunnel and SSH authentication.

## Design Choices & Technical Details

### Why SSH?
- **Security**: SSH with public key authentication is the industry standard for secure remote shell access, offering significantly stronger security than password-based methods.
- **Compatibility**: The vast majority of development and system administration tools are designed to work over SSH, making the endpoint far more versatile.
- **Stateful Interaction**: SSH provides a true, stateful shell, allowing for more complex, multi-step tasks than a stateless HTTP-based approach.

### How it Works
The `docker-compose up` command builds and starts a container that does the following:
1.  **Creates a User**: It creates a dedicated, non-root user named `jules` for the agent to use.
2.  **Sets up SSH**: It takes the public SSH key you provide in the `.env` file and adds it to the `jules` user's `authorized_keys` file. This is what allows the agent to authenticate.
3.  **Starts Services**: It starts the `cloudflared` service to create the public tunnel and the `sshd` service to listen for incoming SSH connections.

## Installation Instructions

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for Windows/macOS) or Docker Engine (for Linux) must be installed.
- You must have an SSH key pair for your AI agent. If you don't have one, you can generate it with `ssh-keygen -t rsa -b 4096`.

### Running the Agent

1.  **Clone the Repository:** You will need these files locally. Clone the repository and navigate into this `docker` directory.

2.  **Configure Credentials:** Open the `docker-compose.yml` file in a text editor. You **must** fill in the following environment variables:
    - `CLOUDFLARE_TOKEN`: Get this from the Cloudflare Zero Trust dashboard. When you create a tunnel, Cloudflare will give you a token string that starts with "eyJ" and is ~200+ characters long.
    - `JULES_SSH_PUBLIC_KEY`: Paste the **public key** (the contents of the `.pub` file, e.g., `id_rsa.pub`) of the SSH key pair that your agent will use to connect. Should start with "ssh-rsa" or "ssh-ed25519".

    **Optional:** Validate your configuration before proceeding:
    ```bash
    # On Linux/macOS
    chmod +x validate-config.sh && ./validate-config.sh
    
    # On Windows (using Git Bash or WSL)
    bash validate-config.sh
    ```

3.  **Build and Run:** From your terminal in this `docker` directory, run the following command:
    ```bash
    docker-compose up --build -d
    ```
    This will build the Docker image, create a container, and run it in the background.

4.  **Verify Installation:** Check that the services are running properly:
    ```bash
    # Check container status
    docker-compose ps
    
    # Check health status
    docker-compose exec jules-agent /healthcheck.sh
    
    # View logs
    docker-compose logs -f jules-agent
    ```

5.  **Get Your Connection Info:**
    - The public hostname will be visible in the Cloudflare Zero Trust dashboard for the tunnel you created.
    - You will connect using SSH. The command will look like this (replace `<your-tunnel-hostname>` with the actual hostname from Cloudflare):
    ```bash
    ssh jules@<your-tunnel-hostname>
    ```
    You must use the corresponding private key to connect.

### Connection Information

After successful installation, you'll receive connection details:

```bash
# Get connection information
docker-compose exec jules-agent /connection-info.sh
```

This will display:
- SSH hostname (from Cloudflare tunnel)
- Username (`jules`)
- Ready-to-use SSH connection command
- Additional configuration details

### Troubleshooting

**Container Startup Issues:**
```bash
# Check container status
docker-compose ps

# View startup logs
docker-compose logs jules-agent

# Run health check
docker-compose exec jules-agent /healthcheck.sh
```

**Environment Variable Issues:**
- Ensure `CLOUDFLARE_TOKEN` is valid (starts with "eyJ", ~200+ characters)
- Verify `JULES_SSH_PUBLIC_KEY` format (starts with "ssh-rsa" or "ssh-ed25519")
- Check for proper escaping of special characters in keys

**SSH Connection Issues:**
```bash
# Test SSH connectivity from inside container
docker-compose exec jules-agent ssh jules@localhost

# Check SSH service status
docker-compose exec jules-agent systemctl status ssh
```

**GPU Access Issues:**
```bash
# Verify GPU access in container
docker-compose exec jules-agent nvidia-smi

# Check GPU configuration
docker-compose config | grep -A 10 "deploy:"
```

For detailed troubleshooting, see the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) guide.

## GPU and Hardware Access

The Docker container is configured with comprehensive hardware access capabilities, including GPU passthrough, performance optimization, and hardware detection tools.

### Hardware Access Features

**Automatic Hardware Detection:**
- CPU, memory, storage, and network information
- GPU detection (NVIDIA and AMD)
- Hardware performance capabilities
- Device access permissions

**Performance Optimization:**
- CPU frequency scaling optimization
- Memory management tuning
- GPU performance mode configuration
- Storage I/O optimization
- Network buffer optimization

**Hardware Access Tools:**
- Hardware detection script: `/app/hardware-detection.sh`
- Performance optimization script: `/app/performance-optimization.sh`
- Comprehensive hardware monitoring tools
- Stress testing capabilities

### Enabling GPU Access

The container includes built-in GPU support with the following configuration:

**NVIDIA GPU Access:**
1. Install [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on your host
2. Uncomment the NVIDIA GPU section in `docker-compose.yml`:
   ```yaml
   deploy:
     resources:
       reservations:
         devices:
           - driver: nvidia
             count: all
             capabilities: [gpu]
   ```
3. Restart the container: `docker-compose up --build -d`

**Hardware Device Access:**
The container automatically mounts hardware devices:
- `/dev/dri` - GPU devices
- `/dev/nvidia*` - NVIDIA GPU devices
- `/sys` - System information (read-only)
- `/proc` - Process and system information

**Privileged Mode:**
The container runs in privileged mode for full hardware access, including:
- Direct hardware device access
- System-level performance tuning
- Hardware monitoring and control
- Unrestricted resource access

### Hardware Detection and Monitoring

**Check Hardware Status:**
```bash
# Get comprehensive hardware information
docker-compose exec jules-agent /app/hardware-detection.sh

# Check GPU status specifically
docker-compose exec jules-agent /app/hardware-detection.sh gpu

# Check hardware permissions
docker-compose exec jules-agent /app/hardware-detection.sh permissions

# Generate detailed hardware report
docker-compose exec jules-agent /app/hardware-detection.sh report
```

**Performance Optimization:**
```bash
# Apply performance optimizations
docker-compose exec jules-agent /app/performance-optimization.sh optimize

# Run performance stress tests
docker-compose exec jules-agent /app/performance-optimization.sh test

# Generate performance report
docker-compose exec jules-agent /app/performance-optimization.sh report

# Optimize specific components
docker-compose exec jules-agent /app/performance-optimization.sh gpu
docker-compose exec jules-agent /app/performance-optimization.sh cpu
```

### Testing GPU and Hardware Access

Use the included test script to verify hardware access:

```bash
# Run comprehensive hardware tests
./test-gpu-hardware.sh

# Test specific components
./test-gpu-hardware.sh gpu          # GPU access only
./test-gpu-hardware.sh permissions  # Hardware permissions
./test-gpu-hardware.sh performance  # Performance tools
```

### Hardware Requirements and Recommendations

**Minimum Requirements:**
- 2 CPU cores
- 4GB RAM
- 10GB disk space

**Recommended for GPU Workloads:**
- 4+ CPU cores
- 8GB+ RAM
- NVIDIA GPU with Container Toolkit
- SSD storage for better I/O performance

**Optimal Performance Configuration:**
- Dedicated GPU (NVIDIA RTX series recommended)
- 16GB+ RAM
- NVMe SSD storage
- High-speed network connection

### Hardware Access Security

**Security Considerations:**
- Container runs in privileged mode for hardware access
- Jules user has full sudo access for hardware control
- Direct device access enabled for performance
- Recommend using dedicated/isolated systems for production

**Access Control:**
- SSH key-based authentication only
- Dedicated user account (jules) with controlled access
- Audit logging for system modifications
- Clean session termination and resource cleanup

### Troubleshooting Hardware Access

**GPU Access Issues:**
```bash
# Check GPU devices in container
docker-compose exec jules-agent ls -la /dev/dri/
docker-compose exec jules-agent nvidia-smi

# Verify GPU configuration
docker-compose config | grep -A 15 "deploy:"

# Test GPU functionality
docker-compose exec jules-agent /app/hardware-detection.sh gpu
```

**Performance Issues:**
```bash
# Check system resources
docker-compose exec jules-agent htop
docker-compose exec jules-agent iostat -x 1 5

# Apply performance optimizations
docker-compose exec jules-agent /app/performance-optimization.sh optimize

# Run performance diagnostics
docker-compose exec jules-agent /app/performance-optimization.sh report
```

**Hardware Detection Issues:**
```bash
# Verify hardware tools
docker-compose exec jules-agent lscpu
docker-compose exec jules-agent lshw -short
docker-compose exec jules-agent lspci | grep -i vga

# Check device permissions
docker-compose exec jules-agent /app/hardware-detection.sh permissions

# Test hardware access
./test-gpu-hardware.sh permissions
```
