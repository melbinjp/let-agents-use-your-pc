# jules-endpoint-agent: install.ps1
#
# This PowerShell script automates the setup of the Jules Endpoint Agent on Windows.
# It installs shell2http and cloudflared, configures them to run as
# services, and guides the user through the final setup steps.

# --- Helper Functions ---
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red; exit 1 }

# --- Main Script ---

# TODO / HELP WANTED: Implement uninstallation logic.
# This script should accept an `--uninstall` flag that performs the following actions:
# - Stop the 'JulesEndpointAgent' and 'cloudflared' services.
# - Delete the 'JulesEndpointAgent' and 'cloudflared' services.
# - Delete the installation directory ('C:\Program Files\JulesEndpointAgent').
# - Delete the Cloudflare tunnel.
# - Remove the cloudflared config files from the user's profile.

# 1. Welcome and Pre-flight Checks
Write-Info "Welcome to the Jules Endpoint Agent installer for Windows."
Write-Warn "Please review the security warnings in the README.md before proceeding."
Write-Warn "This script will download and install software and create Windows services."

# Check for Administrator privileges
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator. Please re-launch PowerShell as Administrator and run the script again."
}

# Check for Git dependency
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in your PATH. Please install Git for Windows and ensure it's in your system's PATH, then re-run this script."
}

# 2. Gather User Input for Authentication
Write-Info "Configuring Basic Authentication for the endpoint."
$JulesUsername = Read-Host "Enter a username for the agent to use"
$JulesPassword = Read-Host "Enter a password for the agent" -AsSecureString

# Convert SecureString to plain text for the service creation.
# This is a security trade-off for simplicity in this script.
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($JulesPassword)
$PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# 3. Define Paths and Architecture
$InstallDir = "C:\Program Files\JulesEndpointAgent"
$RunnerScriptPath = Join-Path $InstallDir "runner.ps1"
$Shell2HttpPath = Join-Path $InstallDir "shell2http.exe"
$CloudflaredPath = Join-Path $InstallDir "cloudflared.exe"

$Arch = $env:PROCESSOR_ARCHITECTURE
if ($Arch -eq "AMD64") { $Arch = "amd64" }
elseif ($Arch -eq "ARM64") { $Arch = "arm64" }
else { Write-Error "Unsupported architecture: $Arch" }

Write-Info "Detected Architecture: $Arch"
Write-Info "Installation directory will be: $InstallDir"

# 4. Download and Install Binaries
New-Item -ItemType Directory -Path $InstallDir -Force
$TempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "jules-install-$(Get-Random)")

try {
    Write-Info "Downloading shell2http..."
    $S2H_URL = "https://github.com/msoap/shell2http/releases/download/1.17.0/shell2http-1.17.0.windows_$($Arch).zip"
    Invoke-WebRequest -Uri $S2H_URL -OutFile (Join-Path $TempDir "shell2http.zip")
    Expand-Archive -Path (Join-Path $TempDir "shell2http.zip") -DestinationPath $InstallDir -Force

    Write-Info "Downloading cloudflared..."
    $CF_URL = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$($Arch).exe"
    Invoke-WebRequest -Uri $CF_URL -OutFile $CloudflaredPath

    Write-Info "Binaries installed successfully."
}
finally {
    Remove-Item -Recurse -Force -Path $TempDir
}

# 5. Create runner.ps1 script
Write-Info "Installing runner script to $RunnerScriptPath"
$runnerScriptContent = @'
# jules-endpoint-agent: runner.ps1
$ErrorActionPreference = 'Stop'
if (-not $env:repo -or -not $env:branch -or -not $env:test_cmd) {
    Write-Error "[ERROR] Missing required environment variables."
    exit 1
}
$tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "jules-run-$(Get-Random)")
try {
    Write-Host "[INFO] Created temp dir: $($tempDir.FullName)"
    Set-Location -Path $tempDir.FullName
    Write-Host "[INFO] Cloning: $env:repo (branch: $env:branch)"
    git clone --depth 1 -b $env:branch $env:repo "repo"
    Set-Location -Path (Join-Path $tempDir.FullName "repo")
    Write-Host "[INFO] Executing: $env:test_cmd"
    Invoke-Expression -Command $env:test_cmd
}
finally {
    Write-Host "[INFO] Cleaning up..."
    Remove-Item -Recurse -Force -Path $tempDir.FullName
}
'@
Set-Content -Path $RunnerScriptPath -Value $runnerScriptContent

