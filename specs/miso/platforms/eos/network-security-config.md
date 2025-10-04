# Network Security Configuration
*Configuring network security for Android/e/OS apps*

Android's Network Security Configuration controls which network connections apps can make, similar to iOS App Transport Security.

## Default Behavior (Android 9+)

Starting with Android 9 (API level 28), cleartext (HTTP) traffic is **blocked by default**:
- Only HTTPS connections allowed
- Apps must use TLS encryption
- Plain HTTP connections fail with error

**Error**: `CLEARTEXT communication not permitted by network security policy`

## Why Configure Network Security

You need to configure network security when:
- **Development/Testing**: Connecting to local HTTP servers
- **Legacy APIs**: Backend services without HTTPS
- **Mixed Content**: Some endpoints use HTTP

**Warning**: Allowing cleartext reduces security. Only use when necessary.

## Configuration Location

Network security is configured in:
1. **XML file**: `res/xml/network_security_config.xml` (you create this)
2. **Manifest reference**: `AndroidManifest.xml` points to the config

## Setup Steps

### 1. Create Configuration File

**File**: `app/src/main/res/xml/network_security_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

**Note**: Create the `res/xml/` directory if it doesn't exist

### 2. Reference in Manifest

**File**: `app/src/main/AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <application
        android:networkSecurityConfig="@xml/network_security_config"
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
        
        <!-- activities... -->
        
    </application>
</manifest>
```

## Configuration Options

### Allow All Cleartext (Development)

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

**Use case**: Development/testing with HTTP servers  
**Risk**: App can connect to any HTTP endpoint  
**Production**: Avoid shipping with this setting

### Allow Specific Domains Only

```xml
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">example.com</domain>
        <domain>192.168.1.76</domain>
    </domain-config>
</network-security-config>
```

**Use case**: Specific legacy API or local server  
**Risk**: Limited to specified domains only  
**Production**: More acceptable for specific needs

### Debug vs Release

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

**Use case**: HTTPS in production, flexible in debug builds  
**Benefit**: Security by default, convenience in development

## Example: Firefly Test App

Our test app allows all cleartext for development:

**File**: `app/src/main/res/xml/network_security_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

**File**: `app/src/main/AndroidManifest.xml`

```xml
<application
    android:label="@string/app_name"
    android:icon="@mipmap/ic_launcher"
    android:networkSecurityConfig="@xml/network_security_config">
    <!-- ... -->
</application>
```

**Why**: Connects to development server at `http://185.96.221.52:8080`  
**Future**: Should use HTTPS with valid certificate in production

## Testing Configuration

### Test HTTP Connection

```kotlin
val client = OkHttpClient()
val request = Request.Builder()
    .url("http://example.com/api/test")
    .build()

client.newCall(request).execute().use { response ->
    if (!response.isSuccessful) {
        Log.e("Network", "Failed: ${response.code}")
    }
}
```

### Error Without Config

```
java.io.IOException: Cleartext HTTP traffic to example.com not permitted
```

### Success With Config

```
D/Network: Response code: 200
D/Network: Connection successful
```

## Directory Structure

```
app/
├── src/
│   └── main/
│       ├── AndroidManifest.xml
│       ├── res/
│       │   └── xml/
│       │       └── network_security_config.xml
│       └── kotlin/
│           └── ...
```

## Build Configuration

For different environments, use build variants:

**File**: `app/build.gradle.kts`

```kotlin
android {
    buildTypes {
        debug {
            // Uses debug config
        }
        release {
            // Could use different config file
            manifestPlaceholders["networkSecurityConfig"] = "@xml/network_security_config_prod"
        }
    }
}
```

## Common Errors

### Error: File not found
```
error: resource xml/network_security_config (aka com.example.app:xml/network_security_config) not found.
```
**Fix**: Create the file in `res/xml/` directory

### Error: Still blocked
```
CLEARTEXT communication to 192.168.1.76 not permitted
```
**Fix**: Check `android:networkSecurityConfig` is in `<application>` tag  
**Fix**: Verify domain matches exactly in config

### Error: Invalid XML
```
error: Error parsing XML: not well-formed
```
**Fix**: Check XML syntax, matching tags, proper encoding declaration

## Google Play Requirements

Google Play may flag apps with relaxed security:
- Apps with `cleartextTrafficPermitted="true"` may be reviewed
- Must justify why HTTPS isn't possible
- Domain-specific exceptions preferred
- Plan to migrate to HTTPS

## Best Practices

1. **HTTPS First**: Use HTTPS whenever possible
2. **Minimize Exceptions**: Only allow cleartext for specific domains
3. **Document Reasons**: Why is HTTP necessary?
4. **Environment-Specific**: Different configs for debug/release
5. **Transition Plan**: Timeline for moving to HTTPS
6. **Test Both**: Verify app works with and without cleartext

## Migration from Cleartext to HTTPS

```xml
<!-- Phase 1: Development (cleartext allowed) -->
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>

<!-- Phase 2: Transition (specific domains only) -->
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain>legacy-api.example.com</domain>
    </domain-config>
</network-security-config>

<!-- Phase 3: Production (HTTPS only) -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

## Advanced Features

### Custom Trust Anchors

```xml
<network-security-config>
    <domain-config>
        <domain>internal.company.com</domain>
        <trust-anchors>
            <certificates src="@raw/company_ca" />
        </trust-anchors>
    </domain-config>
</network-security-config>
```

### Certificate Pinning

```xml
<network-security-config>
    <domain-config>
        <domain>api.example.com</domain>
        <pin-set expiration="2025-12-31">
            <pin digest="SHA-256">base64encodedpublickeyhash==</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

## Resources

- [Android Network Security Config Documentation](https://developer.android.com/training/articles/security-config)
- [Android 9 Behavior Changes](https://developer.android.com/about/versions/pie/android-9.0-changes-28)
- Google Play security best practices
