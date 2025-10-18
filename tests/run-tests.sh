#!/bin/bash

# Comprehensive Test Runner for Remote Hardware Access System
# This script runs the complete testing framework

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

# Source the main test framework
source "$SCRIPT_DIR/test-framework.sh"

# Make test framework executable
chmod +x "$SCRIPT_DIR/test-framework.sh"

# Make all test modules executable
find "$SCRIPT_DIR/modules" -name "*.sh" -exec chmod +x {} \;

# Run the test framework with all arguments passed through
exec "$SCRIPT_DIR/test-framework.sh" "$@"