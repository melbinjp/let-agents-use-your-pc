#!/bin/bash
#
# jules-endpoint-agent: runner.sh
#
# This script is executed via SSH. It clones a Git repository
# and runs a command inside it.
#
# WARNING: This script uses `eval` to execute the command provided as the
# third argument. The endpoint is intended to be run in a sandboxed
# environment and accessed only by trusted agents like Jules.
#
# Usage:
#   ./runner.sh <repo_url> <branch_name> <command_to_run>
#
# Arguments:
#   - $1 (repo): The full URL of the git repository to clone.
#   - $2 (branch): The branch of the repository to check out.
#   - $3 (test_cmd): The shell command to execute in the repository root.

# --- Script Configuration ---

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipelines fail if any command fails, not just the last one.
set -o pipefail

# --- Pre-flight Checks ---

# Check that all required arguments are provided.
if [ "$#" -ne 3 ]; then
  echo "[ERROR] Invalid number of arguments." >&2
  echo "[ERROR] Usage: $0 <repo_url> <branch_name> <command_to_run>" >&2
  exit 1
fi

# Assign arguments to variables for clarity.
repo_url="$1"
branch_name="$2"
test_cmd="$3"


# --- Execution ---

# Create a temporary directory for the test run.
# mktemp creates a unique directory to avoid collisions.
TMP_DIR=$(mktemp -d /tmp/jules-run-XXXXXX)

# Set a trap to clean up the temporary directory on script exit.
# This ensures that even if the script fails, the temp files are removed.
trap 'echo "[INFO] Cleaning up temporary directory..."; rm -rf -- "$TMP_DIR"' EXIT

echo "[INFO] Created temporary directory at: $TMP_DIR"
cd "$TMP_DIR"

echo "[INFO] Cloning repository: $repo_url (branch: $branch_name)"
# Clone a specific branch with a depth of 1 for efficiency.
git clone --depth 1 -b "$branch_name" "$repo_url" "repo"
cd "repo"

echo "[INFO] Repository cloned. Current working directory: $(pwd)"
echo "[INFO] ---"
echo "[INFO] Executing command: $test_cmd"
echo "[INFO] ---"

# Execute the provided command.
# The output of this command will be the main body of the HTTP response.
eval "$test_cmd"

echo "[INFO] ---"
echo "[INFO] Command finished with exit code $?."
