# Jules Endpoint Agent

Welcome to the Jules Endpoint Agent! This project provides a set of scripts and tools to turn any machine into a secure, remotely-accessible execution endpoint for an AI agent like Jules. This allows an agent to perform development tasks like cloning repositories, running tests, and executing builds in a real, high-performance environment.

This repository contains several methods for installing the agent, each tailored to a specific need or operating system.

---

## 🛑 Security Warning

**This is extremely important.** By installing this agent, you are creating a bridge between the public internet and a shell on your machine. The runner scripts are designed to execute arbitrary commands sent to them.

**Please follow these security best practices:**
- **Run this on a dedicated, sandboxed machine or VM.** Do not run it on your primary personal or work machine.
- **Always use the secure Cloudflare tunnel.** Never expose any ports directly.
- **Review the installation scripts before running them** to understand what they do.

---

## 🚀 Getting Started: Choose Your Installation Path

Please choose the installation method that best fits your operating system and use case. Each directory contains a detailed `README.md` file with specific instructions.

### 🐧 For Native Linux Environments
- **Go to: [`./linux/`](./linux/)**
- Use this method to install the agent directly on a modern Linux distribution (e.g., Ubuntu, Debian, Fedora, CentOS).

### 🍏 For Native macOS Environments
- **Go to: [`./macos/`](./macos/)**
- Use this method to install the agent directly on a macOS machine, ideal for testing Apple-specific projects.

### 💻 For Native Windows Environments
- **Go to: [`./windows/`](./windows/)**
- Use this method to install the agent directly on Windows, ideal for testing Windows-native projects.

### 🐳 For Docker Environments (High-Performance & Isolated)
- **Go to: [`./docker/`](./docker/)**
- **This is the recommended method for most users on any OS** who want a secure, isolated, and high-performance Linux environment. It is the best option for tasks that require **GPU acceleration**.

### 📦 For VirtualBox Environments (Legacy or High-Isolation)
- **Go to: [`./virtualbox/`](./virtualbox/)**
- Use this method if you are on Windows or macOS and prefer the high-isolation of a full Linux VM over the native or Docker installations.

---

## 🤝 Contributing

We welcome contributions from the community! Whether it's reporting a bug, suggesting a feature, or submitting code changes, your help is greatly appreciated.

- **[Contribution Guidelines](./CONTRIBUTING.md):** Learn how to submit issues and pull requests.
- **[Manual Testing Guide](./TESTING.md):** Find out how to test your changes before submitting.
