package com.miso.noobtest

import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject

// Test result structure
data class TestResult(
    val success: Boolean,
    val error: String? = null
)

// Registry for test functions
object TestRegistry {
    private val tests = mutableMapOf<String, () -> TestResult>()

    fun register(feature: String, test: () -> TestResult) {
        tests[feature] = test
    }

    fun run(feature: String): TestResult {
        val test = tests[feature]
        return if (test != null) {
            test()
        } else {
            TestResult(success = false, error = "No test found for feature '$feature'")
        }
    }
}

// Simple HTTP test server with UI automation support
class TestServer(port: Int = 8081) : NanoHTTPD(port) {
    companion object {
        private var instance: TestServer? = null

        fun start() {
            Logger.log("TestServer: Attempting to start on port 8081")
            try {
                instance = TestServer()
                instance?.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
                Logger.log("TestServer: Server started successfully")
            } catch (e: Exception) {
                Logger.log("TestServer: Failed to start - ${e.message}")
            }
        }
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val method = session.method

        Logger.log("TestServer: ${method.name} $uri")

        // Handle UI automation endpoints
        when {
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

            // POST /test/tap?id=element-id - Trigger a UI element
            method == Method.POST && uri.startsWith("/test/tap") -> {
                return handleTap(session)
            }

            // POST /test/set-text?id=field-id&text=value - Set text in a field
            method == Method.POST && uri.startsWith("/test/set-text") -> {
                return handleSetText(session)
            }

            // GET /test/list-elements - List all registered UI elements
            method == Method.GET && uri == "/test/list-elements" -> {
                return handleListElements()
            }

            // GET /test/{feature} - Run a registered test
            method == Method.GET && uri.startsWith("/test/") -> {
                val feature = uri.removePrefix("/test/")
                val result = TestRegistry.run(feature)
                val message = if (result.success) {
                    "succeeded"
                } else {
                    "failed because ${result.error ?: "unknown error"}"
                }
                Logger.log("TestServer: Test result for $feature: $message")
                return newFixedLengthResponse(Response.Status.OK, MIME_PLAINTEXT, message)
            }

            else -> {
                return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not found")
            }
        }
    }

    private fun handleTap(session: IHTTPSession): Response {
        val params = session.parms
        val id = params["id"]

        if (id.isNullOrEmpty()) {
            Logger.log("TestServer: Missing id parameter in tap request")
            val json = """{"status": "error", "message": "Missing id parameter"}"""
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", json)
        }

        Logger.log("TestServer: Triggering UI element: $id")
        val success = UIAutomationRegistry.trigger(id)

        return if (success) {
            Logger.log("TestServer: Successfully triggered: $id")
            val json = """{"status": "success", "id": "$id"}"""
            newFixedLengthResponse(Response.Status.OK, "application/json", json)
        } else {
            Logger.log("TestServer: Element not found: $id")
            val json = """{"status": "error", "message": "Element not found: $id"}"""
            newFixedLengthResponse(Response.Status.NOT_FOUND, "application/json", json)
        }
    }

    private fun handleSetText(session: IHTTPSession): Response {
        val params = session.parms
        val id = params["id"]
        val text = params["text"]

        if (id.isNullOrEmpty() || text == null) {
            Logger.log("TestServer: Missing id or text parameter in set-text request")
            val json = """{"status": "error", "message": "Missing id or text parameter"}"""
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", json)
        }

        Logger.log("TestServer: Setting text field $id to: $text")
        val success = UIAutomationRegistry.setTextFieldValue(id, text)

        return if (success) {
            Logger.log("TestServer: Successfully set text field: $id")
            val json = """{"status": "success", "id": "$id", "text": "$text"}"""
            newFixedLengthResponse(Response.Status.OK, "application/json", json)
        } else {
            Logger.log("TestServer: Text field not found: $id")
            val json = """{"status": "error", "message": "Text field not found: $id"}"""
            newFixedLengthResponse(Response.Status.NOT_FOUND, "application/json", json)
        }
    }

    private fun handleListElements(): Response {
        val elements = UIAutomationRegistry.listElements()
        val textFields = UIAutomationRegistry.listTextFields()

        val json = JSONObject().apply {
            put("elements", elements)
            put("textFields", textFields)
        }.toString()

        return newFixedLengthResponse(Response.Status.OK, "application/json", json)
    }

    // Tunable constants handlers

    private fun handleGetTunables(): Response {
        val constants = TunableConstants.getAll()
        val json = JSONObject(constants).toString(2)
        Logger.log("TestServer: Returning all tunables (${constants.size} values)")
        return newFixedLengthResponse(Response.Status.OK, "application/json", json)
    }

    private fun handleSetTunable(uri: String): Response {
        // Parse /tune/:key/:value
        val path = uri.removePrefix("/tune/")
        val parts = path.split("/")

        if (parts.size < 2) {
            val json = """{"status": "error", "message": "Invalid path format. Use /tune/:key/:value"}"""
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", json)
        }

        val key = parts[0]
        val valueStr = parts[1]

        // Try to parse as number first, then string
        val value: Any = valueStr.toDoubleOrNull() ?: valueStr

        TunableConstants.set(key, value)
        Logger.log("TestServer: Set tunable $key = $value")

        val json = """{"status": "success", "key": "$key", "value": $valueStr}"""
        return newFixedLengthResponse(Response.Status.OK, "application/json", json)
    }

    private fun handleSetAllTunables(session: IHTTPSession): Response {
        try {
            // Read the body
            val contentLength = session.headers["content-length"]?.toIntOrNull() ?: 0
            val buffer = ByteArray(contentLength)
            session.inputStream.read(buffer, 0, contentLength)
            val body = String(buffer)

            val json = JSONObject(body)
            val newConstants = mutableMapOf<String, Any>()

            json.keys().forEach { key ->
                newConstants[key] = json.get(key)
            }

            TunableConstants.setAll(newConstants)
            Logger.log("TestServer: Updated all tunables (${newConstants.size} values)")

            val response = """{"status": "success", "count": ${newConstants.size}}"""
            return newFixedLengthResponse(Response.Status.OK, "application/json", response)
        } catch (e: Exception) {
            Logger.log("TestServer: Error parsing tunables JSON: ${e.message}")
            val json = """{"status": "error", "message": "Invalid JSON: ${e.message}"}"""
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, "application/json", json)
        }
    }
}
