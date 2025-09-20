# Jules Endpoint Agent: Docker Installation

This directory contains the necessary files to run the Jules Endpoint Agent in a Docker container.

This method is highly recommended for users who want a standardized, isolated, and high-performance Linux environment for the agent, regardless of their host operating system (Windows, macOS, or Linux).

## File Descriptions

- `Dockerfile`: This file defines the Docker image. It builds a standard Ubuntu environment, installs all necessary dependencies (`git`, `openssh-server`, `cloudflared`), and sets up the agent's runner script and entrypoint for a secure SSH connection.
- `docker-compose.yml`: This is the easiest way to run the agent. It defines the service and manages the required `CLOUDFLARE_TOKEN` environment variable.
- `runner.sh`: A copy of the Linux runner script, included here to be copied into the Docker image during the build process.

## Installation and Setup

The full, end-to-end instructions for setting up the Cloudflare Tunnel and connecting to the agent are in the main documentation file in the root of this repository:

**➡️ [CLOUDFLARE_SETUP.md](../CLOUDFLARE_SETUP.md)**

The high-level steps are:
1.  Create a Cloudflare Tunnel and get a token.
2.  Configure this `docker-compose.yml` file with your token.
3.  Run `docker compose up --build -d`.
4.  Configure your local machine's SSH client to connect through the tunnel.

Please refer to the main setup guide for detailed instructions.

## Enabling GPU Access (Optional)

If you need the agent to have access to your NVIDIA GPU:
1.  Ensure you have met the prerequisites (Docker, latest NVIDIA drivers, NVIDIA Container Toolkit).
2.  Open the `docker-compose.yml` file.
3.  Uncomment the `deploy` section at the bottom of the file.
4.  Restart the container: `docker compose up --build -d`.

The agent running inside the container will now have access to the GPU.
