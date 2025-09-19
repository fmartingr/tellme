#!/bin/bash

# Build script for Tell me
# This script builds the project using Swift Package Manager

set -e

echo "🔨 Building Tell me..."

# Clean previous build
echo "🧹 Cleaning previous build..."
swift package clean

# Build in release mode
echo "⚡ Building in release mode..."
swift build -c release

# Run tests
echo "🧪 Running tests..."
swift test

# Check if SwiftFormat is available and run it
if command -v swiftformat >/dev/null 2>&1; then
    echo "📝 Checking code formatting..."
    swiftformat --lint .
else
    echo "⚠️  SwiftFormat not available, skipping format check"
fi

# Check if SwiftLint is available and run it
if command -v swiftlint >/dev/null 2>&1; then
    echo "🔍 Running SwiftLint..."
    swiftlint
else
    echo "⚠️  SwiftLint not available, skipping lint check"
fi

echo "✅ Build completed successfully!"