# ui-automation Android implementation
*Jetpack Compose UI automation via HTTP*

## Overview

Implements UI automation for Android using a singleton registry that maps string IDs to UI actions. Extends the existing TestServer to handle `/test/tap` and `/test/set-text` POST requests.

## Files

1. **UIAutomationRegistry.kt** - Singleton registry for UI elements
2. **TestServer.kt** - HTTP endpoints for triggering UI actions

## Implementation

### UIAutomationRegistry.kt

**File:** `apps/firefly/product/client/imp/android/app/src/main/kotlin/com/miso/noobtest/UIAutomationRegistry.kt`

```kotlin
package com.miso.noobtest

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed

object UIAutomationRegistry {
    private val elements = mutableMapOf<String, () -> Unit>()
    private val textFields = mutableMapOf<String, (String) -> Unit>()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(id: String, action: () -> Unit) {
        synchronized(elements) {
            elements[id] = action
            Logger.log("[UI_AUTO] Registered element: $id")
        }
    }

    fun registerTextField(id: String, setText: (String) -> Unit) {
        synchronized(textFields) {
            textFields[id] = setText
            Logger.log("[UI_AUTO] Registered text field: $id")
        }
    }

    fun unregister(id: String) {
        synchronized(elements) { elements.remove(id) }
        synchronized(textFields) { textFields.remove(id) }
    }

    fun trigger(id: String): Boolean {
        val action: (() -> Unit)?
        synchronized(elements) { action = elements[id] }

        if (action == null) {
            Logger.log("[UI_AUTO] Element not found: $id")
            return false
        }

        mainHandler.post {
            Logger.log("[UI_AUTO] Triggering: $id")
            action()
        }
        return true
    }

    fun setTextFieldValue(id: String, text: String): Boolean {
        val setText: ((String) -> Unit)?
        synchronized(textFields) { setText = textFields[id] }

        if (setText == null) {
            Logger.log("[UI_AUTO] Text field not found: $id")
            return false
        }

        mainHandler.post {
            Logger.log("[UI_AUTO] Setting text field $id to: $text")
            setText(text)
        }
        return true
    }

    fun listElements(): List<String> = synchronized(elements) { elements.keys.sorted() }
    fun listTextFields(): List<String> = synchronized(textFields) { textFields.keys.sorted() }
}

// Composable helpers
@Composable
fun RegisterUIElement(id: String, action: () -> Unit) {
    DisposableEffect(id) {
        UIAutomationRegistry.register(id, action)
        onDispose { UIAutomationRegistry.unregister(id) }
    }
}

@Composable
fun RegisterTextField(id: String, setText: (String) -> Unit) {
    DisposableEffect(id) {
        UIAutomationRegistry.registerTextField(id, setText)
        onDispose { UIAutomationRegistry.unregister(id) }
    }
}

// Modifier extension
fun Modifier.uiAutomationId(id: String, action: () -> Unit): Modifier = composed {
    DisposableEffect(id) {
        UIAutomationRegistry.register(id, action)
        onDispose { UIAutomationRegistry.unregister(id) }
    }
    this
}
```

### TestServer Endpoints

The TestServer handles these UI automation endpoints:

- `POST /test/tap?id=element-id` - Trigger a registered UI element
- `POST /test/set-text?id=field-id&text=value` - Set text in a registered text field
- `GET /test/list-elements` - List all registered elements and text fields

## Usage

### Registering a Button

```kotlin
@Composable
fun MyButton() {
    var clicked by remember { mutableStateOf(false) }

    // Register for automation
    RegisterUIElement("my-button") {
        clicked = true
    }

    Button(onClick = { clicked = true }) {
        Text("Click Me")
    }
}
```

### Using Modifier Extension

```kotlin
@Composable
fun MyScreen() {
    Button(
        onClick = { /* action */ },
        modifier = Modifier.uiAutomationId("toolbar-plus") { /* action */ }
    ) {
        Text("+")
    }
}
```

### Registering a Text Field

```kotlin
@Composable
fun MyTextField() {
    var text by remember { mutableStateOf("") }

    // Register for automation
    RegisterTextField("search-field") { newText ->
        text = newText
    }

    TextField(
        value = text,
        onValueChange = { text = it }
    )
}
```

## Testing

**Setup ADB port forwarding:**
```bash
adb forward tcp:8081 tcp:8081
```

**Trigger a button:**
```bash
curl -X POST 'http://localhost:8081/test/tap?id=my-button'
```

**Set text in a field:**
```bash
curl -X POST 'http://localhost:8081/test/set-text?id=search-field&text=hello'
```

**List registered elements:**
```bash
curl http://localhost:8081/test/list-elements
```

## Expected Responses

**Success:**
```json
{"status": "success", "id": "my-button"}
```

**Element not found:**
```json
{"status": "error", "message": "Element not found: invalid-id"}
```

**List elements:**
```json
{"elements": ["my-button", "toolbar-plus"], "textFields": ["search-field"]}
```

## Notes

- Actions execute on main thread via Handler
- Registry is thread-safe using synchronized blocks
- Elements auto-unregister when composable leaves composition
- Requires ADB port forwarding for remote access
- Only available when TestServer is running

## Common Element IDs

Once toolbar and other views are updated:
- `toolbar-home` - Home/feed button
- `toolbar-plus` - Create post button
- `toolbar-search` - Search button
- `toolbar-profile` - Profile button
- `refresh-button` - Pull to refresh

## Patching Instructions

1. Create `UIAutomationRegistry.kt` with the code above
2. Update `TestServer.kt` to add tap/set-text endpoints (already done)
3. Add `RegisterUIElement` calls to views that need automation
4. Test via curl commands
