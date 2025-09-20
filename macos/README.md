# Jules Endpoint Agent: macOS Installation (SSH Method)

This directory contains the necessary scripts to install the Jules Endpoint Agent on a macOS machine, providing secure remote access via an SSH tunnel powered by Cloudflare.

## File Descriptions

- `install.sh`: The main installer script. It handles dependency checks, downloads `cloudflared`, and configures the Cloudflare tunnel as a `launchd` service for persistence.
- `runner.sh`: The execution script. This script is intended to be called by the connecting AI agent over the SSH connection. It is placed in `/usr/local/etc/jules-endpoint-agent/` for inspection.

## Design Choices & Technical Details

### Why Bash and launchd?
- **Bash:** Bash is a standard shell available on macOS, ensuring the scripts run correctly.
- **launchd:** `launchd` is the standard system for managing services on macOS. Using a `launchd` plist file is the correct, native way to ensure the `cloudflared` tunnel runs automatically.

### Security Considerations
- **Root Privileges:** The `install.sh` script requires `sudo` access to install `cloudflared` into `/usr/local/bin` and to create service and configuration files.
- **SSH Authentication:** This setup relies on SSH public key authentication, which is significantly more secure than password-based methods. The agent's public key must be added to the appropriate `~/.ssh/authorized_keys` file on the host machine.

## Installation Instructions

### Prerequisites
- A macOS machine.
- **Remote Login** must be enabled. You can do this in `System Settings` > `General` > `Sharing`.
- `git` and `curl` must be installed. They are typically available by default or can be installed with the Xcode Command Line Tools.

### Running the Installer
1. **Clone the Repository:**
   ```bash
   git clone https://github.com/melbinjp/let-agents-use-your-pc.git
   ```
2. **Navigate to the Directory:**
   ```bash
   cd let-agents-use-your-pc/macos
   ```
3. **Run the Installer:**
   ```bash
   sudo ./install.sh
   ```

The script will guide you through the Cloudflare login and tunnel creation process.

### Post-Installation
Once the script is complete, you must add the AI agent's public SSH key to the `authorized_keys` file of the user you wish the agent to run as. For example:
```bash
# As the target user (e.g., 'dev')
echo "ssh-ed25519 AAAAC3... agent@example.com" >> ~/.ssh/authorized_keys
```

The installer will provide you with the SSH connection command to give to the agent.
