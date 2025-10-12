#!/bin/bash
# List all registered devices that can be tested remotely

SERVER_URL="http://185.96.221.52:8080"

echo "Registered Devices:"
echo "========================================"
curl -s "$SERVER_URL/api/devices" | python3 -m json.tool
echo ""
echo "To test a device:"
echo "  ./test-feature-remote.sh ping <device-id>"
echo "  ./test-all-remote.sh <device-id>"
