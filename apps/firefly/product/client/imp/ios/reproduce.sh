#!/bin/bash
# Reproduce the new-user sign-in flow for testing
# Resets Henry's device IDs, logs out, restarts app, and runs through sign-in

set -e

echo "🔄 Clearing Henry's profile content (keeping just name)..."
ssh microserver@185.96.221.52 "psql -d firefly -c \"UPDATE posts SET summary = '', body = '', image_url = NULL WHERE template_name = 'profile' AND user_id = (SELECT id FROM users WHERE email = 'henry@example.com');\""

echo "🔄 Resetting Henry's device IDs on server..."
ssh microserver@185.96.221.52 "psql -d firefly -c \"UPDATE users SET device_ids = '{}' WHERE email = 'henry@example.com';\""

echo "🔄 Restarting port forwarding..."
pkill -f "pymobiledevice3.*forward" 2>/dev/null || true
sleep 1
pymobiledevice3 usbmux forward -d 8081 8081
sleep 2

echo "🔄 Clearing login state..."
curl -s http://localhost:8081/test/clear-login
echo ""

echo "🔄 Stopping and restarting app..."
./stop-app.sh 2>&1 | tail -1
sleep 1
./restart-app.sh 2>&1

echo "⏳ Waiting for app to start..."
sleep 3

echo "📧 Entering email..."
curl -s -X POST 'http://localhost:8081/test/set-text?id=signin-email&text=henry@example.com'
echo ""

echo "🔘 Tapping login..."
curl -s -X POST 'http://localhost:8081/test/tap?id=signin-login'
echo ""

sleep 1.5

echo "🔢 Entering code 1324..."
curl -s -X POST 'http://localhost:8081/test/set-text?id=signin-code&text=1324'
echo ""

echo "🔘 Tapping verify..."
curl -s -X POST 'http://localhost:8081/test/tap?id=signin-verify'
echo ""

sleep 1.5

echo "🚀 Tapping get started..."
curl -s -X POST 'http://localhost:8081/test/tap?id=newuser-getstarted'
echo ""

echo "✅ Flow complete! Check logs for editCurrentUserProfile behavior."
