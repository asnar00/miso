# code-signing
*certificates, provisioning profiles, and team IDs*

Code signing is required to run iOS apps on physical devices and distribute via TestFlight.

## Key Concepts

**Certificate**: Proves your identity as a developer
**Provisioning Profile**: Links your app's bundle ID to certificates and devices
**Team ID**: Your Apple Developer account identifier
**Bundle ID**: Unique identifier for your app (e.g., `com.yourname.appname`)

## Finding Your Team ID

```bash
security find-certificate -c "Apple Development" -p | \
    openssl x509 -text | \
    grep "OU=" | \
    head -1 | \
    sed 's/.*OU=\([^,]*\).*/\1/'
```

Output example: `226X782N9K`

## Finding Your Certificates

```bash
security find-identity -v -p codesigning
```

Shows available signing identities:
```
1) 657212482C5163396C7A8FF142E89523D68A463E "Apple Development: Your Name (XXXXXXXXX)"
```

## Automatic Provisioning

The easiest approach is automatic provisioning:

```bash
xcodebuild ... -allowProvisioningUpdates
```

This tells Xcode to:
1. Create provisioning profiles if needed
2. Register devices automatically
3. Update profiles when bundle ID or team changes

## Manual Configuration

In your Xcode project settings (project.pbxproj):

```
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = 226X782N9K;  // Your team ID
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.appname;
```

## Provisioning Profile Location

Automatically created profiles are stored at:
```
~/Library/Developer/Xcode/UserData/Provisioning Profiles/
```

## Common Issues

**"No signing certificate found"**:
- Log into Xcode with your Apple ID
- Let Xcode download certificates

**"No provisioning profile"**:
- Use `-allowProvisioningUpdates`
- Or manually create in App Store Connect

**"Team not found"**:
- Verify team ID with command above
- Ensure Apple ID is added to Xcode

## Distribution Signing

For TestFlight/App Store, different signing is used:
- **Development**: For testing on your devices
- **Distribution**: For App Store submission

The archive process automatically handles this when configured with automatic signing.