#!/bin/bash

echo "Pre-deployment Checklist:"
echo "------------------------"

# Check environment variables
if [ -f .env ]; then
    echo "✓ .env file exists"
else
    echo "✗ .env file missing"
    exit 1
fi

# Check required tools
if command -v forge &> /dev/null; then
    echo "✓ forge installed"
else
    echo "✗ forge not found"
    exit 1
fi

# Check contract size
forge build --sizes
echo "------------------------"

# Run tests
echo "Running tests..."
forge test -vv

# Run coverage check
forge coverage

# Run slither if installed
if command -v slither &> /dev/null; then
    echo "Running Slither analysis..."
    slither .
fi

echo "------------------------"
echo "Ready for deployment!"