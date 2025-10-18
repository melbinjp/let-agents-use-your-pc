# jules-endpoint-agent: install.ps1 (SSH Edition)
#
# This PowerShell script automates the setup of the Jules Endpoint Agent on Windows.
# It configures OpenSSH Server and cloudflared to create a secure SSH endpoint
# accessible via a public URL.

param(
    [switch]$Uninstall
)

# --- Helper Functions ---
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red; exit 1 }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Cyan }

# --- Constants ---
$AGENT_USER = "jules"
$CLOUDFLARED_CONFIG_DIR = "C:\ProgramData\cloudflared"
$CLOUDFLARED_CONFIG_FILE = "$CLOUDFLARED_CONFIG_DIR\config.yml"
$INSTALL_LOG = "$env:TEMP\jules-endpoint-install.log"

# --- Uninstall Function ---
function Uninstall-JulesEndpoint {
    Write-Info "Starting Jules Endpoint Agent uninstallation..."
    
    try {
        # Stop and remove cloudflared service
        if (Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue) {
            Write-Info "Stopping cloudflared service..."
            Stop-Service -Name "cloudflared" -Force -ErrorAction SilentlyContinue
            
            Write-Info "Uninstalling cloudflared service..."
            & cloudflared service uninstall
        }
        
        # Stop OpenSSH Server if we enabled it
        Write-Info "Stopping OpenSSH Server..."
        Stop-Service -Name "sshd" -ErrorAction SilentlyContinue
        
        # Remove jules user
        if (Get-LocalUser -Name $AGENT_USER -ErrorAction SilentlyContinue) {
            Write-Info "Removing user '$AGENT_USER'..."
            Remove-LocalUser -Name $AGENT_USER -ErrorAction SilentlyContinue
        }
        
        # Remove cloudflared configuration
        if (Test-Path $CLOUDFLARED_CONFIG_DIR) {
            Write-Info "Removing cloudflared configuration..."
            Remove-Item -Path $CLOUDFLARED_CONFIG_DIR -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Remove SSH configuration changes (restore backup if exists)
        $sshConfigPath = "$env:ProgramData\ssh\sshd_config"
        $sshConfigBackup = "$sshConfigPath.backup"
        if (Test-Path $sshConfigBackup) {
            Write-Info "Restoring SSH configuration backup..."
            Copy-Item -Path $sshConfigBackup -Destination $sshConfigPath -Force
            Remove-Item -Path $sshConfigBackup -Force
        }
        
        Write-Success "Jules Endpoint Agent uninstalled successfully!"
        Write-Info "Note: OpenSSH Server feature was left enabled. Disable manually if not needed."
    }
    catch {
        Write-Error "Uninstallation failed: $_"
    }
    
    exit 0
}

# --- Main Script ---

# Handle uninstall flag
if ($Uninstall) {
    Uninstall-JulesEndpoint
}

# Initialize installation log
"Jules Endpoint Agent Installation Log - $(Get-Date)" | Out-File -FilePath $INSTALL_LOG

# 1. Welcome and Pre-flight Checks
Write-Info "Welcome to the Jules Endpoint Agent installer for Windows (SSH Edition)."
Write-Info "This script will set up your machine as a remote SSH endpoint."
Write-Warn "Please review the security warnings in the README.md before proceeding."
Write-Warn "This will give the AI agent full administrative access to your system."
""

# Check for Administrator privileges
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator. Please re-launch PowerShell as Administrator and run the script again."
}

# Check Windows version compatibility
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    Write-Error "This script requires Windows 10 or later for OpenSSH Server support."
}

Write-Info "System check passed. Windows version: $($osVersion.Major).$($osVersion.Minor)"

# 2. Gather User Input for SSH Key
Write-Info "I need the public SSH key for the AI agent that will connect to this endpoint."
Write-Warn "The key should be a single line (e.g., 'ssh-rsa AAAA...' or 'ssh-ed25519 AAAA...')."
""
"Example: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... user@host"
""

