# AI Agent Remote Hardware Access - Interactive Setup
# This script guides you through setting up secure remote access for AI agents

param(
    [switch]$SkipCloudflare,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
AI Agent Remote Hardware Access Setup

This script will guide you through:
1. Generating SSH keys for your AI agent
2. Setting up Cloudflare tunnel configuration
3. Starting the secure tunnel
4. Providing connection details for your AI agent

Usage:
  .\setup.ps1                 # Full interactive setup
  .\setup.ps1 -SkipCloudflare # Skip Cloudflare setup (if already configured)
  .\setup.ps1 -Help           # Show this help

Requirements:
- Docker installed and running
- Cloudflare account (free tier works)
- Internet connection

"@
    exit 0
}

Write-Host "🤖 AI Agent Remote Hardware Access Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

# Check Docker
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker found: $dockerVersion" -ForegroundColor Green
    } else {
        throw "Docker not found"
    }
} catch {
    Write-Host "❌ Docker is required but not found. Please install Docker Desktop." -ForegroundColor Red
    Write-Host "   Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is running
try {
    docker ps >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker is running" -ForegroundColor Green
    } else {
        throw "Docker not running"
    }
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 1: Generate SSH Keys
Write-Host "🔐 Step 1: Generating SSH Keys for AI Agent" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$agentName = Read-Host "Enter your AI agent name (e.g., 'jules', 'claude', 'gpt')"
if ([string]::IsNullOrWhiteSpace($agentName)) {
    $agentName = "ai-agent"
}

$keyFile = "${agentName}_key"

if (Test-Path $keyFile) {
    $overwrite = Read-Host "SSH key '$keyFile' already exists. Overwrite? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "Using existing SSH key." -ForegroundColor Yellow
    } else {
        Remove-Item $keyFile, "${keyFile}.pub" -ErrorAction SilentlyContinue
        ssh-keygen -t ed25519 -f $keyFile -N '""' -C "${agentName}@remote-access"
    }
} else {
    Write-Host "Generating new SSH key pair..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f $keyFile -N '""' -C "${agentName}@remote-access"
}

