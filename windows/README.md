# Jules Endpoint Agent: Native Windows Installation

**Status: ✅ Available - SSH-based architecture implemented**

This directory contains PowerShell scripts to install the Jules Endpoint Agent directly on Windows systems using the native OpenSSH Server and Cloudflare tunnels.

## Quick Start

```powershell
# Run as Administrator in PowerShell
.\install.ps1
```

## Features

- **Native OpenSSH Server**: Uses Windows 10/11 built-in OpenSSH Server
- **PowerShell Automation**: Full PowerShell-based installation and management
- **Windows Service Integration**: Proper Windows service management for cloudflared
- **User Account Management**: Creates dedicated `jules` user with administrative privileges
- **SSH Key Authentication**: Secure public key authentication only
- **Automatic Configuration**: Complete setup with connection information generation

## Installation Process

The installer performs the following steps:

1. **System Validation**: Checks Windows version and administrator privileges
2. **SSH Key Input**: Prompts for Jules' SSH public key with validation
3. **OpenSSH Server Setup**: Enables and configures Windows OpenSSH Server
4. **cloudflared Installation**: Downloads and installs cloudflared
5. **User Creation**: Creates `jules` user with administrative privileges
6. **SSH Configuration**: Sets up SSH keys and secure configuration
7. **Tunnel Setup**: Creates and configures Cloudflare tunnel
8. **Service Installation**: Installs cloudflared as Windows service
9. **Connection Info**: Generates ready-to-use connection details

### Prerequisites

- Windows 10 version 1809+ or Windows 11
- PowerShell 5.1 or PowerShell 7+
- Administrator privileges
- Internet connectivity for downloads
- Jules' SSH public key

### Installation Command

```powershell
# Download and run the installer
.\install.ps1
```

## Windows-Specific Implementation

### OpenSSH Server Configuration
- Windows stores SSH configuration in `C:\ProgramData\ssh\sshd_config`
- User SSH keys stored in `C:\Users\jules\.ssh\authorized_keys`
- Service managed via Windows Services (`sshd`)

### User Management
- `jules` user added to Administrators group for full system access
- Configured for passwordless SSH key authentication only
- Random password set (not used due to key-only authentication)

### Service Management
- OpenSSH Server: Windows built-in service
- cloudflared: Installed as Windows Service with automatic startup
- Both services configured for automatic startup

### Security Features
- **SSH Key Authentication**: Password authentication disabled
- **Windows Firewall**: Automatic firewall rule configuration for SSH
- **Administrative Access**: Full system access for AI agent tasks
- **Encrypted Tunnels**: All traffic encrypted through Cloudflare network

## Usage

### Getting Connection Information

After installation, use the connection info script:

```powershell
.\connection-info.ps1
```

Options:
- `-HostnameOnly`: Output only the tunnel hostname
- `-SshCommandOnly`: Output only the SSH connection command
- `-Help`: Show help information

### Service Management

Check service status:
```powershell
Get-Service sshd, cloudflared
```

Restart services:
```powershell
Restart-Service sshd
Restart-Service cloudflared
```

### Logs and Troubleshooting

View SSH service logs:
```powershell
Get-EventLog -LogName System -Source sshd -Newest 10
```

View cloudflared logs:
```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='cloudflared'} -MaxEvents 10
```

## Uninstallation

To completely remove the Jules Endpoint Agent:

```powershell
.\install.ps1 -Uninstall
```

This will:
- Stop and remove cloudflared service
- Remove the `jules` user account
- Clean up SSH configuration changes
- Remove cloudflared configuration files
- Restore SSH configuration backup

## Connection Information Format

The installer generates connection information in this format:

```
Host jules-endpoint
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

## Security Considerations

### Access Level
- The `jules` user has **full administrative access** to the Windows system
- Can install software, modify system settings, and access all files
- Suitable for development, testing, and automation tasks

### Network Security
- No direct network ports exposed on the host machine
- All connections routed through Cloudflare's encrypted tunnels
- SSH traffic encrypted end-to-end

### Recommendations
- Use on dedicated development/testing machines
- Consider using Docker installation for better isolation
- Monitor system activity and logs regularly
- Keep SSH keys secure and rotate periodically

## Troubleshooting

### Common Issues

**OpenSSH Server fails to start:**
- Ensure Windows version supports OpenSSH Server (Windows 10 1809+)
- Check Windows Features to ensure OpenSSH Server is enabled
- Verify no conflicting SSH services are running

**cloudflared service fails:**
- Check internet connectivity
- Verify Cloudflare authentication completed successfully
- Check Windows Event Log for cloudflared errors

**SSH connection refused:**
- Verify both sshd and cloudflared services are running
- Check SSH key is properly configured in authorized_keys
- Test local SSH connection: `ssh jules@localhost`

**Tunnel hostname not found:**
- Wait a few minutes for tunnel to establish
- Run `cloudflared tunnel list` to verify tunnel exists
- Check cloudflared service logs for errors

### Getting Help

1. Check service status and logs (commands above)
2. Run connection info script for current status
3. Review installation log at `%TEMP%\jules-endpoint-install.log`
4. Consult main project troubleshooting documentation

## Alternative: Docker Installation

For better isolation and consistency, consider the Docker-based installation:

```powershell
cd ..\docker
docker-compose up --build -d
```

Benefits of Docker approach:
- Isolated from Windows host system
- Consistent Ubuntu environment
- GPU passthrough support
- Easier cleanup and management

## Files in this Directory

- `install.ps1` - Main installation script
- `connection-info.ps1` - Connection information generator
- `README.md` - This documentation

## Contributing

Contributions welcome for:
- PowerShell script improvements
- Windows-specific optimizations
- Additional security features
- Testing on various Windows versions
- Documentation improvements
