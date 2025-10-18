# Simple Docker Setup for Jules Hardware Access (Windows PowerShell)

Write-Host "🤖 Jules Hardware Access - Docker Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
}

Write-Host "✓ Docker found" -ForegroundColor Green
Write-Host ""

# Check if .env exists
if (-not (Test-Path .env)) {
    Write-Host "📝 Creating .env file..." -ForegroundColor Yellow
    
    @"
# Cloudflare Tunnel Token
# Get from: https://one.dash.cloudflare.com/
CLOUDFLARE_TOKEN=your_token_here

# Your SSH Public Key
# Get with: cat ~/.ssh/id_rsa.pub (in Git Bash) or type $env:USERPROFILE\.ssh\id_rsa.pub
JULES_SSH_PUBLIC_KEY=ssh-rsa AAAA...your_key_here

# Optional: Custom settings
SSH_PORT=22
JULES_USERNAME=jules
"@ | Out-File -FilePath .env -Encoding UTF8
    
    Write-Host "✓ Created .env file" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  IMPORTANT: Edit .env file with your credentials!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Get Cloudflare token: https://one.dash.cloudflare.com/"
    Write-Host "2. Get your SSH public key: type $env:USERPROFILE\.ssh\id_rsa.pub"
    Write-Host ""
    Write-Host "Then run this script again."
    exit 0
}

# Validate .env
Write-Host "🔍 Validating configuration..." -ForegroundColor Cyan

$envContent = Get-Content .env -Raw
if ($envContent -match "CLOUDFLARE_TOKEN=your_token_here") {
    Write-Host "❌ Please set CLOUDFLARE_TOKEN in .env file" -ForegroundColor Red
    exit 1
}

if ($envContent -match "JULES_SSH_PUBLIC_KEY=ssh-rsa AAAA...your_key_here") {
    Write-Host "❌ Please set JULES_SSH_PUBLIC_KEY in .env file" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Configuration valid" -ForegroundColor Green
Write-Host ""

# Build and start
Write-Host "🚀 Starting Jules container..." -ForegroundColor Cyan
docker-compose up -d --build

Write-Host ""
Write-Host "⏳ Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Get connection info
Write-Host ""
Write-Host "📋 Connection Information:" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
docker-compose exec -T jules-agent /connection-info.sh

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Copy connection files to your project"
Write-Host "  2. Commit and push to GitHub"
Write-Host "  3. Jules can now access your hardware!"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  • View logs: docker-compose logs -f"
Write-Host "  • Stop: docker-compose down"
Write-Host "  • Restart: docker-compose restart"
Write-Host "  • Shell: docker-compose exec jules-agent bash"
