#!/bin/bash

# TestFlight Deployment Script for NoobTest
# This script builds, archives, exports, and uploads the app to TestFlight

set -e  # Exit on error

echo "🚀 Starting TestFlight deployment for NoobTest..."

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="NoobTest"
SCHEME="NoobTest"
ARCHIVE_PATH="/tmp/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="/tmp/${PROJECT_NAME}Export"
EXPORT_OPTIONS="${PROJECT_DIR}/ExportOptions.plist"

# Check if API key is configured
if [ -z "$APP_STORE_CONNECT_API_KEY_PATH" ]; then
    echo "⚠️  Warning: APP_STORE_CONNECT_API_KEY_PATH not set"
    echo "To automate uploads, you need to:"
    echo "1. Create an API key in App Store Connect (Users & Access > Keys)"
    echo "2. Download the .p8 file"
    echo "3. Set these environment variables:"
    echo "   export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXXXX.p8"
    echo "   export APP_STORE_CONNECT_API_KEY_ID=XXXXXXXXXX"
    echo "   export APP_STORE_CONNECT_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    echo ""
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# Build and archive
echo "📦 Building and archiving..."
xcodebuild -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    LD="clang" \
    -allowProvisioningUpdates

echo "✅ Archive created successfully"

# Create export options if it doesn't exist
if [ ! -f "$EXPORT_OPTIONS" ]; then
    echo "📝 Creating ExportOptions.plist..."
    cat > "$EXPORT_OPTIONS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store</string>
	<key>teamID</key>
	<string>226X782N9K</string>
	<key>uploadBitcode</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
EOF
fi

# Export archive
echo "📤 Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

echo "✅ Export completed: ${EXPORT_PATH}/${PROJECT_NAME}.ipa"

# Upload to TestFlight if API keys are configured
if [ -n "$APP_STORE_CONNECT_API_KEY_PATH" ] && \
   [ -n "$APP_STORE_CONNECT_API_KEY_ID" ] && \
   [ -n "$APP_STORE_CONNECT_API_ISSUER_ID" ]; then
    echo "☁️  Uploading to App Store Connect..."
    xcrun altool --upload-app \
        --type ios \
        --file "${EXPORT_PATH}/${PROJECT_NAME}.ipa" \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
    echo "✅ Upload completed! Check App Store Connect for processing status."
    echo "📱 Once processed, the build will be available in TestFlight."
else
    echo "⏸️  Skipping upload (API keys not configured)"
    echo "To upload manually, run:"
    echo "open -a 'Transporter' '${EXPORT_PATH}/${PROJECT_NAME}.ipa'"
fi

echo ""
echo "🎉 Deployment process complete!"
echo "IPA location: ${EXPORT_PATH}/${PROJECT_NAME}.ipa"