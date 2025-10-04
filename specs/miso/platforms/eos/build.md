# build
*compiling Android apps with Gradle*

Android apps are built using Gradle, a build automation tool. The Gradle Wrapper (`gradlew`) ensures consistent builds across different environments.

## Prerequisites

- Android SDK installed
- Gradle wrapper present in project root (automatically created when project is initialized)
- Java Development Kit (JDK) 17 or higher

## Building Debug APK

```bash
./gradlew assembleDebug
```

**Output location:**
```
app/build/outputs/apk/debug/app-debug.apk
```

The debug APK is automatically signed with a debug keystore and is ready to install immediately.

## Building Release APK

```bash
./gradlew assembleRelease
```

**Output location:**
```
app/build/outputs/apk/release/app-release.apk
```

Release builds require signing configuration (see `code-signing.md`).

## Build + Install (One Step)

Instead of building then manually installing, Gradle can do both:

```bash
./gradlew installDebug
```

This builds the debug APK and installs it directly to a connected device or running emulator.

## Useful Commands

```bash
# List all available build tasks
./gradlew tasks

# Clean build artifacts
./gradlew clean

# Build all variants
./gradlew build

# Assemble specific build variant
./gradlew assembleDebug
./gradlew assembleRelease
```

## Build Script

For convenience, create `build.sh`:

```bash
#!/bin/bash

echo "🔨 Building NoobTest debug APK..."
./gradlew assembleDebug

if [ $? -eq 0 ]; then
    echo "✅ Build complete!"
    echo "📦 APK: app/build/outputs/apk/debug/app-debug.apk"
else
    echo "❌ Build failed"
    exit 1
fi
```

## First Build

The first build downloads dependencies and may take several minutes:

```
Downloading https://services.gradle.org/distributions/gradle-8.9-bin.zip
...
BUILD SUCCESSFUL in 2m 14s
```

Subsequent builds are much faster due to caching.

## Troubleshooting

**"Command not found: gradlew"**
- The Gradle wrapper wasn't created. Initialize with: `gradle wrapper`

**"JAVA_HOME not set"**
- Set JAVA_HOME environment variable to your JDK installation path

**"SDK location not found"**
- Create `local.properties` with: `sdk.dir=/path/to/android/sdk`
- On macOS: typically `~/Library/Android/sdk`

## Implementation

Working build script in `build/imp/build.sh`