# Allow multiple attempts for SSH key input
$attempts = 0
$maxAttempts = 3
do {
    $JULES_SSH_PUBLIC_KEY = Read-Host "Paste the agent's public SSH key"
    
    if ([string]::IsNullOrWhiteSpace($JULES_SSH_PUBLIC_KEY)) {
        Write-Warn "SSH public key cannot be empty."
        $attempts++
        continue
    }
    
    # Basic SSH key validation
    if ($JULES_SSH_PUBLIC_KEY -match '^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\s+[A-Za-z0-9+/]+=*\s*.*$') {
        Write-Success "SSH key format validation passed"
        break
    } else {
        Write-Warn "Invalid SSH key format. Please ensure the key starts with a valid key type."
        $attempts++
    }
} while ($attempts -lt $maxAttempts)

if ($attempts -ge $maxAttempts) {
    Write-Error "Maximum attempts reached. Please ensure you have a valid SSH public key and re-run the script."
}

# 3. Install and Configure OpenSSH Server
Write-Info "Checking OpenSSH Server installation..."

# Check if OpenSSH Server is installed
$sshServerFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshServerFeature.State -ne "Installed") {
    Write-Info "Installing OpenSSH Server..."
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-Success "OpenSSH Server installed successfully"
    }
    catch {
        Write-Error "Failed to install OpenSSH Server: $_"
    }
} else {
    Write-Info "OpenSSH Server is already installed"
}

# Configure SSH Server
Write-Info "Configuring SSH Server..."
$sshConfigPath = "$env:ProgramData\ssh\sshd_config"
$sshConfigBackup = "$sshConfigPath.backup"

# Create backup of original config
if (Test-Path $sshConfigPath -and -not (Test-Path $sshConfigBackup)) {
    Copy-Item -Path $sshConfigPath -Destination $sshConfigBackup
    Write-Info "Created backup of SSH configuration"
}

# Apply secure SSH configuration
$sshConfig = @"

# Jules Endpoint Agent SSH Configuration
# Added by jules-endpoint-agent installer
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
Subsystem sftp sftp-server.exe
"@

Add-Content -Path $sshConfigPath -Value $sshConfig
Write-Success "SSH Server configured successfully"

# Enable and start SSH services
Write-Info "Starting SSH services..."
try {
    Set-Service -Name sshd -StartupType 'Automatic'
    Start-Service sshd
    
    Set-Service -Name ssh-agent -StartupType 'Automatic'
    Start-Service ssh-agent
    
    Write-Success "SSH services started successfully"
}
catch {
    Write-Error "Failed to start SSH services: $_"
}

# Configure Windows Firewall for SSH (local connections only)
Write-Info "Configuring Windows Firewall for SSH..."
try {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH SSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
    Write-Success "Firewall rule configured for SSH"
}
catch {
    Write-Warn "Failed to configure firewall rule. SSH may not work properly."
}

# 4. Install cloudflared
Write-Info "Installing cloudflared..."

# Detect architecture
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq "AMD64") { $arch = "amd64" }
elseif ($arch -eq "ARM64") { $arch = "arm64" }
else { Write-Error "Unsupported architecture: $arch" }

# Download cloudflared
$cloudflaredPath = "C:\Program Files\cloudflared\cloudflared.exe"
$cloudflaredDir = Split-Path $cloudflaredPath -Parent

if (-not (Test-Path $cloudflaredDir)) {
    New-Item -ItemType Directory -Path $cloudflaredDir -Force | Out-Null
}

if (-not (Test-Path $cloudflaredPath)) {
    Write-Info "Downloading cloudflared..."
    $cfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe"
    try {
        Invoke-WebRequest -Uri $cfUrl -OutFile $cloudflaredPath
        Write-Success "cloudflared downloaded successfully"
    }
    catch {
        Write-Error "Failed to download cloudflared: $_"
    }
} else {
    Write-Info "cloudflared is already installed"
}

# Add cloudflared to PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($currentPath -notlike "*$cloudflaredDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$cloudflaredDir", "Machine")
    $env:PATH += ";$cloudflaredDir"
    Write-Info "Added cloudflared to system PATH"
}

