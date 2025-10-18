# Troubleshooting Guide

This guide provides solutions to common issues encountered when installing and using the Jules Endpoint Agent.

## Installation Issues

### SSH Server Installation Fails

**Symptoms:**
- Package installation errors during setup
- SSH service fails to start
- "openssh-server not found" errors

**Solutions:**
```bash
# Update package lists
sudo apt update

# Install SSH server manually
sudo apt install -y openssh-server

# Start SSH service
sudo systemctl start ssh
sudo systemctl enable ssh

# Verify installation
sudo systemctl status ssh
```

### Cloudflared Installation Fails

**Symptoms:**
- "cloudflared command not found"
- Download or installation errors
- Architecture compatibility issues

**Solutions:**
```bash
# Manual cloudflared installation (Linux)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# For ARM systems
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared-linux-arm64.deb

# Verify installation
cloudflared --version
```

### User Creation Fails

**Symptoms:**
- "jules user already exists" errors
- Permission denied when creating user
- Home directory creation issues

**Solutions:**
```bash
# Remove existing jules user (if needed)
sudo userdel -r jules

# Create user manually
sudo useradd -m -s /bin/bash jules

# Add to sudo group
sudo usermod -aG sudo jules

# Configure passwordless sudo
echo "jules ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jules
```

## Connection Issues

### SSH Connection Refused

**Symptoms:**
- "Connection refused" when attempting SSH
- Timeout errors
- "Host unreachable" messages

**Diagnostic Steps:**
```bash
# Check SSH service status
sudo systemctl status ssh

# Verify SSH is listening on port 22
sudo netstat -tlnp | grep :22

# Check SSH configuration
sudo sshd -T | grep -E "(Port|ListenAddress)"

# Test local SSH connection
ssh jules@localhost
```

**Solutions:**
```bash
# Restart SSH service
sudo systemctl restart ssh

# Check SSH configuration file
sudo nano /etc/ssh/sshd_config

# Ensure these settings:
# Port 22
# PermitRootLogin no
# PubkeyAuthentication yes
# PasswordAuthentication no
```

### Cloudflare Tunnel Issues

**Symptoms:**
- Tunnel hostname not accessible
- "This site can't be reached" errors
- Intermittent connectivity

**Diagnostic Steps:**
```bash
# Check tunnel status
sudo systemctl status cloudflared

# View tunnel logs
sudo journalctl -u cloudflared -f

# Test tunnel configuration
sudo cloudflared tunnel info <tunnel-name>

# List active tunnels
sudo cloudflared tunnel list
```

**Solutions:**
```bash
# Restart cloudflared service
sudo systemctl restart cloudflared

# Recreate tunnel (if needed)
sudo cloudflared tunnel delete <tunnel-name>
sudo cloudflared tunnel create <new-tunnel-name>

# Update tunnel configuration
sudo nano /etc/cloudflared/config.yml
```

### SSH Key Authentication Issues

**Symptoms:**
- "Permission denied (publickey)" errors
- Key authentication failures
- "Invalid key format" messages

**Diagnostic Steps:**
```bash
# Check SSH key format
ssh-keygen -l -f ~/.ssh/id_rsa.pub

# Verify authorized_keys file
sudo cat /home/jules/.ssh/authorized_keys

# Check file permissions
ls -la /home/jules/.ssh/
```

**Solutions:**
```bash
# Fix SSH directory permissions
sudo chmod 700 /home/jules/.ssh
sudo chmod 600 /home/jules/.ssh/authorized_keys
sudo chown -R jules:jules /home/jules/.ssh

# Validate SSH key format
# Key should start with ssh-rsa, ssh-ed25519, etc.

# Test key authentication locally
ssh -i ~/.ssh/id_rsa jules@localhost
```

## Docker-Specific Issues

### Container Startup Fails

**Symptoms:**
- Container exits immediately
- "Exited with code 1" errors
- Service startup failures in container

**Diagnostic Steps:**
```bash
# Check container logs
docker-compose logs jules-agent

# Run container interactively
docker-compose run --rm jules-agent /bin/bash

# Check environment variables
docker-compose config
```

**Solutions:**
```bash
# Verify environment variables in docker-compose.yml
# Ensure CLOUDFLARE_TOKEN and JULES_SSH_PUBLIC_KEY are set

# Rebuild container
docker-compose down
docker-compose up --build -d

# Check health status
docker-compose exec jules-agent /healthcheck.sh
```

### GPU Access Issues

**Symptoms:**
- "nvidia-smi: command not found" in container
- GPU not visible to applications
- CUDA errors

