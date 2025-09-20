#!/bin/bash

# tests/test_linux_installer_integration.sh
#
# High-level integration test for the Linux installer. This script executes the
# installer in a sandboxed environment with mocked external dependencies.

set -e # Exit immediately if a command fails.
set -o pipefail # Fail a pipe if any command in it fails.

echo "--- Starting Linux Installer Integration Test ---"

# --- Test Setup ---
# Create a temporary root directory for the installation.
TMP_DIR=$(mktemp -d)
# Ensure cleanup happens on script exit.
trap 'echo "--- Cleaning up temporary directory ---"; rm -rf "$TMP_DIR"' EXIT

# Define environment variables to override installation paths.
export PREFIX="$TMP_DIR/usr/local"
export AGENT_CONFIG_DIR="$PREFIX/etc/jules-endpoint-agent"
export CLOUDFLARED_CONFIG_DIR="$PREFIX/etc/cloudflared"

# Create a directory for mock binaries.
MOCK_BIN_DIR="$TMP_DIR/bin"
export PATH="$MOCK_BIN_DIR:$PATH"

mkdir -p "$PREFIX/bin"
mkdir -p "$AGENT_CONFIG_DIR"
mkdir -p "$CLOUDFLARED_CONFIG_DIR"
mkdir -p "$MOCK_BIN_DIR"

COMMAND_LOG="$TMP_DIR/commands.log"
touch "$COMMAND_LOG"

# --- Mock Dependencies ---
# Mock external commands to avoid network calls and system changes.
mock_command() {
    local cmd_name=$1
    shift
    printf '#!/bin/bash\n# Mock for %s\necho "[%s] $@" >> "%s"\n%s' "$cmd_name" "$cmd_name" "$COMMAND_LOG" "$@" > "$MOCK_BIN_DIR/$cmd_name"
    chmod +x "$MOCK_BIN_DIR/$cmd_name"
}

mock_command "cloudflared" '
if [ "$1" = "tunnel" ] && [ "$2" = "create" ]; then
    echo "mock-tunnel-uuid-1234"
fi
'
mock_command "systemctl" "exit 0"
mock_command "openssl" "echo 'mock-random-hex-string'"
mock_command "getent" "echo '/home/mockuser:x:1000:1000::/home/mockuser:/bin/bash'"
mock_command "id" "echo 0"
mock_command "curl" 'touch "$3"' # The -o file is the 3rd arg
mock_command "git"
mock_command "cp" "command cp \"\$@\"" # Use real cp
mock_command "mkdir" "command mkdir -p \"\$@\"" # Use real mkdir

# --- Execute Installer ---
INSTALLER_SCRIPT="$(dirname "$0")/../linux/install.sh"
echo "--- Running installer script: $INSTALLER_SCRIPT ---"

# The installer script requires a real runner.sh to copy.
COMMON_DIR="$(dirname "$0")/../common"
mkdir -p "$COMMON_DIR"
touch "$COMMON_DIR/runner.sh"

# Use a heredoc to provide automated input to the 'read' command.
"$INSTALLER_SCRIPT" <<EOF
y
EOF

echo "--- Installer script finished. Verifying results... ---"

# --- Assertions ---
# 1. Verify cloudflared was "downloaded".
echo "Asserting cloudflared download..."
grep -q "\[curl\] -sL -o $PREFIX/bin/cloudflared" "$COMMAND_LOG"
echo "[PASS] cloudflared download command was logged."

# 2. Verify runner.sh was copied.
echo "Asserting runner script installation..."
RUNNER_SCRIPT_PATH="$AGENT_CONFIG_DIR/runner.sh"
[ -f "$RUNNER_SCRIPT_PATH" ] || { echo "[FAIL] runner.sh not found at $RUNNER_SCRIPT_PATH"; exit 1; }
echo "[PASS] runner.sh exists at the correct location."

# 3. Verify cloudflared config.yml was created and has correct content.
echo "Asserting cloudflared config.yml..."
CONFIG_YML_PATH="$CLOUDFLARED_CONFIG_DIR/config.yml"
[ -f "$CONFIG_YML_PATH" ] || { echo "[FAIL] config.yml not found at $CONFIG_YML_PATH"; exit 1; }
echo "[PASS] config.yml exists."

# Check for tunnel UUID and credentials file path.
grep -q "tunnel: mock-tunnel-uuid-1234" "$CONFIG_YML_PATH"
echo "[PASS] config.yml contains the correct tunnel UUID."
grep -q "credentials-file: /home/mockuser/.cloudflared/mock-tunnel-uuid-1234.json" "$CONFIG_YML_PATH"
echo "[PASS] config.yml contains the correct credentials file path."

# 4. Verify cloudflared service was installed.
echo "Asserting cloudflared service installation..."
grep -q "\[cloudflared\] service install" "$COMMAND_LOG"
echo "[PASS] 'cloudflared service install' was called."
grep -q "\[systemctl\] start cloudflared" "$COMMAND_LOG"
echo "[PASS] 'systemctl start cloudflared' was called."

# --- Test Success ---
echo "---"
echo "🟢 All integration tests passed successfully! ---"

# Cleanup the dummy runner.sh
rm "$COMMON_DIR/runner.sh"