# 6. Set up Windows Services
Write-Info "Setting up Windows services..."

# HELP WANTED: The method below passes the agent's password as a plain text argument
# to the Windows service binary path. This is a security risk, as it can be viewed by
# anyone with administrative access to the machine.
# A more secure method would be to store the credentials in a protected file or use
# a different method to pass them to the service. If you have ideas on how to
# improve this, please open an issue or a pull request!
Write-Warn "The agent's password will be stored in the service configuration. This is a security risk if the machine is not properly secured."

# Service for shell2http
$S2H_Service_Name = "JulesEndpointAgent"
$S2H_Binary_Path = "`"$Shell2HttpPath`" -host 0.0.0.0 -port 8080 -form -include-stderr -500 -basic-auth `"$JulesUsername`:$PlainTextPassword`" /run `"`"powershell.exe -File `"`"$RunnerScriptPath`"`"`"`""
New-Service -Name $S2H_Service_Name -BinaryPathName $S2H_Binary_Path -DisplayName "Jules Endpoint Agent (shell2http)" -StartupType Automatic
Start-Service -Name $S2H_Service_Name
Write-Info "$S2H_Service_Name service created and started."

# 7. Configure Cloudflare Tunnel
Write-Info "--- Cloudflare Tunnel Setup ---"
Write-Info "A browser window will open. Please log in to your Cloudflare account and authorize the tunnel."
Read-Host "Press Enter to continue..."

Start-Process -FilePath $CloudflaredPath -ArgumentList "tunnel login" -Wait

$TunnelName = "jules-win-$(Get-Random -Maximum 9999)"
Write-Info "Creating a new tunnel named: $TunnelName"
Start-Process -FilePath $CloudflaredPath -ArgumentList "tunnel create $TunnelName" -Wait -NoNewWindow

# Find user's profile path for the .cloudflared directory
$userProfile = $env:USERPROFILE
$credentialsFile = (Get-ChildItem -Path "$userProfile\.cloudflared\*.json" | Where-Object { $_.Name -match '^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\.json$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$tunnelId = (Get-Content $credentialsFile | ConvertFrom-Json).TunnelID

# Create config.yml
$configContent = @"
tunnel: $tunnelId
credentials-file: $credentialsFile
ingress:
  - hostname: "*"
    service: http://localhost:8080
  - service: http_status:404
"@
$configPath = Join-Path "$userProfile\.cloudflared" "config.yml"
Set-Content -Path $configPath -Value $configContent

Write-Info "Installing cloudflared as a service..."
Start-Process -FilePath $CloudflaredPath -ArgumentList "service install" -Wait
Start-Service -Name "cloudflared"
Write-Info "cloudflared service installed and started."

# 8. Final Output
Write-Info "--- SETUP COMPLETE ---"
Write-Info "Your Jules Endpoint Agent is now running on Windows!"
Write-Info "  Username: $JulesUsername"
$tunnelUrl = (Start-Process -FilePath $CloudflaredPath -ArgumentList "tunnel info $TunnelName" -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $TempDir "cf.log")); Wait-Process $tunnelUrl.Id; (Get-Content (Join-Path $TempDir "cf.log") | Select-String -Pattern "trycloudflare.com" | Select-Object -First 1).Line.Split(' ')[0]
Write-Warn "  Your public URL is: $tunnelUrl"
Write-Info "Please provide the username and the public URL to the AI agent."
