# Agent Usage Guide

This document provides the technical specification for interacting with a Jules Endpoint Agent. The agent uses a Cloudflare Tunnel to provide secure SSH access for executing remote commands.

---

## Endpoint and Authentication

The user who set up the agent will provide you with a unique SSH endpoint URL. This will look something like this:

`ssh your_user@your-tunnel-name.trycloudflare.com`

Authentication is handled by standard SSH key-based authentication. You must provide your public SSH key to the user who manages the agent. They will add it to the `~/.ssh/authorized_keys` file on the endpoint machine.

---

## API: Execute Command via SSH

The primary way to interact with the agent is by executing the `runner.sh` script remotely via SSH. The script accepts the repository URL, branch name, and the command to run as command-line arguments.

### Command Structure

```bash
ssh <your_endpoint> -- /usr/local/etc/jules-endpoint-agent/runner.sh <repo_url> <branch> "<command>"
```

-   **`<your_endpoint>`**: The full SSH endpoint URL (e.g., `your_user@your-tunnel-name.trycloudflare.com`).
-   **`--`**: This is important. It tells SSH that the arguments after it are for the command, not for SSH itself.
-   **`/usr/local/etc/jules-endpoint-agent/runner.sh`**: The full path to the runner script on the remote machine. This is the default path set by the installer.
-   **`<repo_url>`**: The full HTTPS URL of the Git repository to clone.
-   **`<branch>`**: The branch, tag, or commit hash to check out.
-   **`<command>`**: The shell command to be executed. It **must be quoted** to be treated as a single argument.

### Example Request

Here is a complete example to clone the official Git repository and run `make test`.

```bash
ssh your_user@jules-ssh-endpoint-a1b2c3d4.trycloudflare.com -- \
  /usr/local/etc/jules-endpoint-agent/runner.sh \
  "https://github.com/git/git.git" \
  "master" \
  "make test"
```

---

## Response

### On Success

If the command executes successfully (exits with 0), the SSH session will also exit with a status code of 0. The combined `stdout` and `stderr` from the `runner.sh` script and your command will be streamed to your terminal.

```
[INFO] Created temporary directory at: /tmp/jules-run-aBcDeF
[INFO] Cloning repository: https://github.com/git/git.git (branch: master)
... (git clone output) ...
[INFO] Repository cloned. Current working directory: /tmp/jules-run-aBcDeF/repo
[INFO] ---
[INFO] Executing command: make test
[INFO] ---
... (output of 'make test') ...
[INFO] ---
[INFO] Command finished with exit code 0.
[INFO] Cleaning up temporary directory...
```

### On Failure

If the `runner.sh` script or your command fails (exits with a non-zero status code), the SSH session will terminate with the same non-zero exit code. This is the primary way to programmatically detect a failure. The output will still be streamed, allowing you to debug the error.

### On Request Error

If you provide an incorrect number of arguments to `runner.sh`, it will print an error to `stderr`, exit with status 1, and the SSH session will terminate.

```
[ERROR] Invalid number of arguments.
[ERROR] Usage: /usr/local/etc/jules-endpoint-agent/runner.sh <repo_url> <branch_name> <command_to_run>
```
