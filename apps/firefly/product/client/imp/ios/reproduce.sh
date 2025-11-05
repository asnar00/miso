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

# Wait for expansion animation
echo "⏳ Waiting for expansion animation..."
sleep 2

# Tap the edit button
echo "✏️  Tapping edit button..."
RESPONSE=$(curl -s -X POST "http://localhost:8081/test/tap?id=edit-button")
echo "   Response: $RESPONSE"

# Wait for edit mode to activate
echo "⏳ Waiting for edit mode..."
sleep 1

# Tap the delete image button
echo "🗑️  Tapping delete image button..."
RESPONSE=$(curl -s -X POST "http://localhost:8081/test/tap?id=delete-image-button")
echo "   Response: $RESPONSE"

# Wait for layout to update
echo "⏳ Waiting for layout to update..."
sleep 1

# Take a screenshot
echo "📸 Taking screenshot..."
/Users/asnaroo/Desktop/experiments/miso/miso/platforms/ios/development/screen-capture/imp/screenshot.sh /tmp/delete-image-test.png

echo "✅ Test sequence complete!"
echo ""
echo "📸 Screenshot saved to: /tmp/delete-image-test.png"
echo ""
echo "📋 To view logs:"
echo "   ./get-logs.sh"
