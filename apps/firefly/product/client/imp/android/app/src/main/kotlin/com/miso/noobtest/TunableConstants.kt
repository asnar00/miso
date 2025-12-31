package com.miso.noobtest

import android.content.Context
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.graphics.Color
import org.json.JSONObject
import java.io.File

/**
 * TunableConstants - Live constants for UI tuning without rebuilding.
 *
 * Constants are stored in a JSON file in the app's files directory.
 * HTTP endpoints allow real-time updates via the TestServer.
 */
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
            // Initialize with defaults
            constants.putAll(defaults)
            saveConstants()
            Logger.info("[TunableConstants] Created with defaults at ${fileLocation.absolutePath}")
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
            // Fall back to defaults
            constants.putAll(defaults)
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

    fun getString(key: String, default: String = ""): String {
        return constants[key] as? String ?: default
    }

    fun set(key: String, value: Any) {
        constants[key] = value
        saveConstants()
        version.value++
        Logger.info("[TunableConstants] Set $key = $value")
    }

    fun getAll(): Map<String, Any> {
        return constants.toMap()
    }

    fun setAll(newConstants: Map<String, Any>) {
        constants.clear()
        constants.putAll(newConstants)
        saveConstants()
        version.value++
        Logger.info("[TunableConstants] Updated all constants (${constants.size} values)")
    }

    // Color helper functions (matching iOS)

    /** Returns the button color based on RGB values modified by brightness */
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

    /** Returns the button highlight color (0.8x brightness for darker highlight) */
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

    /** Returns the background color */
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
