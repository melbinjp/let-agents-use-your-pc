# Jules Endpoint Agent: Native macOS Installation

**Status: ✅ Available - SSH-based architecture implemented**

This directory contains shell scripts to install the Jules Endpoint Agent directly on macOS systems using the built-in SSH server and Cloudflare tunnels.

## Quick Start

```bash
# Run as root/sudo
sudo ./install.sh
```

## Features

- **Native SSH Server**: Uses macOS built-in SSH server (Remote Login)
- **Homebrew Integration**: Automatic dependency installation via Homebrew
- **launchd Service Management**: Proper macOS service integration for cloudflared
- **User Account Management**: Creates dedicated `jules` user with administrative privileges
- **SSH Key Authentication**: Secure public key authentication only
- **Apple Silicon Support**: Full compatibility with M1/M2/M3 Macs

## Installation Process

The installer performs the following steps:

1. **System Validation**: Checks macOS version and root privileges
2. **SSH Key Input**: Prompts for Jules' SSH public key with validation
3. **SSH Server Setup**: Enables Remote Login and configures SSH server
4. **Homebrew Setup**: Installs Homebrew if not present
5. **cloudflared Installation**: Installs cloudflared via Homebrew
6. **User Creation**: Creates `jules` user with admin group membership
7. **SSH Configuration**: Sets up SSH keys and secure configuration
8. **Tunnel Setup**: Creates and configures Cloudflare tunnel
9. **Service Installation**: Installs cloudflared as launchd service
10. **Connection Info**: Generates ready-to-use connection details

### Prerequisites

- macOS 10.15 (Catalina) or later
- Administrator privileges (sudo access)
- Internet connectivity for downloads
- Jules' SSH public key
- Xcode Command Line Tools (installed automatically if needed)

### Installation Command

```bash
# Download and run the installer
sudo ./install.sh
```

## macOS-Specific Implementation

### SSH Server Configuration
- macOS SSH configuration in `/etc/ssh/sshd_config`
- User SSH keys stored in `/Users/jules/.ssh/authorized_keys`
- Remote Login managed via `systemsetup` and System Preferences

### User Management
- `jules` user created using `dscl` (Directory Service Command Line)
- Added to `admin` group for sudo access
- Proper home directory creation with correct ownership
- Configured for passwordless SSH key authentication

### Service Management
- SSH server: macOS built-in `com.openssh.sshd` launchd service
- cloudflared: Installed as `com.cloudflare.cloudflared` launchd daemon
- Both services configured for automatic startup

### Homebrew Integration
- Automatic Homebrew installation if not present
- Works on both Intel and Apple Silicon Macs
- cloudflared installed via `brew install cloudflared`
- Proper PATH configuration for both architectures

## Usage

### Getting Connection Information

After installation, use the connection info script:

```bash
sudo ./connection-info.sh
```

Options:
- `--hostname-only`: Output only the tunnel hostname
- `--ssh-command-only`: Output only the SSH connection command
- `--help`: Show help information

### Service Management

Check Remote Login status:
```bash
systemsetup -getremotelogin
```

Enable/disable Remote Login:
```bash
sudo systemsetup -setremotelogin on
sudo systemsetup -setremotelogin off
```

Check cloudflared service:
```bash
launchctl list | grep cloudflared
```

Restart cloudflared:
```bash
sudo launchctl stop com.cloudflare.cloudflared
sudo launchctl start com.cloudflare.cloudflared
```

### Logs and Troubleshooting

View SSH logs:
```bash
log show --predicate 'process == "sshd"' --last 1h
```

View cloudflared logs:
```bash
log show --predicate 'process == "cloudflared"' --last 1h
```

## Uninstallation

To completely remove the Jules Endpoint Agent:

```bash
sudo ./install.sh --uninstall
```

This will:
- Stop and remove cloudflared service
- Remove the `jules` user account
- Clean up SSH configuration changes
- Remove cloudflared configuration files
- Restore SSH configuration backup

Note: Remote Login (SSH) is left enabled. Disable manually in System Preferences > Sharing if not needed.

## Connection Information Format

The installer generates connection information in this format:

```
Host jules-endpoint-macos
    HostName [generated-hostname].trycloudflare.com
    User jules
    Port 22
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Quick connect command:
```bash
ssh jules@[generated-hostname].trycloudflare.com
```

## Apple Silicon Support

Full compatibility with Apple Silicon Macs:
- Native ARM64 cloudflared binary via Homebrew
- Optimized performance on M1/M2/M3 processors
- No Rosetta 2 translation required
- Homebrew automatically detects architecture

Installation paths:
- Intel Macs: `/usr/local/bin/brew`
- Apple Silicon: `/opt/homebrew/bin/brew`

## Security Considerations

### Access Level
- The `jules` user has **full administrative access** via sudo
- Can install software, modify system settings, and access all files
- Suitable for development, testing, and automation tasks

### Network Security
- No direct network ports exposed on the host machine
- All connections routed through Cloudflare's encrypted tunnels
- SSH traffic encrypted end-to-end

### macOS Integration
- Compatible with System Integrity Protection (SIP)
- Respects macOS privacy and security settings
- Works with Gatekeeper and notarization requirements

### Recommendations
- Use on dedicated development/testing machines
- Consider using Docker installation for better isolation
- Monitor system activity via Console.app
- Keep SSH keys secure and rotate periodically

## Troubleshooting

### Common Issues

**Remote Login fails to enable:**
- Check System Preferences > Sharing > Remote Login
- Verify user has administrator privileges
- Try enabling manually via System Preferences

**Homebrew installation fails:**
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check internet connectivity
- Verify sufficient disk space

**cloudflared service fails:**
- Check Homebrew installation: `brew --version`
- Verify Cloudflare authentication completed
- Check launchd service status: `launchctl list | grep cloudflared`

**SSH connection refused:**
- Verify Remote Login is enabled: `systemsetup -getremotelogin`
- Check SSH key is properly configured in authorized_keys
- Test local SSH connection: `ssh jules@localhost`

**User creation fails:**
- Ensure running with sudo privileges
- Check if username conflicts with existing accounts
- Verify system has available UID in valid range

### Getting Help

1. Check service status and logs (commands above)
2. Run connection info script for current status
3. Review installation log at `/tmp/jules-endpoint-install.log`
4. Use Console.app to view system logs
5. Consult main project troubleshooting documentation

## Alternative: Docker Installation

For better isolation and consistency, consider the Docker-based installation:

```bash
cd ../docker
docker-compose up --build -d
```

Benefits of Docker approach:
- Isolated from macOS host system
- Consistent Ubuntu environment
- Works identically on Intel and Apple Silicon
- Easier cleanup and management
- GPU support with appropriate configuration

## Files in this Directory

- `install.sh` - Main installation script
- `connection-info.sh` - Connection information generator
- `README.md` - This documentation

## macOS Version Compatibility

Tested on:
- macOS Monterey (12.x)
- macOS Ventura (13.x)
- macOS Sonoma (14.x)

Both Intel and Apple Silicon architectures supported.

## Contributing

Contributions welcome for:
- Shell script improvements
- macOS-specific optimizations
- Additional security features
- Testing on various macOS versions
- Apple Silicon optimizations
- Documentation improvements
