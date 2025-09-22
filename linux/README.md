# Jules Endpoint Agent: Native Linux Installation (SSH)

This directory contains the script to install the Jules Endpoint Agent directly on a modern Linux distribution (e.g., Ubuntu, Debian).

This method configures your machine as a secure, remotely-accessible SSH endpoint, which an AI agent can connect to for development tasks.

## How it Works

The `install.sh` script automates the entire setup process:
1.  **Installs Dependencies**: It installs `openssh-server` (the standard SSH server for Linux) and `cloudflared` (the Cloudflare Tunnel client).
2.  **Creates an Agent User**: It creates a dedicated, non-root user account named `jules` to isolate the agent's activities.
3.  **Configures SSH**: It prompts you for the agent's public SSH key and adds it to the `jules` user's `authorized_keys` file. This ensures secure, passwordless authentication.
4.  **Creates a Secure Tunnel**: It uses `cloudflared` to create a secure tunnel from your local SSH server (on port 22) to the Cloudflare network, making it accessible via a public hostname without opening any ports on your firewall.
5.  **Sets up Services**: It ensures that both the `sshd` and `cloudflared` services are enabled to run automatically on system startup.

## Installation Instructions

### Prerequisites
- A modern Debian-based Linux distribution (e.g., Ubuntu 20.04+, Debian 10+).
- You must have `sudo` or root access to the machine.
- You must have an SSH key pair for your AI agent. The script will ask you for the **public key**.

### Running the Installer

1.  **Clone the Repository:**
    ```bash
    git clone <repo-url>
    cd <repo-name>/linux
    ```
2.  **Make the Script Executable:**
    ```bash
    chmod +x install.sh
    ```
3.  **Run with Sudo:**
    ```bash
    sudo ./install.sh
    ```
4.  **Follow the Prompts:**
    - The script will first ask you to **paste the agent's public SSH key**.
    - It will then ask you to **log in to your Cloudflare account** in a browser to authorize the tunnel creation.
5.  **Get Your Connection Info:**
    - At the end of the installation, the script will display the public hostname for your new SSH endpoint (e.g., `your-tunnel-name.trycloudflare.com`).
    - The agent will use this hostname to connect. The final command will look like this:
    ```bash
    ssh jules@<your-tunnel-hostname>
    ```

## Uninstallation
To remove the agent and all its components, a corresponding `uninstall.sh` script will be provided. (This is part of the implementation plan).
