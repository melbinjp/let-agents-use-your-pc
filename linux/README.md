# Jules Endpoint Agent: Linux Installation

This directory contains the necessary scripts to install the Jules Endpoint Agent on a Linux machine. This method is recommended for users who want to provide a native Linux environment for building and testing projects.

## File Descriptions

- `install.sh`: The main installer script, written in Bash. It handles dependency checks, downloading binaries, and setting up `systemd` services for persistence.
- `runner.sh`: The execution script. This is a Bash script that is called by `shell2http` to clone a Git repository and run the provided command.

## Design Choices & Technical Details

### Why Bash and systemd?
- **Bash:** Bash is the de facto standard shell for scripting on nearly all Linux distributions, ensuring maximum compatibility.
- **systemd:** `systemd` is the standard init system and service manager for most modern Linux distributions (including Ubuntu, Debian, Fedora, CentOS, etc.). Using `systemd` is the most robust and conventional way to ensure the agent's services run automatically and are managed correctly by the OS.

### Security Considerations
- **Root Privileges:** The `install.sh` script requires `sudo` access to install binaries into `/usr/local/bin` and to create service files in `/etc/systemd/system`.
- **Credential Storage:** The agent's username and password are stored in a file at `/usr/local/etc/jules-endpoint-agent/credentials`. The installer sets the permissions of this file to `600` so that it is only readable by the root user, providing a reasonable level of security.

## Installation Instructions

### Prerequisites
- A modern Linux distribution that uses `systemd`.
- `git` and `curl` must be installed (`sudo apt install git curl` or `sudo yum install git curl`).

### Running the Installer
1. **Clone the Repository:** First, clone this repository to your local machine.
   ```bash
   git clone https://github.com/melbinjp/let-agents-use-your-pc.git
   ```
2. **Navigate to the Directory:** Open a terminal and navigate into the `linux` directory within the cloned repository.
   ```bash
   cd let-agents-use-your-pc/linux
   ```
3. **Run the Installer:** Run the `install.sh` script with `sudo`.
   ```bash
   sudo ./install.sh
   ```

The script will guide you through the rest of the process. Once complete, it will provide you with the public URL for your agent.