if (Test-Path "${keyFile}.pub") {
    $publicKey = Get-Content "${keyFile}.pub" -Raw
    Write-Host "✅ SSH keys generated successfully!" -ForegroundColor Green
    Write-Host "   Public key: ${keyFile}.pub" -ForegroundColor Gray
    Write-Host "   Private key: ${keyFile} (keep this secure!)" -ForegroundColor Gray
} else {
    Write-Host "❌ Failed to generate SSH keys" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Cloudflare Setup
if (-not $SkipCloudflare) {
    Write-Host "☁️  Step 2: Cloudflare Tunnel Setup" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To create a secure tunnel, you need a Cloudflare tunnel token." -ForegroundColor White
    Write-Host ""
    Write-Host "📝 Follow these steps:" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://one.dash.cloudflare.com/" -ForegroundColor Gray
    Write-Host "   2. Sign in (or create free account)" -ForegroundColor Gray
    Write-Host "   3. Navigate to: Networks → Tunnels" -ForegroundColor Gray
    Write-Host "   4. Click 'Create a tunnel'" -ForegroundColor Gray
    Write-Host "   5. Choose 'Cloudflared'" -ForegroundColor Gray
    Write-Host "   6. Name it: '${agentName}-hardware-access'" -ForegroundColor Gray
    Write-Host "   7. Copy the token (starts with 'eyJ...')" -ForegroundColor Gray
    Write-Host ""
    
    $token = Read-Host "Paste your Cloudflare tunnel token here"
    
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "❌ Token is required. Run the script again when you have it." -ForegroundColor Red
        exit 1
    }
    
    if (-not $token.StartsWith("eyJ")) {
        Write-Host "⚠️  Warning: Token doesn't look correct (should start with 'eyJ')" -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            exit 1
        }
    }
} else {
    Write-Host "⏭️  Skipping Cloudflare setup (using existing configuration)" -ForegroundColor Yellow
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" -Raw
        if ($envContent -match "CLOUDFLARE_TOKEN=(.+)") {
            $token = $matches[1]
            if ($token -eq "YOUR_CLOUDFLARE_TOKEN_HERE") {
                Write-Host "❌ No valid Cloudflare token found in .env file" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "❌ No Cloudflare token found in .env file" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "❌ No .env file found" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 3: Update Configuration
Write-Host "⚙️  Step 3: Updating Configuration" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Update .env file
$envContent = @"
# AI Agent Remote Hardware Access Configuration
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Cloudflare tunnel token
CLOUDFLARE_TOKEN=$token

# AI Agent SSH public key
JULES_SSH_PUBLIC_KEY=$($publicKey.Trim())

# SSH configuration
SSH_PORT=22
JULES_USERNAME=$agentName
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8
Write-Host "Configuration updated in .env file" -ForegroundColor Green

Write-Host ""

# Step 4: Start the Tunnel
Write-Host "🚀 Step 4: Starting Secure Tunnel" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

Write-Host "Building and starting the secure tunnel..." -ForegroundColor Yellow

try {
    # Stop any existing container
    docker-compose -f docker/docker-compose.yml down 2>$null
    
    # Start the tunnel
    docker-compose -f docker/docker-compose.yml up -d --build
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Tunnel started successfully!" -ForegroundColor Green
    } else {
        throw "Docker compose failed"
    }
} catch {
    Write-Host "❌ Failed to start tunnel. Check Docker logs:" -ForegroundColor Red
    Write-Host "   docker-compose -f docker/docker-compose.yml logs" -ForegroundColor Gray
    exit 1
}

# Wait for tunnel to establish
Write-Host "⏳ Waiting for tunnel to establish connection..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host ""

# Step 5: Get Connection Information
Write-Host "🔗 Step 5: Connection Information for AI Agent" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

try {
    Write-Host "Retrieving connection details..." -ForegroundColor Yellow
    $connectionInfo = docker exec jules-agent /app/connection-info.sh 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $connectionInfo) {
        Write-Host $connectionInfo
    } else {
        Write-Host "⚠️  Could not retrieve connection info automatically. Tunnel may still be connecting." -ForegroundColor Yellow
        Write-Host "   Try running this command in a few minutes:" -ForegroundColor Gray
        Write-Host "   docker exec jules-agent /app/connection-info.sh" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️  Connection info not available yet. Tunnel may still be starting." -ForegroundColor Yellow
}

Write-Host ""

# Step 6: AI Agent Instructions
Write-Host "🤖 Step 6: Instructions for Your AI Agent" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Provide these details to your AI agent:" -ForegroundColor White
Write-Host ""

Write-Host "🔑 Private SSH Key:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Gray
if (Test-Path $keyFile) {
    $privateKey = Get-Content $keyFile -Raw
    Write-Host $privateKey -ForegroundColor White
} else {
    Write-Host "❌ Private key file not found: $keyFile" -ForegroundColor Red
}

Write-Host ""
Write-Host "💬 Instructions for AI Agent:" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Gray
Write-Host @"
To connect to your hardware remotely:

1. Save the private key above to a file (e.g., 'remote_key')
2. Set proper permissions: chmod 600 remote_key (on Unix systems)
3. Get the current tunnel hostname by running:
   docker exec jules-agent /app/connection-info.sh --hostname-only
4. Connect using: ssh -i remote_key $agentName@[tunnel-hostname]

You will have full sudo access to the system and can:
- Access GPU and hardware resources
- Install software packages
- Run development tools
- Access files and directories
"@ -ForegroundColor White

Write-Host ""

# Step 7: Management Commands
Write-Host "🛠️  Step 7: Management Commands" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📝 Useful commands:" -ForegroundColor White
Write-Host ""
Write-Host "Get connection info:" -ForegroundColor Yellow
Write-Host "  docker exec jules-agent /app/connection-info.sh" -ForegroundColor Gray
Write-Host ""
Write-Host "Check tunnel status:" -ForegroundColor Yellow
Write-Host "  docker-compose -f docker/docker-compose.yml ps" -ForegroundColor Gray
Write-Host ""
Write-Host "View tunnel logs:" -ForegroundColor Yellow
Write-Host "  docker-compose -f docker/docker-compose.yml logs -f" -ForegroundColor Gray
Write-Host ""
Write-Host "Stop tunnel:" -ForegroundColor Yellow
Write-Host "  docker-compose -f docker/docker-compose.yml down" -ForegroundColor Gray
Write-Host ""
Write-Host "Restart tunnel:" -ForegroundColor Yellow
Write-Host "  docker-compose -f docker/docker-compose.yml restart" -ForegroundColor Gray
Write-Host ""

Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host ""
Write-Host "Your AI agent can now securely access your hardware remotely!" -ForegroundColor White
Write-Host "The tunnel will automatically restart if your system reboots." -ForegroundColor Gray
Write-Host ""
Write-Host "For troubleshooting, see: TROUBLESHOOTING.md" -ForegroundColor Gray