# jules-endpoint-agent: connection-info.ps1
#
# This script generates connection information for Jules to access the SSH endpoint
# on Windows. It extracts tunnel hostname and creates formatted configuration blocks.

param(
    [switch]$HostnameOnly,
    [switch]$SshCommandOnly,
    [switch]$Help
)

# --- Constants ---
$AGENT_USER = "jules"
$CLOUDFLARED_CONFIG_DIR = "$env:USERPROFILE\.cloudflared"

# --- Helper Functions ---
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

# Function to extract tunnel hostname from Cloudflare
function Get-TunnelHostname {
    Write-Info "Extracting tunnel hostname..."
    
    $hostname = ""
    
    # Method 1: Try using cloudflared tunnel list command
    if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
        Write-Info "Attempting to get hostname using cloudflared tunnel list..."
        try {
            $tunnelList = cloudflared tunnel list 2>$null
            if ($tunnelList) {
                $hostname = ($tunnelList | Select-String -Pattern '[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1).Matches.Value
                if ($hostname) {
                    Write-Success "Found hostname using tunnel list: $hostname"
                    return $hostname
                }
            }
        }
        catch {
            Write-Warning "Failed to get tunnel list: $($_.Exception.Message)"
        }
    }
    
    # Method 2: Check cloudflared configuration directory
    if (Test-Path $CLOUDFLARED_CONFIG_DIR) {
        Write-Info "Searching for hostname in cloudflared configuration directory..."
        $configFiles = Get-ChildItem -Path $CLOUDFLARED_CONFIG_DIR -Filter "*.json" -ErrorAction SilentlyContinue
        foreach ($configFile in $configFiles) {
            try {
                $content = Get-Content -Path $configFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $matches = [regex]::Matches($content, '[a-z0-9-]+\.trycloudflare\.com')
                    if ($matches.Count -gt 0) {
                        $hostname = $matches[0].Value
                        Write-Success "Found hostname in configuration file: $hostname"
                        return $hostname
                    }
                }
            }
            catch {
                Write-Warning "Could not read config file $($configFile.FullName): $($_.Exception.Message)"
            }
        }
    }
    
    # Method 3: Try to find hostname in Windows Event Log (if cloudflared logs there)
    Write-Info "Checking Windows Event Log for cloudflared entries..."
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='cloudflared'} -MaxEvents 50 -ErrorAction SilentlyContinue
        foreach ($event in $events) {
            $matches = [regex]::Matches($event.Message, '[a-z0-9-]+\.trycloudflare\.com')
            if ($matches.Count -gt 0) {
                $hostname = $matches[0].Value
                Write-Success "Found hostname in Event Log: $hostname"
                return $hostname
            }
        }
    }
    catch {
        Write-Warning "Could not access Event Log: $($_.Exception.Message)"
    }
    
    Write-Error "Could not extract tunnel hostname. Please ensure the tunnel is running and try again."
}

# Function to validate connection information
function Test-ConnectionInfo {
    param(
        [string]$Hostname,
        [string]$Username
    )
    
    Write-Info "Validating connection information..."
    
    # Validate hostname format
    if ($Hostname -notmatch '^[a-z0-9-]+\.(trycloudflare\.com|[a-z0-9.-]+)$') {
        Write-Error "Invalid hostname format: $Hostname"
    }
    
    # Validate username
    if ([string]::IsNullOrEmpty($Username)) {
        Write-Error "Username cannot be empty"
    }
    
    # Check if user exists on system
    try {
        $user = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
        if (-not $user) {
            Write-Warning "User '$Username' does not exist on this system"
        }
    }
    catch {
        Write-Warning "Could not verify user existence: $($_.Exception.Message)"
    }
    
    # Check if SSH service is running (OpenSSH Server)
    $sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
    if (-not $sshService -or $sshService.Status -ne "Running") {
        Write-Warning "SSH service (sshd) does not appear to be running"
    }
    
    # Check if cloudflared is running
    $cloudflaredProcess = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if (-not $cloudflaredProcess) {
        Write-Warning "Cloudflared process does not appear to be running"
    }
    
    Write-Success "Connection information validation completed"
}

# Function to generate SSH connection command
function Get-SshCommand {
    param(
        [string]$Hostname,
        [string]$Username
    )
    
    return "ssh $Username@$Hostname"
}

# Function to generate formatted configuration block
function Get-ConfigBlock {
    param(
        [string]$Hostname,
        [string]$Username
    )
    
    return @"
=== Jules Endpoint Agent - Connection Information (Windows) ===

SSH Connection Details:
  Hostname: $Hostname
  Username: $Username
  Port: 22 (default)
  Authentication: SSH public key only

Quick Connect Command:
  ssh $Username@$Hostname

Windows Information:
  Agent User: $Username
  SSH Service: OpenSSH Server for Windows
  Platform: Windows with PowerShell

Security Notes:
  - This endpoint requires SSH public key authentication
  - The user '$Username' has administrative privileges
  - All traffic is encrypted through Cloudflare's network
  - No direct network ports are exposed on the host machine

Connection Test:
  To test the connection, run: ssh -o ConnectTimeout=10 $Username@$Hostname 'echo "Connection successful"'

=== End Connection Information ===
"@
}

# Function to generate copy-pasteable configuration for Jules
function Get-JulesConfig {
    param(
        [string]$Hostname,
        [string]$Username
    )
    
    return @"

=== Copy-Pasteable Configuration for Jules ===

Host jules-endpoint-windows
    HostName $Hostname
    User $Username
    Port 22
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Connection Command: ssh jules-endpoint-windows

Or direct command: ssh $Username@$Hostname

=== End Jules Configuration ===
"@
}

# Function to show help
function Show-Help {
    Write-Host "Usage: .\connection-info.ps1 [OPTIONS]"
    Write-Host "Generate connection information for Jules Endpoint Agent (Windows)"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -HostnameOnly        Output only the tunnel hostname"
    Write-Host "  -SshCommandOnly      Output only the SSH connection command"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Default: Generate complete connection information block"
}

# Main function
function Main {
    Write-Info "Jules Endpoint Agent - Connection Information Generator (Windows)"
    Write-Info "=================================================================="
    
    # Check if running as administrator (recommended for accessing system info)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Not running as administrator. Some validation checks may not work properly."
    }
    
    # Extract tunnel hostname
    $hostname = Get-TunnelHostname
    
    # Validate connection information
    Test-ConnectionInfo -Hostname $hostname -Username $AGENT_USER
    
    # Generate and display connection information
    Write-Host ""
    Write-Host (Get-ConfigBlock -Hostname $hostname -Username $AGENT_USER)
    
    # Generate Jules-specific configuration
    Write-Host (Get-JulesConfig -Hostname $hostname -Username $AGENT_USER)
    
    # Generate simple SSH command
    Write-Host ""
    Write-Success "Connection information generated successfully!"
    Write-Info "Jules can connect using: $(Get-SshCommand -Hostname $hostname -Username $AGENT_USER)"
}

# Handle command line arguments
if ($Help) {
    Show-Help
    exit 0
}

if ($HostnameOnly) {
    $hostname = Get-TunnelHostname
    Write-Output $hostname
    exit 0
}

if ($SshCommandOnly) {
    $hostname = Get-TunnelHostname
    $command = Get-SshCommand -Hostname $hostname -Username $AGENT_USER
    Write-Output $command
    exit 0
}

# Default: run main function
Main