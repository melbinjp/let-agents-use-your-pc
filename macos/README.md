# Jules Endpoint Agent: Native macOS Installation (Temporarily Deprecated)

**This installation method has not yet been updated to the new SSH-based architecture.**

The previous HTTP-based installation method is no longer supported. Using the Docker-based installation is the recommended approach for running the agent on macOS.

We welcome contributions from the community to update this installer to align with the new SSH-based architecture outlined in the main `README.md`.

## To-Do for Re-enabling this Installer:

- Create a new `install.sh` script for macOS.
- The script should install `openssh-server` (if not already present and configured) and `cloudflared` (likely via Homebrew).
- It should follow the same pattern as the `linux/install.sh` script:
    - Create a dedicated agent user.
    - Prompt for a public SSH key.
    - Configure and launch `cloudflared` as a service (`launchd`).
- Create a corresponding `uninstall.sh` script.
