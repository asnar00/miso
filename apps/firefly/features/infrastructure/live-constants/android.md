# live-constants Android implementation

*Jetpack Compose implementation for live tunable constants with HTTP endpoints*

## File Location

`apps/firefly/product/client/imp/android/app/src/main/kotlin/com/miso/noobtest/TunableConstants.kt`

## TunableConstants Object

```kotlin
package com.miso.noobtest

import android.content.Context
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.graphics.Color
import org.json.JSONObject
import java.io.File

object TunableConstants {
    private val constants = mutableMapOf<String, Any>()

    // Version counter to trigger recomposition when values change
    val version = mutableStateOf(0)

    private lateinit var fileLocation: File
    private var initialized = false

    // Default values (matching iOS)
    private val defaults = mapOf(
        "spacing" to 0.8,
        "corner-roundness" to 0.75,
        "font-scale" to 0.9,
        "post-background-brightness" to 0.7,
        "button-colour-r" to 255,
        "button-colour-g" to 178,
        "button-colour-b" to 128,
        "button-brightness" to 1.0,
        "author-font-size" to 0.95,
        "edit-button-x" to 370,
        "edit-button-spacing" to 16,
        "background-colour-r" to 0,
        "background-colour-g" to 0,
        "background-colour-b" to 0
    )

    fun initialize(context: Context) {
        if (initialized) return

        fileLocation = File(context.filesDir, "live-constants.json")

        if (!fileLocation.exists()) {
            constants.putAll(defaults)
            saveConstants()
            Logger.info("[TunableConstants] Created with defaults")
        } else {
            loadConstants()
        }

        initialized = true
    }

    private fun loadConstants() {
        try {
            val json = JSONObject(fileLocation.readText())
            constants.clear()
            json.keys().forEach { key ->
                constants[key] = json.get(key)
            }
            Logger.info("[TunableConstants] Loaded ${constants.size} constants")
        } catch (e: Exception) {
            Logger.error("[TunableConstants] Error loading: $e")
            constants.putAll(defaults)
        }
    }

    fun getDouble(key: String, default: Double = 0.0): Double {
        return when (val value = constants[key]) {
            is Double -> value
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            is Number -> value.toDouble()
            else -> default
        }
    }

    fun getInt(key: String, default: Int = 0): Int {
        return when (val value = constants[key]) {
            is Int -> value
            is Double -> value.toInt()
            is Long -> value.toInt()
            is Number -> value.toInt()
            else -> default
        }
    }

    fun set(key: String, value: Any) {
        constants[key] = value
        saveConstants()
        version.value++
        Logger.info("[TunableConstants] Set $key = $value")
    }

    fun getAll(): Map<String, Any> = constants.toMap()

    fun setAll(newConstants: Map<String, Any>) {
        constants.clear()
        constants.putAll(newConstants)
        saveConstants()
        version.value++
    }

    // Color helper functions (matching iOS)

    fun buttonColor(): Color {
        val r = getDouble("button-colour-r", 255.0) / 255.0
        val g = getDouble("button-colour-g", 178.0) / 255.0
        val b = getDouble("button-colour-b", 128.0) / 255.0
        val brightness = getDouble("button-brightness", 1.0)

        return Color(
            red = (r * brightness).toFloat().coerceIn(0f, 1f),
            green = (g * brightness).toFloat().coerceIn(0f, 1f),
            blue = (b * brightness).toFloat().coerceIn(0f, 1f)
        )
    }

    fun buttonHighlightColor(): Color {
        val r = getDouble("button-colour-r", 255.0) / 255.0
        val g = getDouble("button-colour-g", 178.0) / 255.0
        val b = getDouble("button-colour-b", 128.0) / 255.0
        val brightness = getDouble("button-brightness", 1.0) * 0.8

        return Color(
            red = (r * brightness).toFloat().coerceIn(0f, 1f),
            green = (g * brightness).toFloat().coerceIn(0f, 1f),
            blue = (b * brightness).toFloat().coerceIn(0f, 1f)
        )
    }

    fun backgroundColor(): Color {
        val r = getDouble("background-colour-r", 0.0) / 255.0
        val g = getDouble("background-colour-g", 0.0) / 255.0
        val b = getDouble("background-colour-b", 0.0) / 255.0

        return Color(
            red = r.toFloat().coerceIn(0f, 1f),
            green = g.toFloat().coerceIn(0f, 1f),
            blue = b.toFloat().coerceIn(0f, 1f)
        )
    }

    private fun saveConstants() {
        try {
            val json = JSONObject(constants.toMap())
            fileLocation.writeText(json.toString(2))
        } catch (e: Exception) {
            Logger.error("[TunableConstants] Error saving: $e")
        }
    }
}
```

## Test Server Endpoints

**File:** `apps/firefly/product/client/imp/android/app/src/main/kotlin/com/miso/noobtest/TestServer.kt`

