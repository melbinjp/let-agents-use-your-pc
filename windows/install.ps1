# jules-endpoint-agent: install.ps1
#
# This PowerShell script automates the setup of the Jules Endpoint Agent on Windows.
# It installs cloudflared and configures it to provide secure,
# remote SSH access via a Cloudflare Tunnel.

# --- Helper Functions ---
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red; exit 1 }

# --- Main Script ---

# TODO / HELP WANTED: Implement uninstallation logic.
# This script should accept an `--uninstall` flag that performs the following actions:
# - Stop the 'cloudflared' service.
# - Delete the 'cloudflared' service.
# - Delete the installation directory ('C:\Program Files\JulesEndpointAgent').
# - Delete the Cloudflare tunnel.
# - Remove the cloudflared config files from the user's profile.

# 1. Welcome and Pre-flight Checks
Write-Info "Welcome to the Jules Endpoint Agent installer for SSH on Windows."
Write-Warn "Please review the security warnings in the README.md before proceeding."
Write-Warn "This script will download software and create a Windows service for Cloudflare."

# Check for Administrator privileges
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator. Please re-launch PowerShell as Administrator and run the script again."
}

# Check for Git dependency
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in your PATH. Please install Git for Windows and ensure it's in your system's PATH, then re-run this script."
}

# Check for running SSH server
$sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
if (-not $sshService -or $sshService.Status -ne 'Running') {
    Write-Error "The OpenSSH Server (sshd) is not running. Please install and start it before running this script."
}
Write-Info "Verified that the SSH server (sshd) is active."

# 2. Define Paths and Architecture
$InstallDir = "C:\Program Files\JulesEndpointAgent"
$RunnerScriptPath = Join-Path $InstallDir "runner.ps1"
$CloudflaredPath = Join-Path $InstallDir "cloudflared.exe"

$Arch = $env:PROCESSOR_ARCHITECTURE
if ($Arch -eq "AMD64") { $Arch = "amd64" }
elseif ($Arch -eq "ARM64") { $Arch = "arm64" }
else { Write-Error "Unsupported architecture: $Arch" }

Write-Info "Detected Architecture: $Arch"
Write-Info "Installation directory will be: $InstallDir"

# 3. Download and Install Binaries
New-Item -ItemType Directory -Path $InstallDir -Force
$TempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "jules-install-$(Get-Random)")

try {
    Write-Info "Downloading cloudflared..."
    $CF_URL = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$($Arch).exe"
    Invoke-WebRequest -Uri $CF_URL -OutFile $CloudflaredPath

    Write-Info "cloudflared binary installed successfully."
}
finally {
    Remove-Item -Recurse -Force -Path $TempDir
}

# 4. Install Runner Script
# The runner script is executed by the agent over SSH.
Write-Info "Installing runner script to $RunnerScriptPath"
# Assumes the install script is run from the `windows` directory.
Copy-Item -Path ".\runner.ps1" -Destination $RunnerScriptPath -Force


# 5. Configure Cloudflare Tunnel
Write-Info "--- Cloudflare Tunnel Setup ---"
Write-Info "A browser window will open. Please log in to your Cloudflare account and authorize the tunnel."
Read-Host "Press Enter to continue..."

Start-Process -FilePath $CloudflaredPath -ArgumentList "tunnel login" -Wait

$TunnelName = "jules-win-ssh-$(Get-Random -Maximum 9999)"
Write-Info "Creating a new tunnel named: $TunnelName"
Start-Process -FilePath $CloudflaredPath -ArgumentList "tunnel create $TunnelName" -Wait -NoNewWindow

# Find user's profile path for the .cloudflared directory
$userProfile = $env:USERPROFILE
$credentialsFile = (Get-ChildItem -Path "$userProfile\.cloudflared\*.json" | Where-Object { $_.Name -match '^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\.json$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$tunnelId = (Get-Content $credentialsFile | ConvertFrom-Json).TunnelID
$TunnelHostname = "$($TunnelName).trycloudflare.com"

# Create config.yml
$configContent = @"
tunnel: $tunnelId
credentials-file: $credentialsFile
ingress:
  - hostname: $TunnelHostname
    service: ssh://localhost:22
  - service: http_status:404
"@
# The config file must be placed in the user's profile .cloudflared directory
# for the service to find it.
$configPath = Join-Path "$userProfile\.cloudflared" "config.yml"
Set-Content -Path $configPath -Value $configContent

Write-Info "Installing cloudflared as a service..."
Start-Process -FilePath $CloudflaredPath -ArgumentList "service install" -Wait
Start-Service -Name "cloudflared"
Write-Info "cloudflared service installed and started."

# 6. Final Output
Write-Info "--- SETUP COMPLETE ---"
Write-Info "Your Jules Endpoint Agent is now running on Windows!"
Write-Warn "Your SSH endpoint is: ssh <YOUR_USER>@$TunnelHostname"
Write-Info "To allow the agent to connect, you must add its public SSH key to your user's `~/.ssh/authorized_keys` file."
Write-Info "The runner script is available at $RunnerScriptPath if you need to inspect it."
