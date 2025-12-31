package com.miso.noobtest

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed

/**
 * Registry for UI elements that can be triggered remotely for testing.
 * Allows buttons and text fields to be registered with IDs and triggered via HTTP.
 */
object UIAutomationRegistry {
    private val elements = mutableMapOf<String, () -> Unit>()
    private val textFields = mutableMapOf<String, (String) -> Unit>()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Register a UI element (button/action) with an ID.
     */
    fun register(id: String, action: () -> Unit) {
        synchronized(elements) {
            elements[id] = action
            Logger.log("[UI_AUTO] Registered element: $id")
        }
    }

    /**
     * Register a text field with an ID.
     */
    fun registerTextField(id: String, setText: (String) -> Unit) {
        synchronized(textFields) {
            textFields[id] = setText
            Logger.log("[UI_AUTO] Registered text field: $id")
        }
    }

    /**
     * Unregister a UI element.
     */
    fun unregister(id: String) {
        synchronized(elements) {
            elements.remove(id)
        }
        synchronized(textFields) {
            textFields.remove(id)
        }
    }

    /**
     * Trigger a registered UI element by ID.
     * Returns true if element was found and triggered.
     */
    fun trigger(id: String): Boolean {
        val action: (() -> Unit)?
        synchronized(elements) {
            action = elements[id]
        }

        if (action == null) {
            Logger.log("[UI_AUTO] Element not found: $id")
            return false
        }

        // Execute on main thread
        mainHandler.post {
            Logger.log("[UI_AUTO] Triggering: $id")
            action()
        }

        return true
    }

    /**
     * Set text in a registered text field.
     * Returns true if field was found and text was set.
     */
    fun setTextFieldValue(id: String, text: String): Boolean {
        val setText: ((String) -> Unit)?
        synchronized(textFields) {
            setText = textFields[id]
        }

        if (setText == null) {
            Logger.log("[UI_AUTO] Text field not found: $id")
            return false
        }

        // Execute on main thread
        mainHandler.post {
            Logger.log("[UI_AUTO] Setting text field $id to: $text")
            setText(text)
        }

        return true
    }

    /**
     * List all registered element IDs.
     */
    fun listElements(): List<String> {
        synchronized(elements) {
            return elements.keys.sorted()
        }
    }

    /**
     * List all registered text field IDs.
     */
    fun listTextFields(): List<String> {
        synchronized(textFields) {
            return textFields.keys.sorted()
        }
    }
}

/**
 * Composable effect to register a UI element for automation.
 * Automatically unregisters when the composable leaves composition.
 */
@Composable
fun RegisterUIElement(id: String, action: () -> Unit) {
    DisposableEffect(id) {
        UIAutomationRegistry.register(id, action)
        onDispose {
            UIAutomationRegistry.unregister(id)
        }
    }
}

/**
 * Composable effect to register a text field for automation.
 * Automatically unregisters when the composable leaves composition.
 */
@Composable
fun RegisterTextField(id: String, setText: (String) -> Unit) {
    DisposableEffect(id) {
        UIAutomationRegistry.registerTextField(id, setText)
        onDispose {
            UIAutomationRegistry.unregister(id)
        }
    }
}

/**
 * Modifier extension to register a UI element for automation.
 * Usage: Modifier.uiAutomationId("my-button") { doSomething() }
 */
fun Modifier.uiAutomationId(id: String, action: () -> Unit): Modifier = composed {
    DisposableEffect(id) {
        UIAutomationRegistry.register(id, action)
        onDispose {
            UIAutomationRegistry.unregister(id)
        }
    }
    this
}
