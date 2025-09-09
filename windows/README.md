# Jules Endpoint Agent: Native Windows Installation

This directory contains the necessary scripts to install the Jules Endpoint Agent directly onto a Windows machine. This method is recommended for users who need to give the agent the ability to run tests or builds in a native Windows environment (e.g., for .NET Framework applications, Windows-specific tools, or PowerShell scripting).

## File Descriptions

- `install.ps1`: This is the main installer script. It is written in PowerShell and automates the entire setup process.
- `runner.ps1`: This is the execution script. It is called by the agent's web server (`shell2http`) and is responsible for cloning a Git repository and running the user-provided command within it.

## Design Choices & Technical Details

### Why PowerShell?
PowerShell is the modern, standard scripting language for Windows administration. It provides the necessary cmdlets to manage system services (`New-Service`), handle files, and interact with the operating system in a robust way, making it the natural choice for the installer.

### Security Considerations
- **Administrator Privileges:** The `install.ps1` script requires administrative privileges to create system services and write to the `C:\Program Files` directory.
- **Password Handling:** During service creation, the password you provide for the agent is passed as a plain-text argument to the service definition. This is a known limitation and a security trade-off for simplicity.
  - **HELP WANTED:** We are actively looking for a more secure way to handle this. If you are a Windows security expert, we would welcome a contribution to improve this!

## Installation Instructions

### Prerequisites
- Windows 10/11 or Windows Server 2016 or newer.
- [Git for Windows](https://git-scm.com/download/win) must be installed.
- PowerShell 5.1 or newer (comes standard with modern Windows).

### Running the Installer
1. **Clone the Repository:** First, clone this repository to your local machine.
   ```powershell
   git clone https://github.com/your-repo/jules-endpoint-agent.git
   ```
2. **Navigate to the Directory:** Open a PowerShell terminal and navigate into the `windows` directory within the cloned repository.
   ```powershell
   cd jules-endpoint-agent/windows
   ```
3. **Run the Installer:** Run the `install.ps1` script from this directory. You must run it from an **elevated (Administrator)** PowerShell terminal.
   ```powershell
   .\install.ps1
   ```

The script will guide you through the rest of the process, including authenticating with Cloudflare. Once complete, it will provide you with the public URL for your agent.
