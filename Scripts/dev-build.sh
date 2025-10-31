#!/bin/bash

# Development build script that creates a proper .app bundle for easier permission management

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
DEV_APP_DIR="$BUILD_DIR/TellMe-Dev.app"

echo "🔨 Building Tell me for development..."

defaults delete com.fmartingr.tellme hasShownPermissionOnboarding 2>/dev/null || echo "Onboarding status reset for new domain"

# Clean previous dev build
rm -rf "$DEV_APP_DIR"

# Build the executable
swift build -c debug

# Create app bundle structure
mkdir -p "$DEV_APP_DIR/Contents/MacOS"
mkdir -p "$DEV_APP_DIR/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/arm64-apple-macosx/debug/TellMe" "$DEV_APP_DIR/Contents/MacOS/TellMe"

# Create Info.plist
cat > "$DEV_APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TellMe</string>
    <key>CFBundleIdentifier</key>
    <string>com.fmartingr.tellme</string>
    <key>CFBundleName</key>
    <string>TellMe Dev</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0-dev</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0-dev</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Tell me needs microphone access to capture speech for transcription.</string>
</dict>
</plist>
EOF

# Copy resources if they exist
if [ -d "$PROJECT_DIR/Sources/App/Resources" ]; then
    # Copy non-localization resources
    find "$PROJECT_DIR/Sources/App/Resources" -maxdepth 1 -type f -exec cp {} "$DEV_APP_DIR/Contents/Resources/" \;

    # Copy localization files to the Resources directory
    find "$PROJECT_DIR/Sources/App/Resources" -maxdepth 1 -type d -name "*.lproj" -exec cp -R {} "$DEV_APP_DIR/Contents/Resources/" \; 2>/dev/null || true
fi

echo "✅ Development app bundle created at: $DEV_APP_DIR"
echo ""
echo "To run with proper permissions:"
echo "1. open '$DEV_APP_DIR'"
echo "2. Grant permissions in System Settings"
echo "3. Or run: '$DEV_APP_DIR/Contents/MacOS/TellMe'"
echo ""
echo "The app bundle makes it easier to grant permissions in System Settings."
