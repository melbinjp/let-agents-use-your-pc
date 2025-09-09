# Jules Endpoint Agent: Docker Installation

This directory contains the necessary files to run the Jules Endpoint Agent in a Docker container.

This method is highly recommended for users who want a standardized, isolated, and high-performance Linux environment for the agent, regardless of their host operating system (Windows, macOS, or Linux).

## File Descriptions

- `Dockerfile`: This file defines the Docker image. It builds a standard Ubuntu environment, installs all necessary dependencies (`git`, `cloudflared`, `shell2http`), and sets up the agent's runner script and entrypoint.
- `docker-compose.yml`: This is the easiest way to run the agent. It defines the service, manages environment variables for credentials, and includes a pre-configured section for enabling GPU acceleration.
- `runner.sh`: A copy of the Linux runner script, included here to be copied into the Docker image during the build process.

## Design Choices & Technical Details

### Why Docker?
- **Consistency:** The agent runs in the exact same Ubuntu-based environment every time, no matter what the host OS is. This eliminates "it works on my machine" problems.
- **Isolation & Security:** The agent and any commands it runs are sandboxed inside the container. This provides a strong layer of security, preventing accidental or malicious changes to the host system.
- **Performance & Hardware Acceleration:** Unlike traditional VMs, Docker can provide near-native performance. Crucially, it allows for direct access to the host's GPU (on Windows and Linux), which is essential for machine learning and other hardware-accelerated tasks.

### Acknowledging Limitations
- **Native Testing:** This method runs a *Linux* container. It cannot be used to test projects that require a native Windows or macOS environment. For that, please use the native installers.
- **GPU on macOS:** GPU acceleration for Docker containers on macOS is not well-supported by Docker Desktop at this time. The GPU instructions below apply primarily to Windows (with WSL2) and Linux hosts.

## Installation Instructions

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for Windows/macOS) or Docker Engine (for Linux) must be installed.
- (Optional, for GPU) For NVIDIA GPUs, you must have the latest drivers installed. On Linux, you must also install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). On Windows, GPU support must be enabled in Docker Desktop's settings.

### Running the Agent

1.  **Clone the Repository:** You will need these files locally. Clone the repository and navigate into this `docker` directory.
2.  **Configure Credentials:** Open the `docker-compose.yml` file in a text editor. You **must** fill in the following environment variables:
    - `CLOUDFLARE_TOKEN`: Get this from the Cloudflare Zero Trust dashboard by creating a new tunnel and copying the token string.
    - `JULES_USERNAME`: The username for the agent.
    - `JULES_PASSWORD`: The password for the agent.
3.  **Build and Run:** From your terminal in this `docker` directory, run the following command:
    ```bash
    docker-compose up --build -d
    ```
    This will build the Docker image, create a container, and run it in the background.
4.  **Get Your URL:** The public URL will be visible in the Cloudflare Zero Trust dashboard for the tunnel you created.

### Enabling GPU Access (Optional)

If you need the agent to have access to your NVIDIA GPU:
1.  Ensure you have met the prerequisites mentioned above.
2.  Open the `docker-compose.yml` file.
3.  Uncomment the `deploy` section at the bottom of the file.
4.  Restart the container: `docker-compose up --build -d`.

The agent running inside the container will now have access to the GPU.
