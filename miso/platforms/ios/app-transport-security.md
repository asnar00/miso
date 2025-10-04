# App Transport Security
*Configuring network security for iOS apps*

App Transport Security (ATS) is Apple's security feature that enforces secure network connections in iOS apps.

## Default Behavior

By default, iOS apps can only make network requests using HTTPS with specific security requirements:
- TLS 1.2 or higher
- Forward secrecy ciphers
- Valid certificates from trusted authorities
- SHA-256 or better certificate signatures

**HTTP connections are blocked by default.**

## Why Configure ATS

You need to configure ATS when:
- **Development/Testing**: Connecting to local servers without HTTPS
- **Legacy Systems**: APIs that don't support modern TLS
- **Third-party Services**: External services with weaker security

**Warning**: Weakening ATS reduces security. Only do this when necessary and document why.

## Configuration Location

ATS is configured in the app's `Info.plist` file.

## Allow All Insecure Connections (Development Only)

For development and testing, allow all HTTP connections:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Use case**: Local development servers, internal testing  
**Risk**: App can connect to any HTTP endpoint (insecure)  
**Production**: Never ship to App Store with this setting

## Allow Specific Domains

Better approach: Allow specific domains while keeping ATS for others:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Use case**: Specific legacy API that doesn't support HTTPS  
**Risk**: Limited to specified domains only  
**Production**: Acceptable if documented and necessary

## Allow Local Networking

For localhost connections during development:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

**Use case**: Connecting to services on 127.0.0.1 or local network  
**Risk**: Only affects local connections  
**Production**: Safe for apps that need local network features

## Example: Firefly Test App

Our test app uses `NSAllowsArbitraryLoads` for development:

**File**: `NoobTest/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Other keys... -->
    
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
```

**Why**: Connects to development server at `http://185.96.221.52:8080`  
**Future**: Should use HTTPS with valid certificate in production

## Viewing Info.plist in Xcode

1. Open project in Xcode
2. Select `Info.plist` in Project Navigator
3. Right-click → Open As → Source Code (to see XML)
4. Or use property list editor view for GUI editing

## Testing ATS Configuration

### Check if HTTP works:
```swift
let url = URL(string: "http://example.com")!
URLSession.shared.dataTask(with: url) { data, response, error in
    if let error = error {
        print("Error: \(error)") // ATS blocks will show here
    }
}
```

### ATS error example:
```
Error: The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.
```

## App Store Review

Apple reviews ATS configurations:
- `NSAllowsArbitraryLoads`: Requires justification in App Store submission
- Must explain why HTTPS isn't possible
- May be rejected if not justified
- Domain-specific exceptions are more acceptable

## Best Practices

1. **Use HTTPS whenever possible**
2. **Minimize exceptions**: Only disable ATS for specific domains
3. **Document reasons**: Why is HTTP necessary?
4. **Transition plan**: When will you move to HTTPS?
5. **Production vs Development**: Use different Info.plist or build configurations
6. **Test both**: Verify app works with and without ATS

## Migration Strategy

For production apps, use build configurations:

### Development Configuration
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Production Configuration
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.production.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionReasons</key>
            <string>Legacy API being migrated to HTTPS Q2 2025</string>
        </dict>
    </dict>
</dict>
```

## Resources

- [Apple ATS Documentation](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
- [App Store Review Guidelines - Section 2.5.3](https://developer.apple.com/app-store/review/guidelines/#software-requirements)
- WWDC Sessions on ATS and network security