Add these handlers to the existing TestServer (using NanoHTTPD):

```kotlin
// In serve() method, add these routes:

// GET /tune - return all tunable constants
method == Method.GET && uri == "/tune" -> {
    return handleGetTunables()
}

// PUT /tune/:key/:value - set single tunable constant
method == Method.PUT && uri.startsWith("/tune/") -> {
    return handleSetTunable(uri)
}

// POST /tune - set all tunable constants from JSON body
method == Method.POST && uri == "/tune" -> {
    return handleSetAllTunables(session)
}

// Handler implementations:

private fun handleGetTunables(): Response {
    val constants = TunableConstants.getAll()
    val json = JSONObject(constants).toString(2)
    return newFixedLengthResponse(Response.Status.OK, "application/json", json)
}

private fun handleSetTunable(uri: String): Response {
    val path = uri.removePrefix("/tune/")
    val parts = path.split("/")

    if (parts.size < 2) {
        return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json",
            """{"status": "error", "message": "Invalid path format"}""")
    }

    val key = parts[0]
    val valueStr = parts[1]
    val value: Any = valueStr.toDoubleOrNull() ?: valueStr

    TunableConstants.set(key, value)
    return newFixedLengthResponse(Response.Status.OK, "application/json",
        """{"status": "success", "key": "$key", "value": $valueStr}""")
}

private fun handleSetAllTunables(session: IHTTPSession): Response {
    try {
        val contentLength = session.headers["content-length"]?.toIntOrNull() ?: 0
        val buffer = ByteArray(contentLength)
        session.inputStream.read(buffer, 0, contentLength)
        val body = String(buffer)

        val json = JSONObject(body)
        val newConstants = mutableMapOf<String, Any>()
        json.keys().forEach { key -> newConstants[key] = json.get(key) }

        TunableConstants.setAll(newConstants)
        return newFixedLengthResponse(Response.Status.OK, "application/json",
            """{"status": "success", "count": ${newConstants.size}}""")
    } catch (e: Exception) {
        return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json",
            """{"status": "error", "message": "Invalid JSON"}""")
    }
}
```

## App Initialization

**File:** `apps/firefly/product/client/imp/android/app/src/main/kotlin/com/miso/noobtest/MainActivity.kt`

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // Initialize storage, logger, and tunables
    Storage.init(this)
    Logger.init(this)
    TunableConstants.initialize(this)

    // Start test server
    TestServer.start()

    // ... rest of initialization
}
```

## Usage in Composables

```kotlin
@Composable
fun MyComposable() {
    // Observe tunables for reactivity - reading this triggers recomposition on change
    val tunablesVersion = TunableConstants.version.value

    // Get tunable values
    val fontScale = TunableConstants.getDouble("font-scale", 1.0).toFloat()
    val cornerRoundness = TunableConstants.getDouble("corner-roundness", 1.0).toFloat()
    val buttonColor = TunableConstants.buttonColor()
    val backgroundColor = TunableConstants.backgroundColor()

    Text(
        text = "Hello",
        fontSize = (16 * fontScale).sp
    )

    Box(
        modifier = Modifier
            .background(buttonColor, RoundedCornerShape((12 * cornerRoundness).dp))
    )
}
```

## HTTP API

```bash
# Get all tunables
curl http://localhost:8081/tune

# Set single value
curl -X PUT http://localhost:8081/tune/font-scale/0.9

# Set all values from JSON
curl -X POST -H "Content-Type: application/json" \
    -d '{"font-scale": 0.9, "corner-roundness": 0.75}' \
    http://localhost:8081/tune

# Sync from shared live-constants.json
cat live-constants.json | curl -X POST -H "Content-Type: application/json" -d @- http://localhost:8081/tune
```

## Key Differences from iOS

1. **Reactivity**: Uses `mutableStateOf(version)` instead of `@Published` - Composables read `version.value` to trigger recomposition
2. **Storage**: Uses app's internal files directory (`context.filesDir`) instead of Documents directory
3. **Defaults**: Hardcoded defaults ensure app works even if JSON file is missing
4. **Color helpers**: Returns `androidx.compose.ui.graphics.Color` instead of SwiftUI `Color`

## Current Tunables in Use

| Key | Default | Description |
|-----|---------|-------------|
| `font-scale` | 0.9 | Multiplier for all font sizes |
| `corner-roundness` | 0.75 | Multiplier for corner radii |
| `post-background-brightness` | 0.7 | Card background alpha (0-1) |
| `author-font-size` | 0.95 | Additional multiplier for author text |
| `button-colour-r/g/b` | 255/178/128 | Button RGB values |
| `button-brightness` | 1.0 | Button color brightness multiplier |
| `background-colour-r/g/b` | 0/0/0 | Background RGB values |
