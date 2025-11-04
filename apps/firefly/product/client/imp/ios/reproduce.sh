#!/bin/bash

# Reproduce script - builds, deploys, and runs automated test sequence
# This script can be updated for different test scenarios without changing install-device.sh

set -e

echo "🔄 Running reproduce script..."

# Install and launch the app
./install-device.sh

# Wait for app to start and load posts
echo "⏳ Waiting for app to start and load posts..."
sleep 5

# Tap the first post using UI automation
echo "👆 Tapping first post..."
RESPONSE=$(curl -s -X POST "http://localhost:8081/test/tap?id=first-post")
echo "   Response: $RESPONSE"

# Wait a moment for expansion animation
sleep 1

echo "✅ Test sequence complete!"
echo ""
echo "📋 To view logs:"
echo "   ./get-logs.sh"
