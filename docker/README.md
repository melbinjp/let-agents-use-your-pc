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
    - `CLOUDFLARE_TOKEN`: Get this from the Cloudflare Zero Trust dashboard. When you create a tunnel, Cloudflare will give you a token string.
    - `JULES_SSH_PUBLIC_KEY`: Paste the **public key** (the contents of the `.pub` file, e.g., `id_rsa.pub`) of the SSH key pair that your agent will use to connect.
3.  **Build and Run:** From your terminal in this `docker` directory, run the following command:
    ```bash
    docker-compose up --build -d
    ```
    This will build the Docker image, create a container, and run it in the background.
4.  **Get Your Connection Info:**
    - The public hostname will be visible in the Cloudflare Zero Trust dashboard for the tunnel you created.
    - You will connect using SSH. The command will look like this (replace `<your-tunnel-hostname>` with the actual hostname from Cloudflare):
    ```bash
    ssh jules@<your-tunnel-hostname>
    ```
    You must use the corresponding private key to connect.

### Enabling GPU Access (Optional)

If you need the agent to have access to your NVIDIA GPU:
1.  Ensure you have met the prerequisites mentioned in the main `README.md`.
2.  Open the `docker-compose.yml` file.
3.  Uncomment the `deploy` section at the bottom of the file.
4.  Restart the container: `docker-compose up --build -d`.

The agent running inside the container will now have access to the GPU.
