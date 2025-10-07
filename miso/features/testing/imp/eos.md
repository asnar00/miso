# testing - Android/e/OS Implementation
*Android/Kotlin/JUnit testing details*

## Overview

Android tests use JUnit framework and run on connected devices or emulators via Gradle.

## Setup Requirements

**Environment**: Set JAVA_HOME before running tests

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
```

**Dependencies**: Configured in `build.gradle.kts`

```kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
}
```

## Test File Structure

**Product test file**: `apps/product/client/imp/eos/app/src/test/FeatureTests.kt`

```kotlin
import org.junit.Test
import org.junit.Assert.*

class FeatureTests {

    // Feature: ping
    @Test
    fun test_ping_serverResponds() {
        // Generated from features/ping/imp/tests-eos.md
    }

    @Test
    fun test_ping_detectsServerRunning() {
        // Generated from features/ping/imp/tests-eos.md
    }

    // Test runner
    fun test_all() {
        test_ping_serverResponds()
        test_ping_detectsServerRunning()
        // ... more tests
    }
}
```

## Test Code Format

Feature tests in `features/name/imp/tests-eos.md`:

```kotlin
@Test
fun test_featureName_scenario() {
    // Test code using HTTP client, assertions, etc.

    val response = httpClient.get("http://server/api/endpoint")
    assertEquals(200, response.status)
    assertTrue(condition)
}
```

## Running Tests

### Single Feature

```bash
cd apps/product/client/imp/eos
./test-feature.sh featureName
```

Executes:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew test --tests "test_featureName_*"
```

### All Tests

```bash
cd apps/product/client/imp/eos
./test-all.sh
```

Executes:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew test
```

## Key Details

**Test Runner**: Gradle (./gradlew test)
**Test Framework**: JUnit 4
**HTTP Library**: OkHttp or Ktor client
**Execution Environment**: JVM (local unit tests)
**Assertions**: JUnit assertions (assertEquals, assertTrue, etc.)

**Critical**: Always set `JAVA_HOME` before running tests

## Test Results

Results are:
- Displayed in console
- Saved to `test-results.log`
- HTML report generated in `app/build/reports/tests/`
- Include pass/fail status and execution time

## Dependencies

Required in `build.gradle.kts`:
```kotlin
testImplementation("junit:junit:4.13.2")
testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
testImplementation("com.squareup.okhttp3:okhttp:4.12.0")
```

## Example Structure

```kotlin
import org.junit.Test
import org.junit.Assert.*
import java.net.URL

class FeatureTests {

    @Test
    fun test_ping_serverResponds() {
        val url = URL("http://192.168.1.76:8080/api/ping")
        val connection = url.openConnection()

        val response = connection.getInputStream().bufferedReader().readText()

        assertTrue(response.contains("\"status\":\"ok\""))
    }
}
```

## Test Types

**Unit tests** (no device):
- Run on JVM
- Fast execution
- Located in `src/test/`

**Instrumented tests** (require device):
- Run on Android device/emulator
- Test UI and Android-specific features
- Located in `src/androidTest/`
- Use: `./gradlew connectedAndroidTest`

For most feature tests, unit tests are sufficient and faster.

## Typical Build Time

- First test run: ~10-15 seconds (Gradle setup)
- Incremental tests: ~1-2 seconds
- Test execution: ~0.5s per test

## Notes

- Tests run on JVM, not Android runtime (for speed)
- For device-specific tests, use instrumented tests
- Gradle caches results for unchanged tests
