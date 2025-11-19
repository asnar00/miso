#!/bin/bash
# Sync tunable constants from device back to codebase

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON_FILE="$PROJECT_DIR/../../live-constants.json"

echo "📥 Fetching current tunable values from device..."
curl -s http://localhost:8081/tune | python3 -m json.tool > "$JSON_FILE"

echo "✅ Synced tunables to: $JSON_FILE"
echo ""
cat "$JSON_FILE"
