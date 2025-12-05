#!/bin/bash
# Sync live-constants.json from source of truth to iOS bundle
# Source: apps/firefly/product/client/live-constants.json
# Destination: apps/firefly/product/client/imp/ios/NoobTest/live-constants.json

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/../../live-constants.json"
DEST="$SCRIPT_DIR/NoobTest/live-constants.json"

if [ -f "$SOURCE" ]; then
    cp "$SOURCE" "$DEST"
    echo "✅ Synced live-constants.json to iOS bundle"
else
    echo "❌ Source file not found: $SOURCE"
    exit 1
fi
