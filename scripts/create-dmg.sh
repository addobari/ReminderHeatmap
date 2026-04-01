#!/bin/bash
set -euo pipefail

# Create a DMG for Plotted.app
# Usage: ./scripts/create-dmg.sh [path/to/Plotted.app] [output.dmg]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

APP_PATH="${1:-}"
OUTPUT_DMG="${2:-$PROJECT_DIR/build/Plotted.dmg}"

if [ -z "$APP_PATH" ]; then
    # Try to find the app in the build directory
    APP_PATH="$PROJECT_DIR/build/Build/Products/Release/Plotted.app"
    if [ ! -d "$APP_PATH" ]; then
        echo "Error: Plotted.app not found. Pass the path as first argument."
        echo "Usage: $0 path/to/Plotted.app [output.dmg]"
        exit 1
    fi
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH does not exist"
    exit 1
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_DMG")"

# Clean up any previous DMG
rm -f "$OUTPUT_DMG"

APP_NAME="Plotted"
DMG_TEMP="$PROJECT_DIR/build/dmg-staging"
VOLUME_NAME="$APP_NAME"

echo "==> Creating DMG for $APP_NAME..."

# Clean and create staging directory
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to staging
cp -a "$APP_PATH" "$DMG_TEMP/$APP_NAME.app"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# Calculate size (app size + 10MB padding)
APP_SIZE_KB=$(du -sk "$DMG_TEMP" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 10240))

# Create temporary writable DMG
TEMP_DMG="$PROJECT_DIR/build/temp.dmg"
rm -f "$TEMP_DMG"
hdiutil create -size "${DMG_SIZE_KB}k" -fs HFS+ -volname "$VOLUME_NAME" -ov "$TEMP_DMG"

# Mount and populate
MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')
cp -a "$DMG_TEMP/$APP_NAME.app" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

# Set Finder view options via AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 400}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "$APP_NAME.app" of container window to {125, 150}
        set position of item "Applications" of container window to {375, 150}
        close
    end tell
end tell
EOF

# Give Finder time to write .DS_Store
sleep 2

# Unmount
hdiutil detach "$MOUNT_POINT" -force

# Convert to compressed read-only DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$DMG_TEMP"

echo "==> DMG created: $OUTPUT_DMG"
echo "    Size: $(du -h "$OUTPUT_DMG" | cut -f1)"
