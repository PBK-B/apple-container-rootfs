#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Usage: install-rootfs-plugin.sh [install-root] [build-root]

Examples:
  ./scripts/install-rootfs-plugin.sh
  ./scripts/install-rootfs-plugin.sh /usr/local
  ./scripts/install-rootfs-plugin.sh /usr/local .build/arm64-apple-macosx/debug
EOF
}

detect_install_root() {
    if command -v container >/dev/null 2>&1; then
        status_output=$(container system status 2>/dev/null || true)
        install_root=$(printf '%s\n' "$status_output" | sed -n 's/^installRoot[[:space:]]*//p' | sed -n '1p')
        if [ -n "$install_root" ]; then
            printf '%s\n' "${install_root%/}"
            return 0
        fi

        container_path=$(command -v container)
        if [ -n "$container_path" ]; then
            resolved_container=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$container_path" 2>/dev/null || true)
            if [ -n "$resolved_container" ]; then
                printf '%s\n' "$(dirname "$(dirname "$resolved_container")")"
                return 0
            fi
        fi
    fi

    if command -v brew >/dev/null 2>&1; then
        brew_prefix=$(brew --prefix container 2>/dev/null || true)
        if [ -n "$brew_prefix" ]; then
            resolved_prefix=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$brew_prefix" 2>/dev/null || true)
            if [ -n "$resolved_prefix" ]; then
                printf '%s\n' "$resolved_prefix"
                return 0
            fi
        fi
    fi

    printf '%s\n' "/usr/local"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_ROOT="${1:-$(detect_install_root)}"
BUILD_ROOT="${2:-$SCRIPT_DIR/../.build/arm64-apple-macosx/debug}"
PLUGIN_NAME="rootfs"
PLUGIN_ROOT="$INSTALL_ROOT/libexec/container-plugins/$PLUGIN_NAME"
BIN_DIR="$PLUGIN_ROOT/bin"
SOURCE_BINARY="$BUILD_ROOT/$PLUGIN_NAME"
SOURCE_CONFIG="$SCRIPT_DIR/../Sources/Plugins/Rootfs/config.toml"
ENTITLEMENTS_PLIST="$SCRIPT_DIR/../entitlements.plist"

if [ ! -d "$BUILD_ROOT" ]; then
    printf '%s\n' "error: build root not found: $BUILD_ROOT" >&2
    exit 1
fi

if [ ! -f "$SOURCE_BINARY" ]; then
    printf '%s\n' "error: built binary not found: $SOURCE_BINARY" >&2
    printf '%s\n' "hint: run 'DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun swift build' first" >&2
    exit 1
fi

if [ ! -f "$SOURCE_CONFIG" ]; then
    printf '%s\n' "error: plugin config not found: $SOURCE_CONFIG" >&2
    exit 1
fi

mkdir -p "$BIN_DIR"
cp "$SOURCE_BINARY" "$BIN_DIR/$PLUGIN_NAME"
cp "$SOURCE_CONFIG" "$PLUGIN_ROOT/config.toml"
chmod 755 "$BIN_DIR/$PLUGIN_NAME"

if [ -f "$ENTITLEMENTS_PLIST" ]; then
    codesign --force --sign - --entitlements "$ENTITLEMENTS_PLIST" "$BIN_DIR/$PLUGIN_NAME"
fi

printf '%s\n' "Installed $PLUGIN_NAME plugin to $PLUGIN_ROOT"
