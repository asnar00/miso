# troubleshooting
*common Android/e/OS development issues and solutions*

This document covers common problems encountered during Android/e/OS development and their solutions.

## Build Issues

### "Unable to locate a Java Runtime"

**Problem**: Gradle can't find Java even though it's installed.

**Solution**:
```bash
# Find your Java installation
ls -la /opt/homebrew/opt/ | grep java

# Set JAVA_HOME
export JAVA_HOME="/opt/homebrew/opt/openjdk"

# Add to shell profile permanently
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk"' >> ~/.zshrc
source ~/.zshrc

# Verify
java -version
```

### "SDK location not found"

**Problem**: Gradle can't find Android SDK.

**Solution**:
Create `local.properties` in project root:
```properties
sdk.dir=/opt/homebrew/share/android-commandlinetools
```

Or set environment variable:
```bash
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
```

### "Failed to install the following Android SDK packages"

**Problem**: SDK components missing or license not accepted.

**Solution**:
```bash
# Accept licenses
mkdir -p $ANDROID_HOME/licenses
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license

# Or interactively
sdkmanager --licenses --sdk_root=$ANDROID_HOME
```

### AndroidX Migration Errors

**Problem**: "Manifest merger failed" or "package android.support does not exist".

**Solution**:
Create `gradle.properties` with:
```properties
android.useAndroidX=true
android.enableJetifier=true
```

## Device Connection Issues

### "no devices/emulators found"

**Problem**: ADB can't see your device.

**Solutions**:
```bash
# 1. Check USB cable (must support data, not just charging)
# 2. Enable USB debugging on device:
#    Settings → About Phone → tap Build Number 7 times
#    Settings → Developer Options → USB Debugging

# 3. Restart ADB
adb kill-server
adb start-server
adb devices

# 4. Check device authorization
# Accept "Allow USB debugging" prompt on device
```

### "device unauthorized"

**Problem**: Device not authorized for debugging.

**Solution**:
1. Check device screen for authorization prompt
2. Accept "Allow USB debugging"
3. Check "Always allow from this computer"
4. If no prompt: `adb kill-server && adb start-server`

### "device offline"

**Problem**: ADB lost connection to device.

**Solution**:
```bash
# Restart ADB
adb kill-server
adb start-server

# Or reconnect USB cable
# Or restart device
```

## Installation Issues

### "INSTALL_FAILED_UPDATE_INCOMPATIBLE"

**Problem**: Signature mismatch with existing installation.

**Solution**:
```bash
# Uninstall existing app
adb uninstall com.miso.noobtest

# Then install again
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### "INSTALL_FAILED_INSUFFICIENT_STORAGE"

**Problem**: Not enough storage on device.

**Solution**:
- Free up space on device
- Uninstall unused apps
- Clear app data/cache

### "INSTALL_PARSE_FAILED_MANIFEST_MALFORMED"

**Problem**: AndroidManifest.xml has errors.

**Solution**:
- Check manifest syntax
- Verify package name is valid (lowercase, dots, no special chars)
- Check for duplicate activities/permissions

## Runtime Issues

### App crashes immediately after launch

**Check logs**:
```bash
adb logcat | grep "AndroidRuntime"
```

**Common causes**:
- Missing permissions in manifest
- Unhandled exception in onCreate()
- Missing dependencies

### "java.lang.SecurityException: Permission denied"

**Problem**: App trying to use permission not declared in manifest.

**Solution**:
Add permission to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### Network requests fail

**Problem**: Cleartext HTTP traffic blocked.

**Solution**:
Add network security configuration (see `setup/network-security-config.md`).

## Gradle Build Performance

### Slow builds

**Solutions**:
```properties
# Add to gradle.properties
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.jvmargs=-Xmx2048m
```

### "Out of memory" during build

**Solution**:
Increase Gradle heap size in `gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=512m
```

## Logcat Issues

### No logs appearing

**Solutions**:
```bash
# 1. Clear log buffer
adb logcat -c

# 2. Check log level
adb logcat *:V  # Show all levels

# 3. Check device connection
adb devices

# 4. Verify app is running
adb shell pidof com.miso.noobtest
```

### Too many logs

**Filter by package**:
```bash
adb logcat | grep "com.miso.noobtest"
```

**Filter by tag**:
```bash
adb logcat -s YourTag
```

## e/OS Specific Issues

### e/OS compatibility

**Note**: e/OS is fully compatible with standard Android development. There are no special e/OS-specific issues - all Android tools and workflows work identically.

### Privacy features

e/OS includes enhanced privacy features, but they don't affect development mode. USB debugging and ADB work normally.

## Getting Help

If you encounter issues not covered here:

1. Check full error message in terminal
2. Search error on Stack Overflow
3. Check Android documentation
4. Verify environment variables are set correctly
5. Try with a clean project from template

## Environment Checklist

Before reporting issues, verify:

```bash
# Java
echo $JAVA_HOME
java -version

# Android SDK
echo $ANDROID_HOME
adb --version

# Device
adb devices

# Gradle
./gradlew --version
```

All of these should work without errors.
