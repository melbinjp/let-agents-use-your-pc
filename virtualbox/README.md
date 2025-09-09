# Jules Endpoint Agent: Installation via VirtualBox

This directory provides documentation for running the Jules Endpoint Agent inside a Linux Virtual Machine (VM) on a Windows or macOS host.

This method is recommended for users who:
- Are on a Windows machine but want to provide a Linux environment for testing.
- Prefer the strong security and isolation of a full virtual machine over a native installation.
- Do not need the high-performance GPU access that the Docker method provides.

## File Descriptions

This directory contains documentation only. The actual installation will use the scripts from the `linux/` directory.

## Design Choices & Technical Details

### Why VirtualBox?
- **Full Isolation:** A VM provides a complete, separate operating system that is fully isolated from the host machine. This is an extremely strong security boundary.
- **Accessibility:** Oracle VirtualBox is a free, popular, and easy-to-use virtualization tool that runs on Windows, macOS, and Linux.
- **Simplicity:** By running a standard Linux distribution (like Ubuntu Server) in the VM, we can then use the well-supported native Linux installer, providing a stable and predictable environment for the agent.

### Acknowledging Limitations
- **Performance:** A full VM has more performance overhead than a container or a native installation.
- **GPU Access:** While technically possible, passing through a host GPU to a VirtualBox VM is complex and often inefficient. For tasks requiring hardware acceleration, the **Docker method is strongly recommended**.

## Installation Instructions

1.  **Install Virtualization Software:** Download and install [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads).

2.  **Download a Linux ISO:** We recommend [Ubuntu Server LTS](https://ubuntu.com/download/server) because it's lightweight and widely supported.

3.  **Create and Install the Linux VM:**
    - Open VirtualBox and create a new virtual machine.
    - During setup, point the "virtual optical disk" to the Ubuntu Server ISO you downloaded.
    - For detailed instructions, you can follow the official [Ubuntu Server installation guide](https://ubuntu.com/tutorials/install-ubuntu-server).

4.  **Configure VM Networking:**
    - After the VM is installed, open its **Settings** in VirtualBox.
    - Go to the **Network** tab.
    - Change the "Attached to" dropdown from "NAT" to **"Bridged Adapter"**. This makes your VM appear as a separate device on your local network and simplifies networking.

5.  **Run the Linux Installer inside the VM:**
    - Start your new Linux VM and log in.
    - You will be at a command-line terminal.
    - From inside the VM, follow the complete installation instructions in the `../linux/README.md` file, which includes cloning the repository and running the `install.sh` script.

Your Jules Endpoint Agent will now be running inside the isolated Linux VM.