**Solutions:**
```bash
# Verify NVIDIA Docker runtime
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# Check docker-compose.yml GPU configuration
# Ensure deploy.resources.reservations.devices section is uncommented

# Install NVIDIA Container Toolkit (host system)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

## Performance Issues

### Slow Connection or High Latency

**Symptoms:**
- Slow SSH response times
- Command execution delays
- File transfer slowness

**Solutions:**
```bash
# Test network connectivity
ping your-tunnel-hostname.trycloudflare.com

# Check system resources
htop
df -h
free -h

# Optimize SSH configuration
# Add to ~/.ssh/config:
# Host your-tunnel-hostname.trycloudflare.com
#   Compression yes
#   ServerAliveInterval 60
#   ServerAliveCountMax 3
```

### High Resource Usage

**Symptoms:**
- High CPU or memory usage
- System slowdown
- Out of memory errors

**Solutions:**
```bash
# Monitor resource usage
top
iostat 1

# Check for resource-intensive processes
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10

# Adjust container resource limits (Docker)
# Add to docker-compose.yml:
# deploy:
#   resources:
#     limits:
#       cpus: '2.0'
#       memory: 4G
```

## Security Issues

### Unauthorized Access Attempts

**Symptoms:**
- Multiple failed login attempts in logs
- Suspicious connection patterns
- Unknown SSH sessions

**Monitoring:**
```bash
# Check SSH logs
sudo journalctl -u ssh -f

# Monitor active SSH sessions
who
w

# Check authentication logs
sudo grep "Failed password" /var/log/auth.log
sudo grep "Accepted publickey" /var/log/auth.log
```

**Solutions:**
```bash
# Install and configure fail2ban
sudo apt install -y fail2ban

# Create SSH jail configuration
sudo tee /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# Restart fail2ban
sudo systemctl restart fail2ban
```

### SSH Key Compromise

**Symptoms:**
- Unauthorized access with valid keys
- Suspicious activity from known connections
- Need to rotate keys

**Solutions:**
```bash
# Generate new SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/jules_new -C "jules-endpoint-new"

# Update authorized_keys
sudo cp /home/jules/.ssh/authorized_keys /home/jules/.ssh/authorized_keys.backup
echo "new-public-key-content" | sudo tee /home/jules/.ssh/authorized_keys

# Test new key
ssh -i ~/.ssh/jules_new jules@your-tunnel-hostname.trycloudflare.com

# Remove old key after verification
```

## Diagnostic Commands

### System Health Check

```bash
# Run comprehensive diagnostics
./test-diagnostics.sh

# Check all services
sudo systemctl status ssh cloudflared

# Verify network connectivity
curl -I https://your-tunnel-hostname.trycloudflare.com

# Test SSH connectivity
ssh -o ConnectTimeout=10 jules@your-tunnel-hostname.trycloudflare.com "echo 'Connection successful'"
```

### Log Analysis

```bash
# SSH service logs
sudo journalctl -u ssh --since "1 hour ago"

# Cloudflared logs
sudo journalctl -u cloudflared --since "1 hour ago"

# System logs
sudo journalctl --since "1 hour ago" | grep -E "(ssh|cloudflared|jules)"

# Authentication logs
sudo grep -E "(ssh|jules)" /var/log/auth.log | tail -20
```

## Getting Additional Help

### Information to Collect

When seeking help, please provide:

1. **System Information:**
   ```bash
   uname -a
   lsb_release -a
   docker --version  # if using Docker
   ```

2. **Service Status:**
   ```bash
   sudo systemctl status ssh cloudflared
   ```

3. **Configuration Files:**
   ```bash
   sudo cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"
   sudo cat /etc/cloudflared/config.yml
   ```

4. **Recent Logs:**
   ```bash
   sudo journalctl -u ssh --since "1 hour ago"
   sudo journalctl -u cloudflared --since "1 hour ago"
   ```

### Support Channels

- Check the main [README.md](./README.md) for basic setup instructions
- Review platform-specific documentation in respective directories
- Run diagnostic scripts: `./test-diagnostics.sh`
- Check [GitHub Issues](https://github.com/your-repo/issues) for known problems
- Create a new issue with diagnostic information if problem persists

### Emergency Recovery

If the system becomes inaccessible:

1. **Physical/Console Access:**
   ```bash
   # Stop services
   sudo systemctl stop cloudflared ssh
   
   # Reset SSH configuration
   sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
   
   # Restart services
   sudo systemctl start ssh cloudflared
   ```

2. **Complete Removal:**
   ```bash
   # Run uninstall script
   sudo ./linux/uninstall.sh
   
   # Manual cleanup if needed
   sudo userdel -r jules
   sudo systemctl stop cloudflared
   sudo rm -rf /etc/cloudflared
   ```

3. **Fresh Installation:**
   ```bash
   # Clean installation
   sudo ./linux/install.sh
   ```