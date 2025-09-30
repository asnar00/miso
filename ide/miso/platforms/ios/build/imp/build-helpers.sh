#!/bin/bash

# Helper functions for iOS building

# Get the first available simulator matching name pattern
get_simulator() {
    local name_pattern="${1:-iPhone}"
    xcrun simctl list devices available | grep "$name_pattern" | head -1 | sed -n 's/.*(\([^)]*\)).*/\1/p'
}

# Get physical device ID for xcodebuild
get_physical_device() {
    local project="$1"
    local scheme="$2"

    xcodebuild -project "$project" -scheme "$scheme" -showdestinations 2>&1 | \
        grep "platform:iOS," | \
        grep -v "Simulator" | \
        grep -v "placeholder" | \
        head -1 | \
        sed -n 's/.*id:\([^,}]*\).*/\1/p' | \
        tr -d ' '
}

# Build for simulator
build_for_simulator() {
    local project="$1"
    local scheme="$2"
    local simulator="${3:-iPhone 17 Pro}"

    echo "Building for simulator: $simulator"
    xcodebuild -project "$project" \
        -scheme "$scheme" \
        -destination "platform=iOS Simulator,name=$simulator" \
        LD="clang" \
        build
}

# Build for physical device
build_for_device() {
    local project="$1"
    local scheme="$2"
    local device_id="$3"

    if [ -z "$device_id" ]; then
        device_id=$(get_physical_device "$project" "$scheme")
    fi

    if [ -z "$device_id" ]; then
        echo "❌ No physical device found"
        return 1
    fi

    echo "Building for device: $device_id"
    xcodebuild -project "$project" \
        -scheme "$scheme" \
        -destination "id=$device_id" \
        -allowProvisioningUpdates \
        LD="clang" \
        build
}

# Archive for distribution
archive_for_distribution() {
    local project="$1"
    local scheme="$2"
    local archive_path="${3:-/tmp/${scheme}.xcarchive}"

    echo "Archiving to: $archive_path"
    xcodebuild -project "$project" \
        -scheme "$scheme" \
        -destination 'generic/platform=iOS' \
        -archivePath "$archive_path" \
        LD="clang" \
        -allowProvisioningUpdates \
        archive
}

# Clean build artifacts
clean_build() {
    local project="$1"
    local scheme="$2"

    echo "Cleaning build artifacts"
    xcodebuild -project "$project" \
        -scheme "$scheme" \
        clean
}

# Example usage:
if [ "$0" = "$BASH_SOURCE" ]; then
    echo "iOS Build Helpers"
    echo ""
    echo "Source this file to use these functions:"
    echo "  source build-helpers.sh"
    echo ""
    echo "Available functions:"
    echo "  get_simulator [pattern]"
    echo "  get_physical_device <project> <scheme>"
    echo "  build_for_simulator <project> <scheme> [simulator]"
    echo "  build_for_device <project> <scheme> [device_id]"
    echo "  archive_for_distribution <project> <scheme> [archive_path]"
    echo "  clean_build <project> <scheme>"
fi