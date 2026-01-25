#!/bin/bash

# Build script for Switchboard
# Builds using Swift Package Manager and creates a macOS .app bundle
# Uses only the Swift toolchain - XCode not required to build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
RESOURCES_DIR="$SCRIPT_DIR/switchboard/Resources"
CONFIGURATION="${1:-release}"  # Default to release, or use first argument (debug/release)
VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "1.0.0")

# Normalize configuration
if [[ "$CONFIGURATION" == "Release" ]] || [[ "$CONFIGURATION" == "release" ]]; then
    SWIFT_CONFIG="release"
    CONFIG_DIR="release"
elif [[ "$CONFIGURATION" == "Debug" ]] || [[ "$CONFIGURATION" == "debug" ]]; then
    SWIFT_CONFIG="debug"
    CONFIG_DIR="debug"
else
    echo "Unknown configuration: $CONFIGURATION"
    echo "Usage: ./build.sh [debug|release]"
    exit 1
fi

# Output paths
APP_NAME="Switchboard"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_OUT_DIR="$CONTENTS_DIR/Resources"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}🔨 Building Switchboard v$VERSION${NC}"
echo ""

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: Swift not found. Please install Swift toolchain.${NC}"
    echo "  Download from: https://swift.org/download/"
    exit 1
fi

SWIFT_VERSION=$(swift --version 2>&1 | head -n 1)
echo "Swift: $SWIFT_VERSION"
echo "Configuration: $SWIFT_CONFIG"
echo ""

# Step 1: Build with Swift Package Manager
echo -e "${YELLOW}⚙️  Compiling with Swift Package Manager...${NC}"

if [[ "$SWIFT_CONFIG" == "release" ]]; then
    swift build -c release 2>&1
else
    swift build 2>&1
fi

EXECUTABLE="$BUILD_DIR/$CONFIG_DIR/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo -e "${RED}Error: Build failed - executable not found at $EXECUTABLE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Compilation successful${NC}"
echo ""

# Step 2: Create .app bundle structure
echo -e "${YELLOW}📦 Creating application bundle...${NC}"

# Remove old bundle if exists
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_OUT_DIR"

# Copy executable
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist and update version
if [ -f "$RESOURCES_DIR/Info.plist" ]; then
    # Use sed to update version in Info.plist
    sed -e "s/<string>1.0.0<\/string>/<string>$VERSION<\/string>/" \
        "$RESOURCES_DIR/Info.plist" > "$CONTENTS_DIR/Info.plist"
else
    echo -e "${RED}Error: Info.plist not found at $RESOURCES_DIR/Info.plist${NC}"
    exit 1
fi

# Copy PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy app icon if it exists
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$RESOURCES_OUT_DIR/"
    echo "Copied AppIcon.icns"
else
    echo -e "${YELLOW}⚠ AppIcon.icns not found - run scripts/generate-icon.sh to create it${NC}"
fi

echo -e "${GREEN}✓ Bundle created${NC}"
echo ""

# Step 3: Code sign the app
echo -e "${YELLOW}🔏 Code signing...${NC}"

if [ -f "$RESOURCES_DIR/Switchboard.entitlements" ]; then
    # Sign with entitlements (ad-hoc signing with -)
    codesign --force --deep --sign - \
        --entitlements "$RESOURCES_DIR/Switchboard.entitlements" \
        "$APP_BUNDLE" 2>&1
    echo -e "${GREEN}✓ Code signed with entitlements${NC}"
else
    # Basic ad-hoc signing without entitlements
    codesign --force --deep --sign - "$APP_BUNDLE" 2>&1
    echo -e "${YELLOW}⚠ Code signed without entitlements (entitlements file not found)${NC}"
fi

echo ""

# Step 4: Verify the bundle
echo -e "${YELLOW}🔍 Verifying bundle...${NC}"

# Check codesign
if codesign --verify --verbose "$APP_BUNDLE" 2>&1; then
    echo -e "${GREEN}✓ Code signature valid${NC}"
else
    echo -e "${YELLOW}⚠ Code signature verification had warnings (may still work)${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Build succeeded!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Application: $APP_BUNDLE"
echo "Version: $VERSION"
echo ""
echo "To run the app:"
echo -e "  ${YELLOW}open \"$APP_BUNDLE\"${NC}"
echo ""
echo "To install to /Applications:"
echo -e "  ${YELLOW}cp -r \"$APP_BUNDLE\" /Applications/${NC}"
echo ""
