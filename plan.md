# Plan for Architectural Change: From HTTP to SSH

This document outlines the current architecture of the Jules Endpoint Agent and proposes a plan to transition it from an HTTP-based command execution system to a more secure and standard SSH-based setup.

## 1. Analysis of the Current (HTTP-based) Architecture

The repository's current goal is to provide a web-accessible execution environment for an AI agent. It achieves this by creating a secure tunnel to a local web service that executes shell commands.

### Core Components:

*   **`shell2http`**: This is the primary component responsible for exposing a shell script (`common/runner.sh`) as a web endpoint. It launches a simple HTTP server that, upon receiving a request, executes the script.
*   **`cloudflared`**: This component creates a secure, persistent outbound tunnel (a Cloudflare Tunnel) from the host machine to the Cloudflare network. This tunnel makes the local `shell2http` server accessible from a public URL without requiring the user to open or forward any ports on their router.
*   **`runner.sh`**: A bash script that acts as the entry point for executing commands received via the HTTP request.
*   **Authentication**: Security is handled via HTTP Basic Authentication (`username:password`), which is configured when `shell2http` is launched. The credentials are provided to the agent, which includes them in every HTTP request.

### How it Works (Flow):

1.  **Installation**: The user runs an installation script (e.g., for Docker, Linux, or Windows).
2.  **Service Setup**: The installer downloads `shell2http` and `cloudflared`. It configures them to run as background services.
    *   `shell2http` is started, listening on a local port (e.g., 8080) and configured to execute `runner.sh` when the `/run` endpoint is hit.
    *   `cloudflared` is started, authenticating with the user's Cloudflare account and tunneling the local port 8080 to a public `trycloudflare.com` URL.
3.  **Execution**:
    *   An external AI agent makes an HTTP POST request to the public Cloudflare URL.
    *   The request includes the Basic Auth credentials and the command to be executed.
    *   Cloudflare's network routes the request through the tunnel to the `cloudflared` service on the host machine.
    *   `cloudflared` forwards the request to the local `shell2http` server.
    *   `shell2http` validates the credentials, receives the request, and executes the `runner.sh` script with the command.
    *   The script's output (`stdout`/`stderr`) is returned as the HTTP response body.

### Limitations of this Approach:

*   **Non-Standard for Shell Access**: Using HTTP for shell access is unconventional. The standard and expected protocol for remote shell access is SSH, which is purpose-built for this task.
*   **Security Concerns**: While Cloudflare Tunnel provides a secure transport layer (HTTPS), HTTP Basic Authentication is a relatively weak form of authentication compared to modern standards like SSH public/private key cryptography.
*   **Tool Incompatibility**: Many development and administration tools are designed to work seamlessly over SSH. They cannot be used with this custom HTTP-based endpoint.
*   **State Management**: HTTP is stateless. The current setup does not provide a true, persistent interactive shell, which limits the complexity of tasks that can be performed. Each command runs in a new, isolated process.

## 2. Proposal for a New (SSH-based) Architecture

To better align with standard security practices and provide a more robust and compatible solution, I propose transitioning the agent to an SSH-based architecture.

### Core Components:

*   **`openssh-server`**: This industry-standard SSH server will replace `shell2http`. It will be responsible for handling incoming SSH connections.
*   **`cloudflared`**: This component will be retained, but its configuration will be changed. Instead of tunneling HTTP traffic, it will be configured to tunnel SSH traffic (on port 22).
*   **Authorized Keys**: Authentication will be handled using SSH public/private key pairs, which is significantly more secure than password-based authentication. The agent user will have their public key added to the `~/.ssh/authorized_keys` file on the host machine.

### How it Will Work (Flow):

1.  **Installation**: The user runs an installation script.
2.  **SSH Key Setup**: The installer will guide the user to provide a public SSH key for the AI agent.
3.  **Service Setup**:
    *   The installer will install `openssh-server`.
    *   It will create a dedicated, non-root user account for the agent.
    *   It will place the agent's public key into the appropriate `authorized_keys` file for that user.
    *   `cloudflared` will be installed and configured to tunnel the local SSH port (22).
4.  **Execution**:
    *   The external AI agent, configured with the corresponding private SSH key, uses a standard SSH client to connect to the public Cloudflare hostname.
    *   Cloudflare's network routes the SSH connection through the tunnel to the `cloudflared` service.
    *   `cloudflared` forwards the TCP connection to the local `openssh-server` on port 22.
    *   The SSH server authenticates the agent using its public key.
    *   The agent is granted a standard, interactive shell session on the host machine, running as the dedicated, unprivileged user.

### Implementation Steps:

1.  **Update `Dockerfile`**:
    *   Remove the installation of `shell2http`.
    *   Add the installation of `openssh-server`.
    *   Modify the entrypoint script to start the `sshd` service and a reconfigured `cloudflared` service.
    *   Add logic to accept an agent's public SSH key as a build argument or environment variable and add it to the `authorized_keys` file.

2.  **Update `linux/install.sh`** (and other OS-specific installers):
    *   Remove all logic related to `shell2http`.
    *   Add logic to install `openssh-server`.
    *   Add steps to create a user account for the agent.
    *   Modify the user interaction to prompt for an SSH public key instead of a username/password.
    *   Update the `cloudflared` configuration to point to `localhost:22` instead of `localhost:8080`.
    *   Update the systemd service to run `sshd`.

3.  **Update Documentation (`README.md` files)**:
    *   Rewrite all `README.md` files to remove references to `shell2http`, HTTP Basic Auth, and the old workflow.
    *   Add detailed instructions for the new SSH-based workflow, including:
        *   How to generate an SSH key pair.
        *   How to provide the public key during installation.
        *   How to configure an AI agent to use the private key and the Cloudflare URL to connect.

4.  **Create Uninstallation Scripts**:
    *   As a best practice, create corresponding `uninstall.sh` scripts that can cleanly remove all components (user account, SSH configuration, services, `cloudflared` tunnel) to restore the system to its previous state.
