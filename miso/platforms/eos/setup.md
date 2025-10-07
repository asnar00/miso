# setup
*installing Android development tools on macOS*

Before you can build Android/e/OS apps, you need to install the Android SDK, Java Development Kit, and Gradle build system.

## Prerequisites

**Homebrew** package manager for macOS (if not installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 1. Install Java Development Kit (JDK)

Android development requires Java. You can install either a specific version or the latest:

```bash
# Option 1: Latest OpenJDK (recommended for simplicity)
brew install openjdk

# Option 2: Specific version (OpenJDK 17)
brew install openjdk@17
```

**⚠️ Critical: Configure JAVA_HOME environment variable**

Gradle requires `JAVA_HOME` to be set, even if Java is installed:

```bash
# If you installed openjdk (latest)
export JAVA_HOME="/opt/homebrew/opt/openjdk"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# If you installed openjdk@17
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
```

**Find your Java installation:**
```bash
ls -la /opt/homebrew/opt/ | grep java
```

**Add to shell profile permanently:**

Add these lines to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
export PATH="$JAVA_HOME/bin:$PATH"
```

Then reload: `source ~/.zshrc`

## 2. Install Gradle Build System

```bash
brew install gradle
```

Gradle is the build automation tool used by Android projects.

## 3. Install Android Command-Line Tools

```bash
brew install --cask android-commandlinetools
```

This installs the Android SDK command-line tools to:
```
/opt/homebrew/share/android-commandlinetools
```

## 4. Install Android SDK Components

The command-line tools provide `sdkmanager` to install required SDK components.

**Set ANDROID_HOME:**
```bash
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
```

**Accept Android SDK license:**

Create the license acceptance file manually to avoid interactive prompts:

```bash
mkdir -p $ANDROID_HOME/licenses
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license
```

**Install required SDK components:**

```bash
sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

This installs:
- **platform-tools**: `adb`, `fastboot`, and other device tools
- **platforms;android-35**: Android 15 (API level 35) SDK platform
- **build-tools;35.0.0**: Build tools for compiling and packaging APKs

The installation takes several minutes and downloads ~500MB.

## 5. Add ADB to PATH

The Android Debug Bridge (`adb`) is installed in platform-tools:

```bash
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

Verify installation:
```bash
adb --version
```

## Complete Setup Script

Save this as `setup-android.sh` and run once:

```bash
#!/bin/bash

echo "🔧 Setting up Android development environment..."

# Install packages
brew install openjdk
brew install gradle
brew install --cask android-commandlinetools

# Set environment variables
export JAVA_HOME="/opt/homebrew/opt/openjdk"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

# Accept SDK license
mkdir -p $ANDROID_HOME/licenses
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license

# Install SDK components
sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-35" "build-tools;35.0.0"

echo "✅ Android development environment ready!"
echo ""
echo "Add these lines to ~/.zshrc:"
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk"'
echo 'export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"'
echo 'export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"'
```

## Verify Installation

**Check Java:**
```bash
echo $JAVA_HOME
# Should show: /opt/homebrew/opt/openjdk

java -version
# Should show: openjdk version (17 or higher)
```

**Check Gradle:**
```bash
gradle --version
# Should show: Gradle 9.1.0
```

**Check Android SDK:**
```bash
sdkmanager --list_installed --sdk_root=$ANDROID_HOME
# Should list: build-tools;35.0.0, platform-tools, platforms;android-35
```

**Check ADB:**
```bash
adb --version
# Should show: Android Debug Bridge version 36.0.0
```

## Project Configuration

Each Android project needs two configuration files:

**local.properties** (SDK location):
```properties
sdk.dir=/opt/homebrew/share/android-commandlinetools
```

**gradle.properties** (AndroidX support):
```properties
android.useAndroidX=true
```

These are typically git-ignored and created automatically or manually per project.

## Troubleshooting

**"Unable to locate a Java Runtime" or "The operation couldn't be completed"**
- This error occurs when `JAVA_HOME` is not set, even if Java is installed
- Find your Java: `ls -la /opt/homebrew/opt/ | grep java`
- Set JAVA_HOME: `export JAVA_HOME="/opt/homebrew/opt/openjdk"` (adjust path if needed)
- Add to shell profile permanently (see section 1 above)
- Verify it works: `java -version` should succeed after setting JAVA_HOME

**"SDK location not found"**
- Create `local.properties` in project root with `sdk.dir=` path
- Or set `ANDROID_HOME` environment variable

**"License not accepted"**
- Create license file manually as shown above
- Or run: `sdkmanager --licenses --sdk_root=$ANDROID_HOME` and type 'y'

**"adb: command not found"**
- Add platform-tools to PATH: `export PATH="$ANDROID_HOME/platform-tools:$PATH"`

**Build fails with AndroidX errors**
- Create `gradle.properties` with `android.useAndroidX=true`

## e/OS Specific Notes

All standard Android development tools work with e/OS devices. No special configuration needed - e/OS is based on Android Open Source Project (AOSP) and maintains full compatibility with Android development workflows.

## Implementation

Complete setup script in `setup/imp/setup-android.sh`