# 5. Create and Configure Agent User
Write-Info "Creating a dedicated user for the agent: '$AGENT_USER'"

# Check if user already exists
try {
    $existingUser = Get-LocalUser -Name $AGENT_USER -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Warn "User '$AGENT_USER' already exists. Updating configuration..."
    } else {
        # Generate a random password for the user (won't be used due to SSH key auth)
        $randomPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})
        $securePassword = ConvertTo-SecureString $randomPassword -AsPlainText -Force
        
        New-LocalUser -Name $AGENT_USER -Password $securePassword -Description "Jules AI Agent User" -PasswordNeverExpires
        Write-Success "User '$AGENT_USER' created successfully"
    }
}
catch {
    Write-Error "Failed to create user '$AGENT_USER': $_"
}

# Add user to Administrators group for full system access
try {
    Add-LocalGroupMember -Group "Administrators" -Member $AGENT_USER -ErrorAction SilentlyContinue
    Write-Success "Added '$AGENT_USER' to Administrators group"
}
catch {
    Write-Warn "User may already be in Administrators group or operation failed"
}

# Configure SSH access for the agent user
Write-Info "Configuring SSH access for '$AGENT_USER'..."
$userProfile = "C:\Users\$AGENT_USER"
$sshDir = "$userProfile\.ssh"
$authorizedKeysFile = "$sshDir\authorized_keys"

# Create user profile directory if it doesn't exist
if (-not (Test-Path $userProfile)) {
    New-Item -ItemType Directory -Path $userProfile -Force | Out-Null
}

# Create .ssh directory
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# Add SSH public key
try {
    Set-Content -Path $authorizedKeysFile -Value $JULES_SSH_PUBLIC_KEY
    Write-Success "SSH key added successfully"
}
catch {
    Write-Error "Failed to add SSH key: $_"
}

# Set proper permissions on SSH directory and files
try {
    # Remove inheritance and set explicit permissions
    $acl = Get-Acl $sshDir
    $acl.SetAccessRuleProtection($true, $false)
    
    # Grant full control to the user and SYSTEM
    $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AGENT_USER, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    
    $acl.SetAccessRule($userRule)
    $acl.SetAccessRule($systemRule)
    Set-Acl -Path $sshDir -AclObject $acl
    
    # Set permissions on authorized_keys file
    $fileAcl = Get-Acl $authorizedKeysFile
    $fileAcl.SetAccessRuleProtection($true, $false)
    $fileAcl.SetAccessRule($userRule)
    $fileAcl.SetAccessRule($systemRule)
    Set-Acl -Path $authorizedKeysFile -AclObject $fileAcl
    
    Write-Success "SSH permissions configured correctly"
}
catch {
    Write-Warn "Failed to set SSH permissions. SSH access may not work properly."
}

# 6. Configure and Install Cloudflare Tunnel
Write-Info "--- Cloudflare Tunnel Setup ---"
Write-Info "You will now be asked to log in to your Cloudflare account."
Write-Info "A browser window will open. Please authorize the tunnel."
Write-Warn "If you don't have a Cloudflare account, create one at https://dash.cloudflare.com/sign-up"
""
Read-Host "Press Enter to continue with Cloudflare authentication"

# Authenticate with Cloudflare
Write-Info "Initiating Cloudflare authentication..."
try {
    & $cloudflaredPath tunnel login
    Write-Success "Cloudflare authentication successful"
}
catch {
    Write-Error "Failed to authenticate with Cloudflare: $_"
}

# Generate unique tunnel name
$tunnelName = "jules-ssh-win-$((Get-Random -Maximum 9999).ToString('D4'))"
Write-Info "Creating a new tunnel named: $tunnelName"

# Create the tunnel
try {
    $tunnelOutput = & $cloudflaredPath tunnel create $tunnelName 2>&1
    $tunnelUuid = ($tunnelOutput | Select-String -Pattern '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}').Matches[0].Value
    
    if ([string]::IsNullOrEmpty($tunnelUuid)) {
        Write-Error "Failed to extract tunnel UUID from creation output"
    }
    
    Write-Success "Tunnel '$tunnelName' created with UUID: $tunnelUuid"
}
catch {
    Write-Error "Failed to create Cloudflare tunnel: $_"
}

