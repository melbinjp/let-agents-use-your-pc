# Jules Endpoint Agent: Native Windows Installation (Temporarily Deprecated)

**This installation method has not yet been updated to the new SSH-based architecture.**

The previous HTTP-based installation method is no longer supported. Using the Docker-based installation is the recommended approach for running the agent on Windows.

We welcome contributions from the community to update this installer to align with the new SSH-based architecture outlined in the main `README.md`.

## To-Do for Re-enabling this Installer:

- Create a new `install.ps1` PowerShell script.
- The script should install and configure the built-in Windows OpenSSH Server and the `cloudflared` client (likely via Chocolatey or another package manager).
- It should follow the same pattern as the `linux/install.sh` script:
    - Create a dedicated local user for the agent.
    - Add the agent's public SSH key to the user's `authorized_keys` file (Windows has a specific way of handling this).
    - Configure and launch `cloudflared` as a Windows Service.
- Create a corresponding `uninstall.ps1` script.
