#!/bin/bash
set -e

APP="zzwitch.app"

# Kill running instance if any
killall zzwitch 2>/dev/null || true

# Clean previous build
rm -rf "$APP" zzwitch generate_icon AppIcon.iconset AppIcon.icns

# Generate app icon
swiftc -framework Cocoa GenerateIcon.swift -o generate_icon
./generate_icon
iconutil -c icns AppIcon.iconset -o AppIcon.icns

# Compile main app
swiftc -framework Cocoa -framework ServiceManagement zzwitch.swift -o zzwitch

# Create bundle structure
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp zzwitch      "$APP/Contents/MacOS/zzwitch"
cp Info.plist   "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign
codesign --force --deep --sign - "$APP"

# Strip quarantine (prevents TCC from ignoring the app)
xattr -cr "$APP"

# Reset TCC entry so macOS re-evaluates the new binary's signature
tccutil reset Accessibility com.local.zzwitch 2>/dev/null || true

echo "Built: $APP"
echo ""
echo "Run with: open $APP"
echo "Note: grant Accessibility permission when prompted — no restart needed."