# Create cloudflared configuration
Write-Info "Configuring the tunnel to point to the local SSH service..."
if (-not (Test-Path $CLOUDFLARED_CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $CLOUDFLARED_CONFIG_DIR -Force | Out-Null
}

$credentialsFile = "$env:USERPROFILE\.cloudflared\$tunnelUuid.json"
$configContent = @"
tunnel: $tunnelUuid
credentials-file: $credentialsFile

ingress:
  - hostname: "*"
    service: ssh://localhost:22
  - service: http_status:404
"@

try {
    Set-Content -Path $CLOUDFLARED_CONFIG_FILE -Value $configContent
    Write-Success "Tunnel configuration created successfully"
}
catch {
    Write-Error "Failed to create tunnel configuration: $_"
}

# Install and start cloudflared service
Write-Info "Installing cloudflared as a Windows service..."
try {
    & $cloudflaredPath service install
    Start-Service -Name "cloudflared"
    Write-Success "cloudflared service installed and started successfully"
}
catch {
    Write-Error "Failed to install or start cloudflared service: $_"
}

# Wait for service to start
Start-Sleep -Seconds 5

# Verify service is running
if ((Get-Service -Name "cloudflared").Status -eq "Running") {
    Write-Success "cloudflared service is running"
} else {
    Write-Error "cloudflared service failed to start"
}

# 7. Generate Connection Information
Write-Info "Generating connection information..."

# Wait for tunnel to establish
Write-Info "Waiting for tunnel to establish connection..."
Start-Sleep -Seconds 10

# Try to get tunnel hostname
$tunnelHostname = ""
try {
    $tunnelInfo = & $cloudflaredPath tunnel info $tunnelUuid 2>&1
    $tunnelHostname = ($tunnelInfo | Select-String -Pattern '[a-z0-9-]+\.trycloudflare\.com').Matches[0].Value
}
catch {
    Write-Warn "Could not automatically determine tunnel hostname"
}

# 8. Final Output
Write-Success "--- INSTALLATION COMPLETE ---"
""
Write-Success "Your Jules Endpoint Agent is now running on Windows!"
Write-Info "  Agent User: $AGENT_USER"
Write-Info "  Tunnel UUID: $tunnelUuid"
Write-Info "  Tunnel Name: $tunnelName"

if ($tunnelHostname) {
    Write-Success "  SSH Hostname: $tunnelHostname"
    ""
    Write-Info "=== Copy-Pasteable Configuration for Jules ==="
    ""
    "Host jules-endpoint"
    "    HostName $tunnelHostname"
    "    User $AGENT_USER"
    "    Port 22"
    "    IdentitiesOnly yes"
    "    StrictHostKeyChecking no"
    "    UserKnownHostsFile /dev/null"
    ""
    Write-Success "Quick Connect Command: ssh $AGENT_USER@$tunnelHostname"
    ""
    Write-Info "=== End Configuration ==="
} else {
    Write-Warn "Could not automatically determine tunnel hostname."
    Write-Info "You can get connection details by running:"
    Write-Info "  cloudflared tunnel info $tunnelUuid"
}

""
Write-Success "Installation completed successfully!"
Write-Info "Installation log saved to: $INSTALL_LOG"
""
Write-Info "Service Status:"
Write-Info "  SSH Service: $((Get-Service -Name 'sshd').Status)"
Write-Info "  Cloudflared Service: $((Get-Service -Name 'cloudflared').Status)"
""
Write-Info "To check service logs:"
Write-Info "  Get-EventLog -LogName System -Source sshd"
Write-Info "  Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='cloudflared'}"
""
Write-Warn "Remember: The '$AGENT_USER' user has full administrative privileges for AI agent access."
""
Write-Info "To uninstall, run: .\install.ps1 -Uninstall"
