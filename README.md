# Jules Endpoint Agent

Welcome to the Jules Endpoint Agent! This project provides a set of scripts to turn any Linux or macOS machine into a secure, remotely-accessible execution endpoint. An AI agent like Jules can then use this endpoint to perform tasks like cloning repositories, running tests, and executing build commands in a real development environment.

This is ideal for giving an AI agent access to more powerful hardware, specific development tools, or a persistent environment that survives beyond a single session.

---

## 🛑 Security Warning

**This is extremely important.** By installing this agent, you are creating a bridge between the public internet and a shell on your machine. The `runner.sh` script is designed to execute arbitrary commands sent to it.

While we use a secure tunnel (`cloudflared`) and recommend authentication, this setup grants significant control to the connecting agent.

**Please follow these security best practices:**
- **Run this on a dedicated, sandboxed virtual machine (VM).** Do not run it on your primary personal or work machine.
- **Never expose the `shell2http` port directly.** Only access it through the secure Cloudflare tunnel.
- **Use the strongest authentication method you can.** The default installation will guide you to set up a username and password.
- **Review the scripts (`install.sh`, `runner.sh`) before running them** to understand what they do.

---

## ⚙️ How It Works

The system is built on two key open-source tools:

1.  **[Cloudflared](https://github.com/cloudflare/cloudflared):** Creates a secure, persistent tunnel from your machine to the Cloudflare network. This means you don't need to configure firewalls, port forwarding, or deal with dynamic IP addresses. You get a stable, public HTTPS URL.
2.  **[shell2http](https://github.com/msoap/shell2http):** A simple web server that executes a shell script (`runner.sh`) whenever it receives an HTTP request. It's configured to pass request data as environment variables to the script.

The flow is as follows:
`Jules -> HTTPS Request -> Cloudflare Tunnel -> cloudflared (on your VM) -> shell2http -> runner.sh (executes git clone, etc.)`

---

## 📋 Prerequisites

Before you begin, please ensure you have the following:

- A **Linux or macOS** machine. For Windows users, please see the dedicated section below. A fresh VM is highly recommended.
- A **Cloudflare account**. The free tier is sufficient.
- `git` and `curl` must be installed on the machine. You can usually install them with `sudo apt update && sudo apt install git curl` (Debian/Ubuntu) or `sudo yum install git curl` (RedHat/CentOS).

---

## 🚀 Installation (Linux & macOS)

The installation is automated via a single script. It will:
1.  Detect your OS and architecture.
2.  Download the correct binaries for `cloudflared` and `shell2http`.
3.  Install the binaries to `/usr/local/bin`.
4.  Create the `runner.sh` script in `/usr/local/etc/jules-endpoint-agent`.
5.  Set up a `systemd` (Linux) or `launchd` (macOS) service to run the endpoint persistently.
6.  Guide you through the final Cloudflare Tunnel configuration.

To start the installation, run the following command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/main/install.sh)"
```
*(Note: The URL above is a placeholder. The correct URL will be provided once the project is in a repository.)*

You will be prompted to set a username and password for Basic Authentication. Please choose a strong, unique password.

The script will then guide you through the **interactive Cloudflare setup**. This involves logging into your Cloudflare account in a browser and authorizing the tunnel.

Once complete, the script will display your public tunnel URL (e.g., `https://your-tunnel-name.trycloudflare.com`). **This is the URL you will provide to the AI agent.**

---

## 🪟 Instructions for Windows Users

The `install.sh` script is designed for Linux-based systems. For Windows users, the recommended approach is to use a Virtual Machine to run a lightweight Linux server. This provides the best security, isolation, and compatibility.

Here are the high-level steps:

1.  **Install Virtualization Software:** Download and install [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads), a free and popular virtualization tool.

2.  **Download a Linux ISO:** Download the server image for a stable Linux distribution. We recommend [Ubuntu Server LTS](https://ubuntu.com/download/server) because it's lightweight and widely supported.

3.  **Create and Install the Linux VM:**
    - Open VirtualBox and create a new virtual machine.
    - During setup, point the "virtual optical disk" to the Ubuntu Server ISO you downloaded.
    - Follow the on-screen instructions to install Ubuntu Server inside the VM. The default options are generally fine.
    - For detailed instructions, you can follow the official [Ubuntu Server installation guide](https://ubuntu.com/tutorials/install-ubuntu-server).

4.  **Configure VM Networking:**
    - After the VM is installed, open its **Settings** in VirtualBox.
    - Go to the **Network** tab.
    - Change the "Attached to" dropdown from "NAT" to **"Bridged Adapter"**. This will make your VM appear as a separate device on your local network, which simplifies a lot of networking issues.

5.  **Run the Installer inside the VM:**
    - Start your new Linux VM and log in.
    - You will be at a command-line terminal.
    - From here, you can run the standard installation command as described in the section above. You will likely need to install `curl` first:
      ```bash
      sudo apt update && sudo apt install curl git
      bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/main/install.sh)"
      ```

Your Jules Endpoint Agent will now be running inside the Linux VM, and the Cloudflare tunnel will securely expose it to the internet.

---

## 🔧 Configuration & Customization

- **Runner Script:** The core logic is in `/usr/local/etc/jules-endpoint-agent/runner.sh`. You can edit this file to change its behavior.
- **Service Management (Linux):**
    - `sudo systemctl start jules-endpoint`
    - `sudo systemctl stop jules-endpoint`
    - `sudo systemctl status jules-endpoint`
    - `sudo journalctl -u jules-endpoint -f` (to view logs)
- **Service Management (macOS):**
    - `sudo launchctl load /Library/LaunchDaemons/com.jules.endpoint.plist`
    - `sudo launchctl unload /Library/LaunchDaemons/com.jules.endpoint.plist`
- **Cloudflare Tunnel:** The tunnel configuration is located in your `~/.cloudflared` or `/etc/cloudflared` directory. You can manage it using the `cloudflared` command-line tool.

---

## 🗑️ Uninstallation

To remove the agent and its services, you can run the uninstallation script (this feature will be added to `install.sh`):

```bash
# Placeholder for uninstallation command
./install.sh --uninstall
```
