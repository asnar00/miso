# Android Jetpack Compose Template
*Minimal Android application template*

A minimal Jetpack Compose app that displays "template" in the center of the screen.

## Usage

Copy this template to start a new Android project:

```bash
cp -r miso/platforms/eos/template/ MyApp/
```

Then:
1. Rename package in `app/src/main/kotlin/com/miso/noobtest/`
2. Update package name in `build.gradle.kts` and `AndroidManifest.xml`
3. Modify `MainActivity.kt` to add your features
4. Open project in Android Studio or build with Gradle

## What's Included

- Complete Gradle project structure
- Jetpack Compose MainActivity displaying "template"
- Ready to build and run on emulator or device

## Building

```bash
./gradlew assembleDebug
```

## Next Steps

See `miso/platforms/eos/` for documentation on:
- Building and deploying
- Adding app icons
- USB deployment to devices
- Setting up Android SDK
