# Contributing to the Jules Endpoint Agent

First off, thank you for considering contributing! This project thrives on community involvement, and every contribution, from a typo fix to a new feature, is appreciated.

This document provides guidelines for contributing to the project.

## How to Contribute

There are many ways to contribute, and all are welcome:

- **Reporting Bugs:** If you find a bug, please open an issue on our GitHub repository.
- **Suggesting Enhancements:** Have an idea for a new feature or an improvement to an existing one? Open an issue to start a discussion.
- **Improving Documentation:** If you see an area where the documentation could be clearer or more complete, please feel free to submit a pull request.
- **Submitting Pull Requests:** If you want to fix a bug or implement a new feature, please follow the workflow below.

### Reporting Bugs

When reporting a bug, please include the following:
- The operating system you were using (e.g., Windows 11, Ubuntu 22.04, macOS 13).
- The exact command you ran.
- The full output of the script, including any error messages.
- A clear description of what you expected to happen and what actually happened.

### Pull Request Workflow

1.  **Fork the repository** to your own GitHub account.
2.  **Create a new branch** for your changes (e.g., `feat/add-new-feature` or `fix/resolve-bug-123`).
3.  **Make your changes** in your new branch.
4.  **Test your changes** thoroughly by following the manual testing guide in `TESTING.md`. Please test on the OS you are developing for.
5.  **Commit your changes** with a clear and descriptive commit message.
6.  **Push your branch** to your fork on GitHub.
7.  **Open a pull request** from your branch to the `main` branch of the original repository. In the pull request description, please explain the changes you made and reference any related issues.

## Development Setup

To test your changes, you will need a machine (or a VM) running the operating system you are targeting (Windows, Linux, or macOS).

The core components are:
- `shell2http`: The web server. The installation scripts download this automatically.
- `cloudflared`: The tunneling software. Also downloaded by the installers.
- **Runner Scripts** (`runner.sh`, `runner.ps1`): These are the heart of the agent.
- **Installer Scripts** (`install.sh`, `install.ps1`): These are used to set up the entire system.

When you make a change to an installer or runner script, you can test it by running the modified installer on a clean test machine/VM.

## Coding Style

To keep the codebase consistent and readable, please follow these simple guidelines:

### Shell Scripts (`.sh`)
- Use `set -euo pipefail` for robustness.
- Use 2 spaces for indentation.
- Write clear and concise comments to explain complex parts of the code.
- Use `[INFO]`, `[WARN]`, and `[ERROR]` prefixes for log messages.

### PowerShell Scripts (`.ps1`)
- Use `$ErrorActionPreference = 'Stop'` at the beginning of scripts.
- Use 4 spaces for indentation.
- Use PowerShell's standard `Verb-Noun` naming convention for functions (e.g., `Write-Info`).
- Write clear and concise comments to explain complex parts of the code.

Thank you again for your interest in contributing!
