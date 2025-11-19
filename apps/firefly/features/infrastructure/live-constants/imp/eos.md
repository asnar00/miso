# live-constants Android implementation

## TunableConstants Object

**File:** `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/noobtest/TunableConstants.kt`

```kotlin
package com.miso.noobtest

import android.content.Context
import androidx.compose.runtime.mutableStateMapOf
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONObject
import java.io.File

object TunableConstants {
    private val constants = mutableStateMapOf<String, Any>()
    private val _version = MutableStateFlow(0)
    val version: StateFlow<Int> = _version

    private lateinit var fileLocation: File

    fun initialize(context: Context) {
        // Path to live-constants.json in project root
        // For Android, we'll use external storage during development
        val projectRoot = File("/Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client")
        fileLocation = File(projectRoot, "live-constants.json")
        loadConstants()
    }

    private fun loadConstants() {
        if (fileLocation.exists()) {
            try {
                val json = JSONObject(fileLocation.readText())
                constants.clear()
                json.keys().forEach { key ->
                    constants[key] = json.get(key)
                }
                Log.i("TunableConstants", "Loaded ${constants.size} constants from ${fileLocation.absolutePath}")
            } catch (e: Exception) {
                Log.e("TunableConstants", "Error loading constants: $e")
            }
        } else {
            // Create empty file
            saveConstants()
        }
    }

    fun get(key: String): Any? {
        return constants[key]
    }

    fun getDouble(key: String, default: Double = 0.0): Double {
        return when (val value = constants[key]) {
            is Double -> value
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            else -> default
        }
    }

    fun getInt(key: String, default: Int = 0): Int {
        return when (val value = constants[key]) {
            is Int -> value
            is Double -> value.toInt()
            is Long -> value.toInt()
            else -> default
        }
    }

    fun getString(key: String, default: String = ""): String {
        return constants[key] as? String ?: default
    }

    fun set(key: String, value: Any) {
        constants[key] = value
        saveConstants()
        _version.value++
    }

    fun getAll(): Map<String, Any> {
        return constants.toMap()
    }

    fun setAll(newConstants: Map<String, Any>) {
        constants.clear()
        constants.putAll(newConstants)
        saveConstants()
        _version.value++
    }

    private fun saveConstants() {
        try {
            val json = JSONObject(constants.toMap())
            fileLocation.writeText(json.toString(2))
            Log.i("TunableConstants", "Saved constants to ${fileLocation.absolutePath}")
        } catch (e: Exception) {
            Log.e("TunableConstants", "Error saving constants: $e")
        }
    }
}
```

## Test Server Endpoints

**File:** `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/noobtest/TestServer.kt`

Add these routes to the existing TestServer:

```kotlin
// GET /tune - return all constants
server.createContext("/tune") { exchange ->
    if (exchange.requestMethod == "GET") {
        val constants = TunableConstants.getAll()
        val json = JSONObject(constants)
        val response = json.toString(2)
        exchange.sendResponseHeaders(200, response.toByteArray().size.toLong())
        exchange.responseBody.use { it.write(response.toByteArray()) }
    } else {
        exchange.sendResponseHeaders(405, -1)
    }
}

// PUT /tune/:key/:value - set single constant
server.createContext("/tune/") { exchange ->
    if (exchange.requestMethod == "PUT") {
        val path = exchange.requestURI.path.removePrefix("/tune/")
        val parts = path.split("/")
        if (parts.size == 2) {
            val key = parts[0]
            val valueStr = parts[1]

            // Try to parse as number first, then string
            val value: Any = valueStr.toDoubleOrNull() ?: valueStr

            TunableConstants.set(key, value)
            val response = "Set $key = $value"
            exchange.sendResponseHeaders(200, response.toByteArray().size.toLong())
            exchange.responseBody.use { it.write(response.toByteArray()) }
        } else {
            exchange.sendResponseHeaders(400, -1)
        }
    } else if (exchange.requestMethod == "POST") {
        // POST /tune - set all constants
        val body = exchange.requestBody.bufferedReader().readText()
        try {
            val json = JSONObject(body)
            val newConstants = mutableMapOf<String, Any>()
            json.keys().forEach { key ->
                newConstants[key] = json.get(key)
            }
            TunableConstants.setAll(newConstants)
            val response = "Updated all constants"
            exchange.sendResponseHeaders(200, response.toByteArray().size.toLong())
            exchange.responseBody.use { it.write(response.toByteArray()) }
        } catch (e: Exception) {
            exchange.sendResponseHeaders(400, -1)
        }
    } else {
        exchange.sendResponseHeaders(405, -1)
    }
}
```

## App Initialization

**File:** `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/noobtest/MainActivity.kt`

Add to onCreate:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // Initialize tunable constants
    TunableConstants.initialize(this)

    // ... rest of initialization
}
```

## Usage Example

**In any Composable:**

```kotlin
@Composable
fun MyComposable() {
    // React to changes
    val version by TunableConstants.version.collectAsState()

    Column(
        modifier = Modifier
            .height(TunableConstants.getDouble("toolbar_height", 60.0).dp)
            .background(
                Color(
                    red = (TunableConstants.getDouble("background_red", 224.0) / 255).toFloat(),
                    green = (TunableConstants.getDouble("background_green", 176.0) / 255).toFloat(),
                    blue = (TunableConstants.getDouble("background_blue", 255.0) / 255).toFloat()
                )
            )
    ) {
        // ...
    }
}
```

## Patching Instructions

1. Create `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/noobtest/TunableConstants.kt` with the code above
2. Update `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/noobtest/TestServer.kt` to add the endpoints
3. Update `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/noobtest/MainActivity.kt` to initialize TunableConstants
4. Create `apps/firefly/product/client/live-constants.json` with `{}` if it doesn't exist
