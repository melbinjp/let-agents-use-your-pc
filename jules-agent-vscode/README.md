# Jules Endpoint Agent - VS Code Extension

Welcome to the Jules Endpoint Agent VS Code extension! This extension provides a simple and integrated way to turn your machine into a secure, remotely-accessible execution endpoint for the Jules AI agent.

It automates the process of setting up the agent by using a sandboxed Docker container, ensuring a consistent and secure environment.

---

##  Prerequisites

Before using this extension, you **must** have **Docker** installed and running on your system.

- **Windows/macOS:** [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Linux:** [Docker Engine](https://docs.docker.com/engine/install/)

You can verify that Docker is running by opening a terminal and typing `docker info`. If it returns information about your Docker installation, you are ready to go.

---

## Features

This extension contributes the following commands to the Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`):

### `Jules Agent: Start Endpoint`
This is the main command for setting up and launching the agent. When you run this command, the extension will:

1.  **Check if Docker is running.**
2.  **Ask for your credentials:**
    -   Your **Cloudflare Tunnel Token**.
    -   A **username** for the agent.
    -   A **password** for the agent.
3.  **Build the agent's Docker image.** This happens automatically the first time or if the image is updated.
4.  **Start the agent container.** The container will run in the background and restart automatically if your machine reboots.

### `Jules Agent: Stop Endpoint`
This command safely stops and removes the agent's Docker container. Use this when you no longer want the agent to be active.

### `Jules Agent: View Logs`
This command opens a new terminal window inside VS Code and streams the live logs from the running agent container. This is useful for troubleshooting or monitoring the agent's activity.

---

## How to Use

1.  **Install Docker** and make sure it is running.
2.  **Install this extension** from the VS Code Marketplace.
3.  Open the **Command Palette** (`Ctrl+Shift+P` or `Cmd+Shift+P`).
4.  Type `Jules Agent` to see the available commands.
5.  Select **`Jules Agent: Start Endpoint`**.
6.  Follow the prompts to enter your Cloudflare token and desired credentials.
7.  The extension will handle the rest! You can monitor the progress in the notification pop-ups and the "Jules Agent" output channel.
8.  Your endpoint URL will be visible in your Cloudflare Zero Trust dashboard.

---

## Security Note

This extension uses Docker to provide a strong layer of isolation. However, you are still creating a bridge to your machine from the internet. Please ensure you use a strong, unique password for the agent and keep your Cloudflare Tunnel Token secure.
