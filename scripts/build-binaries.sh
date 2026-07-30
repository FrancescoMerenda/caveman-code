#!/usr/bin/env bash
#
# Build cave binaries for all platforms locally.
# Mirrors .github/workflows/build-binaries.yml
#
# Usage:
#   ./scripts/build-binaries.sh [--skip-deps] [--platform <platform>]
#
# Options:
#   --skip-deps         Skip installing cross-platform dependencies
#   --platform <name>   Build only for specified platform (darwin-arm64, darwin-x64, linux-x64, linux-arm64, windows-x64)
#
# Output:
#   packages/coding-agent/binaries/
#     cave-darwin-arm64.tar.gz
#     cave-darwin-x64.tar.gz
#     cave-linux-x64.tar.gz
#     cave-linux-arm64.tar.gz
#     cave-windows-x64.zip

set -euo pipefail

cd "$(dirname "$0")/.."

SKIP_DEPS=false
PLATFORM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate platform if specified
if [[ -n "$PLATFORM" ]]; then
    case "$PLATFORM" in
        darwin-arm64|darwin-x64|linux-x64|linux-arm64|windows-x64)
            ;;
        *)
            echo "Invalid platform: $PLATFORM"
            echo "Valid platforms: darwin-arm64, darwin-x64, linux-x64, linux-arm64, windows-x64"
            exit 1
            ;;
    esac
fi

echo "==> Installing dependencies..."
bun install --frozen-lockfile

if [[ "$SKIP_DEPS" == "false" ]]; then
    echo "==> Installing cross-platform native bindings..."
    # A normal install only unpacks the optional deps matching the host
    # platform. Bun cross-compilation needs every target's bindings, so
    # --os='*' --cpu='*' bypasses the os/cpu gates in those packages.
    # --no-save keeps package.json/bun.lock untouched.
    # Install all in one command to avoid removing packages from previous installs.
    bun add --no-save --os='*' --cpu='*' \
        @mariozechner/clipboard-darwin-arm64@0.3.0 \
        @mariozechner/clipboard-darwin-x64@0.3.0 \
        @mariozechner/clipboard-linux-x64-gnu@0.3.0 \
        @mariozechner/clipboard-linux-arm64-gnu@0.3.0 \
        @mariozechner/clipboard-win32-x64-msvc@0.3.0 \
        @img/sharp-darwin-arm64@0.34.5 \
        @img/sharp-darwin-x64@0.34.5 \
        @img/sharp-linux-x64@0.34.5 \
        @img/sharp-linux-arm64@0.34.5 \
        @img/sharp-win32-x64@0.34.5 \
        @img/sharp-libvips-darwin-arm64@1.2.4 \
        @img/sharp-libvips-darwin-x64@1.2.4 \
        @img/sharp-libvips-linux-x64@1.2.4 \
        @img/sharp-libvips-linux-arm64@1.2.4
else
    echo "==> Skipping cross-platform native bindings (--skip-deps)"
fi

echo "==> Building all packages..."
bun run build

echo "==> Building binaries..."
cd packages/coding-agent

# Clean previous builds
rm -rf binaries
mkdir -p binaries/{darwin-arm64,darwin-x64,linux-x64,linux-arm64,windows-x64}

# Determine which platforms to build
if [[ -n "$PLATFORM" ]]; then
    PLATFORMS=("$PLATFORM")
else
    PLATFORMS=(darwin-arm64 darwin-x64 linux-x64 linux-arm64 windows-x64)
fi

for platform in "${PLATFORMS[@]}"; do
    echo "Building for $platform..."
    # Externalize koffi to avoid embedding all 18 platform .node files (~74MB)
    # into every binary. Koffi is only used on Windows for VT input and the
    # call site has a try/catch fallback. For Windows builds, we copy the
    # appropriate .node file alongside the binary below.
    if [[ "$platform" == "windows-x64" ]]; then
        bun build --compile --external koffi --target=bun-$platform ./dist/bun/cli.js --outfile binaries/$platform/cave.exe
    else
        bun build --compile --external koffi --target=bun-$platform ./dist/bun/cli.js --outfile binaries/$platform/cave
    fi
done

echo "==> Creating release archives..."

# Copy shared files to each platform directory
for platform in "${PLATFORMS[@]}"; do
    cp package.json binaries/$platform/
    cp README.md binaries/$platform/
    cp CHANGELOG.md binaries/$platform/
    bun ../../scripts/copy-binary-deps.mjs "binaries/$platform"
    mkdir -p binaries/$platform/theme
    cp dist/modes/interactive/theme/*.json binaries/$platform/theme/
    cp -r dist/core/export-html binaries/$platform/
    cp -r docs binaries/$platform/
    cp -r examples binaries/$platform/

    # Copy koffi native module for Windows (needed for VT input support)
    if [[ "$platform" == "windows-x64" ]]; then
        bun ../../scripts/copy-binary-deps.mjs "binaries/$platform" --koffi
    fi
done

# Create archives
cd binaries

for platform in "${PLATFORMS[@]}"; do
    if [[ "$platform" == "windows-x64" ]]; then
        # Windows (zip)
        echo "Creating cave-$platform.zip..."
        (cd $platform && zip -r ../cave-$platform.zip .)
    else
        # Unix platforms (tar.gz) - use wrapper directory for mise compatibility
        echo "Creating cave-$platform.tar.gz..."
        mv $platform cave && tar -czf cave-$platform.tar.gz cave && mv cave $platform
    fi
done

# Extract archives for easy local testing
echo "==> Extracting archives for testing..."
for platform in "${PLATFORMS[@]}"; do
    rm -rf $platform
    if [[ "$platform" == "windows-x64" ]]; then
        mkdir -p $platform && (cd $platform && unzip -q ../cave-$platform.zip)
    else
        tar -xzf cave-$platform.tar.gz && mv cave $platform
    fi
done

echo ""
echo "==> Build complete!"
echo "Archives available in packages/coding-agent/binaries/"
ls -lh *.tar.gz *.zip 2>/dev/null || true
echo ""
echo "Extracted directories for testing:"
for platform in "${PLATFORMS[@]}"; do
    echo "  binaries/$platform/cave"
done
