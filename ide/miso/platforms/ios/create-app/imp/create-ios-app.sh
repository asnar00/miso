#!/bin/bash

# Creates a new iOS SwiftUI app from command line
# Usage: ./create-ios-app.sh AppName com.yourname.appname

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 AppName com.yourname.bundleid [TeamID]"
    echo "Example: $0 MyApp com.example.myapp 226X782N9K"
    exit 1
fi

APP_NAME="$1"
BUNDLE_ID="$2"
TEAM_ID="${3:-}"

# Auto-detect team ID if not provided
if [ -z "$TEAM_ID" ]; then
    TEAM_ID=$(security find-certificate -c "Apple Development" -p | openssl x509 -text | grep "OU=" | head -1 | sed 's/.*OU=\([^,]*\).*/\1/')
    echo "Auto-detected Team ID: $TEAM_ID"
fi

echo "Creating iOS app: $APP_NAME"
echo "Bundle ID: $BUNDLE_ID"
echo "Team ID: $TEAM_ID"

# Create directory structure
mkdir -p "$APP_NAME/$APP_NAME/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$APP_NAME/$APP_NAME.xcodeproj"

# Create App entry point
cat > "$APP_NAME/$APP_NAME/${APP_NAME}App.swift" << EOF
import SwiftUI

@main
struct ${APP_NAME}App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

# Create ContentView
cat > "$APP_NAME/$APP_NAME/ContentView.swift" << EOF
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
                .font(.largeTitle)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
EOF

# Create Info.plist
cat > "$APP_NAME/$APP_NAME/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>\$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>\$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
</dict>
</plist>
EOF

# Create Assets.xcassets structure
cat > "$APP_NAME/$APP_NAME/Assets.xcassets/Contents.json" << EOF
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "$APP_NAME/$APP_NAME/Assets.xcassets/AppIcon.appiconset/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Create a simple placeholder icon (solid color)
# Note: For real apps, use the icon-generation script
cat > "$APP_NAME/$APP_NAME/Assets.xcassets/AppIcon.appiconset/icon.png.sh" << 'EOF'
# Placeholder - replace with actual icon generation
# See ../../../icon-generation/imp/make-icon.swift
EOF

# Copy project.pbxproj template and customize
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/project.pbxproj.template" ]; then
    sed -e "s/{{APP_NAME}}/$APP_NAME/g" \
        -e "s/{{BUNDLE_ID}}/$BUNDLE_ID/g" \
        -e "s/{{TEAM_ID}}/$TEAM_ID/g" \
        "$SCRIPT_DIR/project.pbxproj.template" > "$APP_NAME/$APP_NAME.xcodeproj/project.pbxproj"
else
    echo "Warning: project.pbxproj.template not found"
    echo "Copy from a working project like apps/firefly/test/imp/ios/NoobTest.xcodeproj/project.pbxproj"
fi

echo "✅ iOS app created at: $APP_NAME/"
echo ""
echo "Next steps:"
echo "1. Generate an icon: swift ../icon-generation/imp/make-icon.swift $APP_NAME/$APP_NAME/Assets.xcassets/AppIcon.appiconset/icon.png"
echo "2. Build: cd $APP_NAME && xcodebuild -project $APP_NAME.xcodeproj -scheme $APP_NAME -destination 'platform=iOS Simulator,name=iPhone 17 Pro' LD=clang build"
echo "3. See ../build.md for more build options"