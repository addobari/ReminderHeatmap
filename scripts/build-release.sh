#!/bin/bash
set -euo pipefail

# Build a release version of Plotted and create a DMG + ZIP for distribution.
# Usage: ./scripts/build-release.sh
#
# Prerequisites:
#   - xcodegen installed
#   - Sparkle EdDSA key in Keychain (run generate_keys first)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

cd "$PROJECT_DIR"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building release..."
mkdir -p "$BUILD_DIR"
xcodebuild \
    -project ReminderHeatmap.xcodeproj \
    -scheme ReminderHeatmap \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

APP_PATH="$BUILD_DIR/Build/Products/Release/Plotted.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed — Plotted.app not found"
    exit 1
fi

echo "==> App built at: $APP_PATH"

# Extract version info
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString)
BUILD=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion)
echo "    Version: $VERSION (build $BUILD)"

# Create ZIP for Sparkle updates
ZIP_NAME="Plotted-v${VERSION}.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
echo "==> Creating ZIP for Sparkle: $ZIP_NAME..."
cd "$BUILD_DIR/Build/Products/Release"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "Plotted.app" "$ZIP_PATH"
cd "$PROJECT_DIR"
echo "    ZIP: $ZIP_PATH"

# Create DMG for first-time download
DMG_NAME="Plotted-v${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
echo "==> Creating DMG: $DMG_NAME..."
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$DMG_PATH"

echo ""
echo "========================================="
echo "  Release build complete!"
echo "========================================="
echo "  Version:  $VERSION (build $BUILD)"
echo "  App:      $APP_PATH"
echo "  ZIP:      $ZIP_PATH"
echo "  DMG:      $DMG_PATH"
echo ""
echo "Next steps:"
echo "  1. Generate EdDSA keys (one-time):"
echo "     ./sparkle-bin/generate_keys"
echo ""
echo "  2. Add SUPublicEDKey to Info.plist (one-time):"
echo "     The public key output by generate_keys"
echo ""
echo "  3. Generate/update appcast.xml:"
echo "     ./sparkle-bin/generate_appcast $BUILD_DIR"
echo ""
echo "  4. Upload to GitHub Release:"
echo "     - $DMG_NAME (for download page)"
echo "     - $ZIP_NAME (for Sparkle updates)"
echo "     - appcast.xml (commit to repo root)"
echo "========================================="
