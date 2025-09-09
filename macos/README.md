# Jules Endpoint Agent: macOS Installation

This directory contains the necessary scripts to install the Jules Endpoint Agent on a macOS machine. This method is recommended for users who need to provide a native macOS environment for building and testing projects (e.g., for iOS or macOS applications).

## File Descriptions

- `install.sh`: The main installer script, written in Bash. It handles dependency checks, downloading binaries, and setting up `launchd` services for persistence.
- `runner.sh`: The execution script. This is a Bash script that is called by `shell2http` to clone a Git repository and run the provided command.

## Design Choices & Technical Details

### Why Bash and launchd?
- **Bash:** Bash is a standard shell available on macOS, ensuring the scripts run correctly.
- **launchd:** `launchd` is the standard system for managing services and daemons on macOS. Using a `launchd` plist file is the correct, native way to ensure the agent's services run automatically and are managed by the OS.

### Security Considerations
- **Root Privileges:** The `install.sh` script requires `sudo` access to install binaries into `/usr/local/bin` and to create the `launchd` plist file in `/Library/LaunchDaemons`.
- **Credential Storage:** On macOS, the agent's username and password are included directly in the `/Library/LaunchDaemons/com.jules.endpoint.plist` file. This file is protected by system permissions and only readable by the root user, but this is a known platform-specific trade-off.

## Installation Instructions

### Prerequisites
- A macOS machine.
- `git` and `curl` must be installed. They are typically available by default, or can be installed with the Xcode Command Line Tools.

### Running the Installer
1. **Clone the Repository:** First, clone this repository to your local machine.
   ```bash
   git clone https://github.com/your-repo/jules-endpoint-agent.git
   ```
2. **Navigate to the Directory:** Open a terminal and navigate into the `macos` directory within the cloned repository.
   ```bash
   cd jules-endpoint-agent/macos
   ```
3. **Run the Installer:** Run the `install.sh` script with `sudo`.
   ```bash
   sudo ./install.sh
   ```

The script will guide you through the rest of the process. Once complete, it will provide you with the public URL for your agent.
