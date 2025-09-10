#!/bin/bash
#
# jules-endpoint-agent: runner.sh
#
# This script is executed by shell2http. It clones a Git repository
# and runs a command inside it.
#
# WARNING: This script uses `eval` to execute the command provided in the
# `test_cmd` variable. The endpoint is intended to be run in a sandboxed
# environment and accessed only by trusted agents like Jules. Exposing this
# endpoint to the public internet without a strong authentication layer is
# extremely dangerous.
#
# Environment Variables (provided by shell2http via POST data):
#   - repo: The full URL of the git repository to clone.
#   - branch: The branch of the repository to check out.
#   - test_cmd: The shell command to execute in the repository root.

# --- Script Configuration ---

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipelines fail if any command fails, not just the last one.
set -o pipefail

# --- Pre-flight Checks ---

# Check that all required environment variables are set.
if [ -z "${repo:-}" ] || [ -z "${branch:-}" ] || [ -z "${test_cmd:-}" ]; then
  echo "[ERROR] Missing required environment variables." >&2
  echo "[ERROR] Please provide 'repo', 'branch', and 'test_cmd' in the POST data." >&2
  exit 1
fi

# --- Execution ---

# Create a temporary directory for the test run.
# mktemp creates a unique directory to avoid collisions.
TMP_DIR=$(mktemp -d /tmp/jules-run-XXXXXX)

# Set a trap to clean up the temporary directory on script exit.
# This ensures that even if the script fails, the temp files are removed.
trap 'echo "[INFO] Cleaning up temporary directory..."; rm -rf -- "$TMP_DIR"' EXIT

echo "[INFO] Created temporary directory at: $TMP_DIR"
cd "$TMP_DIR"

echo "[INFO] Cloning repository: $repo (branch: $branch)"
# Clone a specific branch with a depth of 1 for efficiency.
git clone --depth 1 -b "$branch" "$repo" "repo"
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
