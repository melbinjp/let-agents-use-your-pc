#!/bin/bash

# tests/test_installers.sh
#
# This test script verifies that the native installation scripts (Linux, macOS)
# are configured correctly and do not contain legacy or insecure components.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Test Configuration ---
INSTALL_SCRIPTS=("linux/install.sh" "macos/install.sh" "windows/install.ps1")
FAIL=0

# --- Helper Functions ---
assert_not_contains() {
    local file=$1
    local pattern=$2
    local message=$3

    if grep -q "$pattern" "$file"; then
        echo "[FAIL] $file: $message"
        FAIL=1
    else
        echo "[PASS] $file: OK"
    fi
}

# --- Test Cases ---

echo "--- Running Installer Sanity Checks ---"

for script in "${INSTALL_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "[FAIL] $script: Installer script not found!"
        FAIL=1
        continue
    fi

    echo "Checking $script..."

    # Test Case 1: Ensure shell2http is not used.
    assert_not_contains "$script" "shell2http" "Should not reference or install shell2http."

    # Test Case 2: Ensure the Cloudflare service is not configured for HTTP.
    assert_not_contains "$script" "service: http://localhost" "Cloudflare ingress should be configured for SSH, not HTTP."

    # Test Case 3: Ensure credentials path is not hardcoded to a root-specific directory.
    if [[ "$script" == "linux/install.sh" ]]; then
        assert_not_contains "$script" "credentials-file: /root/.cloudflared" "Credentials path should not be hardcoded to /root."
    elif [[ "$script" == "macos/install.sh" ]]; then
        assert_not_contains "$script" "credentials-file: /var/root/.cloudflared" "Credentials path should not be hardcoded to /var/root."
    fi

    # Test Case 4: Ensure the credentials file path in config.yml uses the invoking user's home directory.
    if [[ "$script" == "linux/install.sh" ]]; then
        assert_not_contains "$script" "credentials-file: \$HOME/.cloudflared" "Credentials path in config.yml should use the invoking user's home directory, not the root's."
    fi
done

echo "---"

# --- Final Verdict ---
if [ "$FAIL" -eq 1 ]; then
    echo "🔴 One or more tests failed."
    exit 1
else
    echo "🟢 All tests passed."
    exit 0
fi
