# Jules Endpoint Agent (SSH Edition)

Welcome to the Jules Endpoint Agent! This project provides a set of scripts and tools to turn any machine into a secure, remotely-accessible SSH endpoint for an AI agent like Jules. This allows an agent to perform development tasks like cloning repositories, running tests, and executing builds in a real, high-performance environment.

This repository contains several methods for installing the agent, each tailored to a specific need or operating system. The new architecture is based on SSH for enhanced security and compatibility.

---

## 🛑 Security Warning

**This is extremely important.** By installing this agent, you are creating a bridge between the public internet and an SSH shell on your machine.

**Please follow these security best practices:**
- **Run this on a dedicated, sandboxed machine or VM.** Do not run it on your primary personal or work machine.
- **Always use the secure Cloudflare tunnel.** The scripts are designed to do this automatically. Never expose the SSH port directly.
- **Use a unique SSH key for the agent** and protect the private key.

---

## 🚀 Getting Started: Choose Your Installation Path

Please choose the installation method that best fits your operating system and use case. Each directory contains a detailed `README.md` file with specific instructions.

### 🐳 For Docker Environments (Recommended)
- **Go to: [`./docker/`](./docker/)**
- **This is the recommended method for most users on any OS** who want a secure, isolated, and high-performance Linux environment. It is the best option for tasks that require **GPU acceleration**.

### 🐧 For Native Linux Environments
- **Go to: [`./linux/`](./linux/)**
- Use this method to install the agent directly on a modern Debian-based Linux distribution (e.g., Ubuntu, Debian).

### 🍏 For Native macOS Environments (Temporarily Deprecated)
- **Go to: [`./macos/`](./macos/)**
- The installer for macOS has not yet been updated to the new SSH-based architecture. Contributions are welcome!

### 💻 For Native Windows Environments (Temporarily Deprecated)
- **Go to: [`./windows/`](./windows/)**
- The installer for Windows has not yet been updated to the new SSH-based architecture. Contributions are welcome!

### 📦 For VirtualBox Environments (Legacy / Deprecated)
- **Go to: [`./virtualbox/`](./virtualbox/)**
- This installation method is considered legacy and has been deprecated in favor of the more modern Docker-based approach.

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's updating an installer for your favorite OS, improving documentation, or submitting a feature, your help is greatly appreciated.

- **[Contribution Guidelines](./CONTRIBUTING.md):** Learn how to submit issues and pull requests.
- **[Manual Testing Guide](./TESTING.md):** Find out how to test your changes before submitting.
