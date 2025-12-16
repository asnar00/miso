package com.miso.noobtest

import fi.iki.elonen.NanoHTTPD

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

// Simple HTTP test server
class TestServer(port: Int = 8081) : NanoHTTPD(port) {
    companion object {
        private lateinit var instance: TestServer

        fun start() {
            Logger.log("TestServer: Attempting to start on port 8081")
            try {
                instance = TestServer()
                instance.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
                Logger.log("TestServer: Server started successfully")
            } catch (e: Exception) {
                Logger.log("TestServer: Failed to start - ${e.message}")
            }
        }
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri

        Logger.log("TestServer: Received request for $uri")

        if (!uri.startsWith("/test/")) {
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not found")
        }

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
}
