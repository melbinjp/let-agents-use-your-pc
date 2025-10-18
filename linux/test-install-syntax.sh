#!/bin/bash

# Test script to validate the enhanced Linux installation script syntax

set -euo pipefail

echo "Testing Linux installation script syntax..."

# Check bash syntax
if bash -n linux/install.sh; then
    echo "✓ install.sh syntax check passed"
else
    echo "✗ install.sh syntax check failed"
    exit 1
fi

# Check connection-info.sh syntax
if bash -n linux/connection-info.sh; then
    echo "✓ connection-info.sh syntax check passed"
else
    echo "✗ connection-info.sh syntax check failed"
    exit 1
fi

# Check for common issues
echo "Checking for common script issues..."

# Check if/fi balance
if_count=$(grep -c "^[[:space:]]*if " linux/install.sh || echo 0)
fi_count=$(grep -c "^[[:space:]]*fi[[:space:]]*$" linux/install.sh || echo 0)

echo "Found $if_count 'if' statements and $fi_count 'fi' statements in install.sh"

if [ "$if_count" -ne "$fi_count" ]; then
    echo "✗ Unbalanced if/fi statements in install.sh"
    exit 1
else
    echo "✓ Balanced if/fi statements in install.sh"
fi

# Check for function definitions
function_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" linux/install.sh || echo 0)
echo "Found $function_count function definitions in install.sh"

# Check for error handling
error_calls=$(grep -c "error " linux/install.sh || echo 0)
echo "Found $error_calls error handling calls in install.sh"

if [ "$error_calls" -lt 10 ]; then
    echo "⚠ Consider adding more error handling"
else
    echo "✓ Good error handling coverage"
fi

echo "All syntax checks passed!"