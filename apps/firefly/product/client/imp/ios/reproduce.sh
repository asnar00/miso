#!/bin/bash

set -e

echo "🔄 Testing undo button behavior..."

# Build and deploy
echo "📱 Installing app..."
./install-device.sh

# Wait for app to start and load posts
echo "⏳ Waiting for app to start and load posts (5 seconds)..."
sleep 5

# Expand first post
echo "👆 Tapping first-post to expand..."
RESULT=$(curl -s -X POST 'http://localhost:8081/test/tap?id=first-post')
echo "$RESULT"
if echo "$RESULT" | grep -q "error"; then
    echo "❌ first-post not found - posts may not have loaded yet"
    exit 1
fi
sleep 1

# Tap edit button
echo "✏️ Tapping edit button..."
RESULT=$(curl -s -X POST 'http://localhost:8081/test/tap?id=edit-button')
echo "$RESULT"
if echo "$RESULT" | grep -q "error"; then
    echo "❌ edit-button not found - post may not have expanded"
    exit 1
fi
sleep 1

# Tap undo/cancel button  
echo "↩️ Tapping cancel/undo button..."
RESULT=$(curl -s -X POST 'http://localhost:8081/test/tap?id=cancel-button')
echo "$RESULT"
sleep 2

# Get the logs
echo "📋 Getting logs..."
./get-logs.sh

echo ""
echo "=== Relevant log entries ==="
grep -E "Undo|onEndEditing|expandedPostId|first-post|edit-button|cancel-button|initialPosts" app.log | tail -50

echo ""
echo "✅ Test complete!"
