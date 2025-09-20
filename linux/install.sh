#!/bin/bash

# jules-endpoint-agent: install.sh
#
# This script automates the setup of the Jules Endpoint Agent on Linux.
# It installs cloudflared, and configures it to provide secure,
# remote SSH access via a Cloudflare Tunnel.

# --- Configuration ---
# Exit on any error, treat unset variables as errors, and fail pipelines on first error.
set -euo pipefail

# --- Constants ---
# Allow overriding install directories for testing purposes.
PREFIX="${PREFIX:-/usr/local}"
AGENT_CONFIG_DIR="${AGENT_CONFIG_DIR:-$PREFIX/etc/jules-endpoint-agent}"
AGENT_RUNNER_SCRIPT="$AGENT_CONFIG_DIR/runner.sh"
CLOUDFLARED_BIN_PATH="$PREFIX/bin/cloudflared"
CLOUDFLARED_CONFIG_DIR="${CLOUDFLARED_CONFIG_DIR:-/etc/cloudflared}"

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
    # In tests, this will return, allowing status checks.
    # In direct execution, the script will exit due to `set -e`.
    return 1
}

# --- Core Logic Functions ---

preflight_checks() {
    info "Running pre-flight checks..."
    [ "$(id -u)" -eq 0 ] || { error "This script must be run with sudo or as root."; return 1; }
    command -v curl &>/dev/null || { error "'curl' is required. Please install it."; return 1; }
    command -v git &>/dev/null || { error "'git' is required. Please install it."; return 1; }
    systemctl is-active --quiet ssh || { error "SSH server (sshd) is not running. Please start it."; return 1; }
    info "Pre-flight checks passed."
}

detect_os_arch() {
    local os
    local arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64 | arm64) arch="arm64" ;;
        *) error "Unsupported architecture: $arch"; return 1 ;;
    esac
    echo "$os-$arch"
}

install_cloudflared() {
    local os_arch=$1
    info "Downloading and installing cloudflared for $os_arch..."
    local cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-$os_arch"
    curl -sL -o "$CLOUDFLARED_BIN_PATH" "$cf_url"
    chmod +x "$CLOUDFLARED_BIN_PATH"
    info "cloudflared installed successfully."
}

setup_runner_script() {
    # Get the directory of the currently executing script.
    local script_dir
    SOURCE=${BASH_SOURCE[0]}
    while [ -h "$SOURCE" ]; do
      DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
      SOURCE=$(readlink "$SOURCE")
      [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
    done
    script_dir=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

    local runner_source_path="$script_dir/../common/runner.sh"

    info "Creating configuration directory: $AGENT_CONFIG_DIR"
    mkdir -p "$AGENT_CONFIG_DIR"
    info "Installing runner script from $runner_source_path"
    cp "$runner_source_path" "$AGENT_RUNNER_SCRIPT"
    chmod +x "$AGENT_RUNNER_SCRIPT"
}

configure_tunnel() {
    info "--- Cloudflare Tunnel Setup ---"
    read -p "A browser window will open to log you into Cloudflare. Press Enter to continue..."
    cloudflared tunnel login

    local tunnel_name="jules-ssh-endpoint-$(openssl rand -hex 4)"
    info "Creating a new tunnel named: $tunnel_name"

    local tunnel_uuid
    if ! tunnel_uuid=$(cloudflared tunnel create "$tunnel_name"); then
        error "Failed to create Cloudflare tunnel."
    fi

    info "Configuring tunnel to point to local SSH service..."
    mkdir -p "$CLOUDFLARED_CONFIG_DIR"

    local cred_home
    if [ -n "${SUDO_USER:-}" ]; then
        cred_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        cred_home=$HOME
    fi

    cat > "$CLOUDFLARED_CONFIG_DIR/config.yml" << EOF
tunnel: $tunnel_uuid
credentials-file: ${cred_home}/.cloudflared/${tunnel_uuid}.json

ingress:
  - hostname: ${tunnel_name}.trycloudflare.com
    service: ssh://localhost:22
  - service: http_status:404
EOF
    echo "$tunnel_name"
}

install_service() {
    info "Installing cloudflared as a systemd service..."
    cloudflared service install
    systemctl start cloudflared
    info "cloudflared service started."
}

# --- Main Execution ---
main() {
    info "Welcome to the Jules Endpoint Agent installer for SSH."
    warn "Please review security warnings in the README.md before proceeding."

    preflight_checks

    local os_arch
    os_arch=$(detect_os_arch)
    info "Detected OS-Architecture: $os_arch"

    tmp_dir=$(mktemp -d)
    trap 'rm -rf -- "$tmp_dir"' EXIT
    cd "$tmp_dir"

    install_cloudflared "$os_arch"
    setup_runner_script

    local tunnel_name
    tunnel_name=$(configure_tunnel)

    install_service

    info "--- SETUP COMPLETE ---"
    warn "Your SSH endpoint is: ssh -p 22 <YOUR_USER>@$tunnel_name.trycloudflare.com"
    info "Add the agent's public SSH key to your ~/.ssh/authorized_keys file to allow access."
}

# Execute main function only if the script is run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
