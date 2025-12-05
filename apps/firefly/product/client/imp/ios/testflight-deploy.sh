#!/bin/bash
# Complete TestFlight deployment: build, upload, wait for processing, distribute
# Usage: ./testflight-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== TestFlight Deployment Pipeline ==="

# Step 1: Sync tunables
echo ""
echo "📋 Step 1: Syncing tunables..."
./sync-tunables.sh

# Step 2: Increment build number (agvtool must run from directory containing .xcodeproj)
echo ""
echo "📈 Step 2: Incrementing build number..."
agvtool next-version -all
NEW_BUILD=$(agvtool what-version -terse)
echo "   New build number: $NEW_BUILD"

# Step 3: Build and archive
echo ""
echo "🔨 Step 3: Building and archiving..."
xcodebuild -project NoobTest.xcodeproj \
    -scheme NoobTest \
    -archivePath /tmp/NoobTest.xcarchive \
    -allowProvisioningUpdates \
    LD="clang" \
    archive | tail -5

echo "   ✅ Archive complete"

# Step 4: Export for App Store
echo ""
echo "📦 Step 4: Exporting for App Store..."
rm -rf /tmp/NoobTestExport
xcodebuild -exportArchive \
    -archivePath /tmp/NoobTest.xcarchive \
    -exportPath /tmp/NoobTestExport \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates | tail -3

echo "   ✅ Export complete"

# Step 5: Upload to TestFlight
echo ""
echo "📤 Step 5: Uploading to TestFlight..."
xcrun altool --upload-app \
    --type ios \
    --file /tmp/NoobTestExport/NoobTest.ipa \
    --apiKey "TF37RTPFSZ" \
    --apiIssuer "2e5cbf08-b1a5-4857-b013-30fb6eec002e" 2>&1 | grep -v "^$"

echo "   ✅ Upload complete"

# Step 6: Wait for processing
echo ""
echo "⏳ Step 6: Waiting for Apple to process build $NEW_BUILD..."
echo "   (This typically takes 5-15 minutes)"

MAX_WAIT=1200  # 20 minutes max
WAIT_INTERVAL=30
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check build status
    STATUS=$(python3 -c "
import subprocess
import requests

def get_token():
    result = subprocess.run(
        ['xcrun', 'altool', '--generate-jwt', '--apiKey', 'TF37RTPFSZ', '--apiIssuer', '2e5cbf08-b1a5-4857-b013-30fb6eec002e'],
        capture_output=True, text=True
    )
    return result.stderr.strip().split('\n')[-1].strip()

token = get_token()
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
resp = requests.get('https://api.appstoreconnect.apple.com/v1/builds?filter[app]=6753210931&filter[version]=$NEW_BUILD&limit=1', headers=headers)
data = resp.json().get('data', [])
if data:
    print(data[0]['attributes'].get('processingState', 'UNKNOWN'))
else:
    print('NOT_FOUND')
" 2>/dev/null)

    echo "   Status: $STATUS (elapsed: ${ELAPSED}s)"

    if [ "$STATUS" = "VALID" ]; then
        echo "   ✅ Build is ready!"
        break
    elif [ "$STATUS" = "INVALID" ]; then
        echo "   ❌ Build is invalid!"
        exit 1
    fi

    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "   ⚠️ Timeout waiting for processing. Try running distribute-testflight.py manually later."
    exit 1
fi

# Step 7: Distribute to beta group
echo ""
echo "🚀 Step 7: Distributing to external testers..."
python3 distribute-testflight.py

echo ""
echo "=== Deployment Complete ==="
echo "Build $NEW_BUILD is now available to external testers!"
