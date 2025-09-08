# Jules Endpoint Agent

Welcome to the Jules Endpoint Agent! This project provides a set of scripts to turn any Windows, macOS, or Linux machine into a secure, remotely-accessible execution endpoint. An AI agent like Jules can then use this endpoint to perform tasks like cloning repositories, running tests, and executing build commands in a real development environment.

This is ideal for giving an AI agent access to more powerful hardware, specific development tools, or a persistent environment that survives beyond a single session.

---

## 🛑 Security Warning

**This is extremely important.** By installing this agent, you are creating a bridge between the public internet and a shell on your machine. The runner scripts (`runner.sh` and `runner.ps1`) are designed to execute arbitrary commands sent to them.

While we use a secure tunnel (`cloudflared`) and recommend authentication, this setup grants significant control to the connecting agent.

**Please follow these security best practices:**
- **Run this on a dedicated, sandboxed virtual machine (VM).** Do not run it on your primary personal or work machine.
- **Never expose the `shell2http` port directly.** Only access it through the secure Cloudflare tunnel.
- **Use the strongest authentication method you can.** The default installation will guide you to set up a username and password.
- **Review the installation scripts before running them** to understand what they do.

---

## ⚙️ How It Works

The system is built on two key open-source tools:

1.  **[Cloudflared](https://github.com/cloudflare/cloudflared):** Creates a secure, persistent tunnel from your machine to the Cloudflare network. This means you don't need to configure firewalls, port forwarding, or deal with dynamic IP addresses. You get a stable, public HTTPS URL.
2.  **[shell2http](https://github.com/msoap/shell2http):** A simple web server that executes a shell script (`runner.sh` or `runner.ps1`) whenever it receives an HTTP request.

The flow is as follows:
`Jules -> HTTPS Request -> Cloudflare Tunnel -> cloudflared (on your machine) -> shell2http -> Runner Script`

---

## 🚀 Installation

This project uses platform-specific installation scripts to automate the setup. Please choose the instructions for your operating system.

### 💻 Installation (Native Windows)

This method installs the agent directly on Windows, allowing it to run Windows-native commands.

**Prerequisites:**
- Windows 10/11 or Windows Server 2016 or newer.
- [Git for Windows](https://git-scm.com/download/win) must be installed.
- PowerShell 5.1 or newer (comes standard with modern Windows).

**Instructions:**
1. Open **PowerShell as an Administrator**.
2. Run the following command to download and execute the installer. This will set up all necessary files and Windows services.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/your-repo/main/install.ps1'))
```
*(Note: The URL above is a placeholder. The correct URL will be provided once the project is in a repository.)*

### 🐧 🍏 Installation (Linux & macOS)

This method installs the agent on Linux or macOS systems.

**Prerequisites:**
- A Linux or macOS machine.
- `git` and `curl` must be installed.

**Instructions:**
1. Open your terminal.
2. Run the following command. The script requires `sudo` privileges to install files and set up the system service.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/main/install.sh)"
```
*(Note: The URL above is a placeholder.)*

### 🪟 Installation (Windows via Linux VM)

This is an alternative for Windows users who prefer to run the agent in an isolated Linux environment.

1.  **Install Virtualization Software:** Download and install [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads).
2.  **Download a Linux ISO:** We recommend [Ubuntu Server LTS](https://ubuntu.com/download/server).
3.  **Create and Install the Linux VM:** Follow the on-screen instructions in VirtualBox to create and install a new Ubuntu VM.
4.  **Configure VM Networking:** In the VM's Network settings, change "Attached to" to **"Bridged Adapter"**.
5.  **Run the Linux Installer:** Start the VM, log in, and run the Linux/macOS installation command provided above.

---

## 🔧 Configuration & Customization

The installation scripts handle the configuration automatically. The core logic for the agent is in the `runner` script located in the installation directory. You can edit this file to change its behavior.

- **Windows:** `C:\Program Files\JulesEndpointAgent\runner.ps1`
- **Linux/macOS:** `/usr/local/etc/jules-endpoint-agent/runner.sh`

Service management commands can be found in the output of the installation scripts.

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's reporting a bug, suggesting a feature, or submitting code changes, your help is greatly appreciated.

- **[Contribution Guidelines](./CONTRIBUTING.md):** Learn how to submit issues and pull requests.
- **[Manual Testing Guide](./TESTING.md):** Find out how to test your changes before submitting.

---

## 🗑️ Uninstallation

An uninstallation feature will be added in a future update. For now, you will need to manually stop and delete the system services and remove the installation directory.
