package com.miso.noobtest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : ComponentActivity() {
    private val serverURL = "http://185.96.221.52:8080"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize logger
        Logger.init(this)

        // Start test server
        TestServer.start()

        // Register ping test
        TestRegistry.register("ping") {
            testPingFeature()
        }

        setContent {
            FireflyApp()
        }
    }

    @Composable
    fun FireflyApp() {
        // State for background color (gray = disconnected, turquoise = connected)
        var backgroundColor by remember { mutableStateOf(Color.Gray) }

        // Periodic ping check
        LaunchedEffect(Unit) {
            while (true) {
                val isConnected = withContext(Dispatchers.IO) {
                    testConnection()
                }
                backgroundColor = if (isConnected) {
                    Color(0xFF40E0D0) // Turquoise when connected
                } else {
                    Color.Gray // Gray when disconnected
                }
                delay(1000) // Check every 1 second
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(backgroundColor),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "ᕦ(ツ)ᕤ",
                fontSize = 90.sp,
                color = Color.Black
            )
        }
    }

    private fun testConnection(): Boolean {
        return try {
            val url = URL("$serverURL/api/ping")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 1000
            connection.readTimeout = 1000

            val responseCode = connection.responseCode
            connection.disconnect()

            responseCode == 200
        } catch (e: Exception) {
            false
        }
    }

    // Test function for ping feature
    private fun testPingFeature(): TestResult {
        return try {
            val url = URL("$serverURL/api/ping")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 2000
            connection.readTimeout = 2000

            val responseCode = connection.responseCode
            connection.disconnect()

            if (responseCode == 200) {
                TestResult(success = true)
            } else {
                TestResult(success = false, error = "Server returned status $responseCode")
            }
        } catch (e: Exception) {
            TestResult(success = false, error = "Connection failed: ${e.message}")
        }
    }
}
