#!/bin/bash
# Simple Docker Setup for Jules Hardware Access
# Works on Linux, macOS, and Windows (Git Bash/WSL)

set -e

echo "🤖 Jules Hardware Access - Docker Setup"
echo "========================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo ""
    echo "Install Docker:"
    echo "  • Windows/Mac: https://www.docker.com/products/docker-desktop"
    echo "  • Linux: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

echo "✓ Docker found"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env << 'EOF'
# Cloudflare Tunnel Token
# Get from: https://one.dash.cloudflare.com/
CLOUDFLARE_TOKEN=your_token_here

# Your SSH Public Key
# Get with: cat ~/.ssh/id_rsa.pub
JULES_SSH_PUBLIC_KEY=ssh-rsa AAAA...your_key_here

# Optional: Custom settings
SSH_PORT=22
JULES_USERNAME=jules
EOF
    echo "✓ Created .env file"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file with your credentials!"
    echo ""
    echo "1. Get Cloudflare token: https://one.dash.cloudflare.com/"
    echo "2. Get your SSH public key: cat ~/.ssh/id_rsa.pub"
    echo ""
    echo "Then run this script again."
    exit 0
fi

# Validate .env
echo "🔍 Validating configuration..."

source .env

if [[ "$CLOUDFLARE_TOKEN" == "your_token_here" ]]; then
    echo "❌ Please set CLOUDFLARE_TOKEN in .env file"
    exit 1
fi

if [[ "$JULES_SSH_PUBLIC_KEY" == "ssh-rsa AAAA...your_key_here" ]]; then
    echo "❌ Please set JULES_SSH_PUBLIC_KEY in .env file"
    exit 1
fi

echo "✓ Configuration valid"
echo ""

# Build and start
echo "🚀 Starting Jules container..."
docker-compose up -d --build

echo ""
echo "⏳ Waiting for services to start..."
sleep 10

# Get connection info
echo ""
echo "📋 Connection Information:"
echo "=========================="
docker-compose exec -T jules-agent /connection-info.sh || echo "Run: docker-compose exec jules-agent /connection-info.sh"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Copy connection files to your project"
echo "  2. Commit and push to GitHub"
echo "  3. Jules can now access your hardware!"
echo ""
echo "Useful commands:"
echo "  • View logs: docker-compose logs -f"
echo "  • Stop: docker-compose down"
echo "  • Restart: docker-compose restart"
echo "  • Shell: docker-compose exec jules-agent bash"
