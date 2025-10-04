# create-app
*creating an Android/e/OS application structure*

An Android app built for e/OS follows the standard Android project structure using Gradle build system and Kotlin/Jetpack Compose for UI.

## Project Structure

A minimal Android app requires:

```
NoobTest/
├── build.gradle.kts          # Root build configuration
├── settings.gradle.kts        # Project settings
├── gradle/
│   └── wrapper/              # Gradle wrapper files
└── app/
    ├── build.gradle.kts      # App module build configuration
    └── src/main/
        ├── kotlin/
        │   └── com/miso/noobtest/
        │       └── MainActivity.kt
        ├── res/
        │   ├── values/
        │   │   └── strings.xml
        │   └── mipmap-xxxhdpi/  # App icons
        │       └── ic_launcher.png
        └── AndroidManifest.xml
```

## Root build.gradle.kts

```kotlin
plugins {
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
```

## settings.gradle.kts

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "NoobTest"
include(":app")
```

## app/build.gradle.kts

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.miso.noobtest"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.miso.noobtest"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.09.01")
    implementation(composeBom)

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
}
```

## AndroidManifest.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

## MainActivity.kt

```kotlin
package com.miso.noobtest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF40E0D0)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "ᕦ(ツ)ᕤ",
                    fontSize = 60.sp,
                    color = Color.Black
                )
            }
        }
    }
}
```

## res/values/strings.xml

```xml
<resources>
    <string name="app_name">NoobTest</string>
</resources>
```

## Key Points

- **Package name**: Uses reverse domain notation (com.miso.noobtest)
- **Jetpack Compose**: Modern declarative UI framework (as of 2025)
- **Kotlin**: Preferred language over Java
- **Material 3**: Latest Material Design components
- **Gradle Kotlin DSL**: build.gradle.kts instead of Groovy
- **e/OS compatibility**: Standard Android code works without Google services

## Implementation

Complete working structure in `create-app/imp/`
