#!/bin/bash
# Helper script to copy generated files to your project repo

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Jules Hardware Access - Copy Files to Project${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if project path provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: ./copy-to-project.sh /path/to/your/project [docker|native]${NC}"
    echo ""
    echo "Examples:"
    echo "  ./copy-to-project.sh ~/projects/my-app"
    echo "  ./copy-to-project.sh ~/projects/my-app docker"
    echo "  ./copy-to-project.sh ~/projects/my-app native"
    echo ""
    exit 1
fi

PROJECT_PATH="$1"
MODE="${2:-docker}"  # Default to docker

# Validate project path
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}✗ Project directory not found: $PROJECT_PATH${NC}"
    exit 1
fi

# Check if generated files exist
SOURCE_DIR="generated_files/$MODE"
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}✗ Generated files not found: $SOURCE_DIR${NC}"
    echo -e "${YELLOW}Run setup first:${NC}"
    if [ "$MODE" = "docker" ]; then
        echo "  cd docker && ./setup.sh"
    else
        echo "  python setup.py"
    fi
    exit 1
fi

echo -e "${BLUE}ℹ${NC} Copying ${MODE} files to: $PROJECT_PATH"
echo ""

# Copy .jules directory
if [ -d "$SOURCE_DIR/.jules" ]; then
    echo -e "${BLUE}→${NC} Copying .jules/ directory..."
    cp -r "$SOURCE_DIR/.jules" "$PROJECT_PATH/"
    echo -e "${GREEN}✓${NC} Copied .jules/"
else
    echo -e "${YELLOW}⚠${NC} .jules/ directory not found in $SOURCE_DIR"
fi

# Copy AGENTS.md
if [ -f "$SOURCE_DIR/AGENTS.md" ]; then
    echo -e "${BLUE}→${NC} Copying AGENTS.md..."
    cp "$SOURCE_DIR/AGENTS.md" "$PROJECT_PATH/"
    echo -e "${GREEN}✓${NC} Copied AGENTS.md"
else
    echo -e "${YELLOW}⚠${NC} AGENTS.md not found in $SOURCE_DIR"
fi

echo ""
echo -e "${GREEN}✓ Files copied successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  cd $PROJECT_PATH"
echo "  git add .jules/ AGENTS.md"
echo "  git commit -m \"Add Jules hardware access\""
echo "  git push"
echo ""
echo -e "${BLUE}ℹ${NC} Jules will now be able to access your hardware when working on this project!"
