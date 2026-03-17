#!/bin/bash
set -euo pipefail

# BrewManager — Build, bundle, sign, and package as DMG
# Usage: ./Scripts/package.sh [--skip-build]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
BUNDLE_DIR="$PROJECT_DIR/dist/BrewManager.app"
DMG_DIR="$PROJECT_DIR/dist"
RESOURCES_DIR="$PROJECT_DIR/Resources"

VERSION=$(defaults read "$RESOURCES_DIR/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.1.0")
DMG_NAME="BrewManager-${VERSION}.dmg"

echo "==> BrewManager Packager v${VERSION}"
echo ""

# Step 1: Build release binary
if [[ "${1:-}" != "--skip-build" ]]; then
    echo "==> Building release binary..."
    cd "$PROJECT_DIR"
    swift build -c release 2>&1
    echo "    Binary: $BUILD_DIR/BrewManager"
else
    echo "==> Skipping build (--skip-build)"
fi

# Verify binary exists
if [[ ! -f "$BUILD_DIR/BrewManager" ]]; then
    echo "ERROR: Release binary not found at $BUILD_DIR/BrewManager"
    echo "       Run without --skip-build first."
    exit 1
fi

# Step 2: Create .app bundle structure
echo "==> Creating .app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/BrewManager" "$BUNDLE_DIR/Contents/MacOS/BrewManager"

# Copy Info.plist
cp "$RESOURCES_DIR/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

# Copy icon
if [[ -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
    echo "    Icon: AppIcon.icns"
else
    echo "    WARNING: No AppIcon.icns found, app will use default icon"
fi

# Write PkgInfo
echo -n "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

echo "    Bundle: $BUNDLE_DIR"

# Step 3: Ad-hoc code sign
echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "$RESOURCES_DIR/BrewManager.entitlements" \
    "$BUNDLE_DIR" 2>&1

# Verify signature
codesign --verify --deep --strict "$BUNDLE_DIR" 2>&1
echo "    Signature: valid"

# Step 4: Create DMG
echo "==> Creating DMG..."
rm -f "$DMG_DIR/$DMG_NAME"

# Create a temporary directory for DMG contents
DMG_TEMP="$DMG_DIR/dmg-staging"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy .app to staging
cp -R "$BUNDLE_DIR" "$DMG_TEMP/"

# Create symlink to /Applications for drag-install
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG from staging directory
hdiutil create \
    -volname "BrewManager" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_DIR/$DMG_NAME" 2>&1

# Clean up staging
rm -rf "$DMG_TEMP"

echo ""
echo "==> Done!"
echo "    .app:  $BUNDLE_DIR"
echo "    .dmg:  $DMG_DIR/$DMG_NAME"
echo "    Size:  $(du -sh "$DMG_DIR/$DMG_NAME" | cut -f1)"
echo ""
echo "    To install: Open the DMG and drag BrewManager to Applications."
echo "    First launch: Right-click > Open (ad-hoc signed, Gatekeeper prompt)"
