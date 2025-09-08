#!/bin/bash

# jules-endpoint-agent: install.sh
#
# This script automates the setup of the Jules Endpoint Agent.
# It installs shell2http and cloudflared, configures them to run as
# services, and guides the user through the final setup steps.

# --- Configuration ---
# Exit on any error, treat unset variables as errors, and fail pipelines on first error.
set -euo pipefail

# --- Constants ---
SHELL2HTTP_VERSION="1.17.0"
AGENT_CONFIG_DIR="/usr/local/etc/jules-endpoint-agent"
AGENT_RUNNER_SCRIPT="$AGENT_CONFIG_DIR/runner.sh"
AGENT_CRED_FILE="$AGENT_CONFIG_DIR/credentials"
SERVICE_NAME="jules-endpoint"
PORT="8080" # Local port for shell2http

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script ---

# TODO / HELP WANTED: Implement uninstallation logic.
# This script should accept an `--uninstall` flag that performs the following actions:
# - Stop and disable the 'jules-endpoint' and 'cloudflared' services.
# - Delete the service files.
# - Delete the installation directory ('/usr/local/etc/jules-endpoint-agent').
# - Delete the binaries ('/usr/local/bin/shell2http', '/usr/local/bin/cloudflared').
# - Delete the Cloudflare tunnel.

# 1. Welcome and Pre-flight Checks
info "Welcome to the Jules Endpoint Agent installer."
info "This script will set up your machine as a remote execution endpoint."
warn "Please review the security warnings in the README.md before proceeding."
echo

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo or as root. Please run as: sudo $0"
fi

# Check for dependencies
if ! command -v curl &> /dev/null || ! command -v git &> /dev/null; then
    error "Both 'curl' and 'git' are required. Please install them and re-run this script."
fi

# 2. Gather User Input for Authentication
info "I need to configure Basic Authentication for the endpoint."
read -p "Enter a username for the agent to use: " JULES_USERNAME
while true; do
    read -s -p "Enter a password for the agent: " JULES_PASSWORD
    echo
    read -s -p "Confirm password: " JULES_PASSWORD_CONFIRM
    echo
    [ "$JULES_PASSWORD" = "$JULES_PASSWORD_CONFIRM" ] && break
    warn "Passwords do not match. Please try again."
done

# 3. Detect OS and Architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac

info "Detected OS: $OS, Architecture: $ARCH"

# 4. Download and Install Binaries

# Create temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT
cd "$TMP_DIR"

# Download and install shell2http
info "Downloading shell2http v$SHELL2HTTP_VERSION..."
S2H_URL="https://github.com/msoap/shell2http/releases/download/$SHELL2HTTP_VERSION/shell2http-$SHELL2HTTP_VERSION.$OS'_'$ARCH.tar.gz"
curl -sL "$S2H_URL" | tar -xz
mv shell2http /usr/local/bin/shell2http
chmod +x /usr/local/bin/shell2http
info "shell2http installed successfully."

# Download and install cloudflared
info "Downloading cloudflared..."
CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-$OS-$ARCH"
curl -sL -o /usr/local/bin/cloudflared "$CF_URL"
chmod +x /usr/local/bin/cloudflared
info "cloudflared installed successfully."

# 5. Create Configuration Files and Runner Script

info "Creating configuration directory: $AGENT_CONFIG_DIR"
mkdir -p "$AGENT_CONFIG_DIR"

# Create credentials file
info "Storing credentials securely."
echo "JULES_USERNAME=$JULES_USERNAME" > "$AGENT_CRED_FILE"
echo "JULES_PASSWORD=$JULES_PASSWORD" >> "$AGENT_CRED_FILE"
chmod 600 "$AGENT_CRED_FILE"

# Create runner.sh script using a heredoc
info "Installing runner script to $AGENT_RUNNER_SCRIPT"
cat > "$AGENT_RUNNER_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail
if [ -z "${repo:-}" ] || [ -z "${branch:-}" ] || [ -z "${test_cmd:-}" ]; then
  echo "[ERROR] Missing required environment variables: repo, branch, test_cmd" >&2
  exit 1
fi
TMP_DIR=$(mktemp -d /tmp/jules-run-XXXXXX)
trap 'echo "[INFO] Cleaning up..." >&2; rm -rf -- "$TMP_DIR"' EXIT
cd "$TMP_DIR"
echo "[INFO] Cloning $repo (branch: $branch)" >&2
git clone --depth 1 -b "$branch" "$repo" "repo"
cd "repo"
echo "[INFO] Running: $test_cmd" >&2
eval "$test_cmd"
EOF
chmod +x "$AGENT_RUNNER_SCRIPT"

# 6. Set up System Service
if [ "$OS" = "linux" ]; then
    info "Setting up systemd service for Linux..."
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Jules Endpoint Agent
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=$AGENT_CRED_FILE
ExecStart=/usr/local/bin/shell2http \\
    -host 0.0.0.0 \\
    -port $PORT \\
    -form \\
    -include-stderr \\
    -500 \\
    -basic-auth "\${JULES_USERNAME}:\${JULES_PASSWORD}" \\
    /run "$AGENT_RUNNER_SCRIPT"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    info "$SERVICE_NAME service started and enabled."

elif [ "$OS" = "darwin" ]; then
    info "Setting up launchd service for macOS..."
    # Using a heredoc with a non-single-quoted EOF to allow variable expansion.
    cat > "/Library/LaunchDaemons/com.jules.endpoint.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jules.endpoint</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/shell2http</string>
        <string>-host</string>
        <string>0.0.0.0</string>
        <string>-port</string>
        <string>${PORT}</string>
        <string>-form</string>
        <string>-include-stderr</string>
        <string>-500</string>
        <string>-basic-auth</string>
        <string>${JULES_USERNAME}:${JULES_PASSWORD}</string>
        <string>/run</string>
        <string>${AGENT_RUNNER_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    launchctl load "/Library/LaunchDaemons/com.jules.endpoint.plist"
    info "launchd service loaded."
fi

# 7. Configure Cloudflare Tunnel
info "--- Cloudflare Tunnel Setup ---"
info "You will now be asked to log in to your Cloudflare account."
info "A browser window will open. Please authorize the tunnel."
read -p "Press Enter to continue..."

cloudflared tunnel login

TUNNEL_NAME="jules-endpoint-$(openssl rand -hex 4)"
info "Creating a new tunnel named: $TUNNEL_NAME"
# The tunnel command may fail if the user already has a tunnel with that name.
# This is unlikely but we should handle it gracefully.
if ! cloudflared tunnel create "$TUNNEL_NAME"; then
    error "Failed to create Cloudflare tunnel. Please check your Cloudflare account and try again."
fi
TUNNEL_UUID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')

info "Configuring the tunnel to point to the local service..."
CF_CONFIG_DIR="/etc/cloudflared"
mkdir -p "$CF_CONFIG_DIR"
cat > "$CF_CONFIG_DIR/config.yml" << EOF
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: "*"
    service: http://localhost:$PORT
  - service: http_status:404
EOF

info "Installing cloudflared as a service..."
cloudflared service install
if [ "$OS" = "linux" ]; then
    systemctl start cloudflared
elif [ "$OS" = "darwin" ]; then
    launchctl start com.cloudflare.cloudflared
fi

info "--- SETUP COMPLETE ---"
echo
info "Your Jules Endpoint Agent is now running!"
info "  Username: $JULES_USERNAME"
warn "  Your public URL is: https://$TUNNEL_NAME.trycloudflare.com"
info "Please provide the username and the public URL to the AI agent."
