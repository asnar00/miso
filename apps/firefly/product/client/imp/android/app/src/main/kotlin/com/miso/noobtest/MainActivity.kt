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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.zIndex
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

        // Initialize storage, logger, and tunables
        Storage.init(this)
        Logger.init(this)
        TunableConstants.initialize(this)

        // Start test server
        TestServer.start()

        // Register tests
        TestRegistry.register("ping") {
            testPingFeature()
        }

        TestRegistry.register("clear-login") {
            Storage.clearLoginState()
            val (email, isLoggedIn) = Storage.getLoginState()
            if (email == null && !isLoggedIn) {
                TestResult(success = true)
            } else {
                TestResult(success = false, error = "Login state not cleared")
            }
        }

        setContent {
            FireflyApp()
        }
    }

    @Composable
    fun FireflyApp() {
        // Check initial authentication state
        val (email, isLoggedIn) = Storage.getLoginState()
        var isAuthenticated by remember { mutableStateOf(isLoggedIn && email != null) }
        var isNewUser by remember { mutableStateOf(false) }
        var hasSeenWelcome by remember { mutableStateOf(isLoggedIn) } // Existing users skip welcome

        when {
            !isAuthenticated -> {
                SignInView(onAuthenticated = { newUser ->
                    isNewUser = newUser
                    isAuthenticated = true
                })
            }
            isNewUser && !hasSeenWelcome -> {
                val (currentEmail, _) = Storage.getLoginState()
                NewUserView(email = currentEmail ?: "unknown", onGetStarted = {
                    hasSeenWelcome = true
                })
            }
            else -> {
                // Main app with toolbar
                var currentExplorer by remember { mutableStateOf(ToolbarExplorer.MAKE_POST) }

                // Reset triggers - incrementing these forces view recreation
                var makePostResetKey by remember { mutableStateOf(0) }
                var searchResetKey by remember { mutableStateOf(0) }
                var usersResetKey by remember { mutableStateOf(0) }

                // Observe tunables for reactivity
                val tunablesVersion = TunableConstants.version.value
                val backgroundColor = TunableConstants.backgroundColor()

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(backgroundColor)
                ) {
                    // All three explorers kept in memory - show/hide with alpha and zIndex
                    // This preserves scroll position and expanded state when switching
                    // Active view gets zIndex 1 (on top), hidden views get zIndex 0 (behind)

                    // Make Post explorer
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .zIndex(if (currentExplorer == ToolbarExplorer.MAKE_POST) 1f else 0f)
                            .alpha(if (currentExplorer == ToolbarExplorer.MAKE_POST) 1f else 0f)
                    ) {
                        key(makePostResetKey) {
                            PostsView(
                                templateName = "post",
                                showAddButton = true,
                                addButtonText = "add post"
                            )
                        }
                    }

                    // Search explorer
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .zIndex(if (currentExplorer == ToolbarExplorer.SEARCH) 1f else 0f)
                            .alpha(if (currentExplorer == ToolbarExplorer.SEARCH) 1f else 0f)
                    ) {
                        key(searchResetKey) {
                            PostsView(
                                templateName = "query",
                                showAddButton = true,
                                addButtonText = "new search"
                            )
                        }
                    }

                    // Users explorer
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .zIndex(if (currentExplorer == ToolbarExplorer.USERS) 1f else 0f)
                            .alpha(if (currentExplorer == ToolbarExplorer.USERS) 1f else 0f)
                    ) {
                        key(usersResetKey) {
                            PostsView(
                                templateName = "profile",
                                showAddButton = false
                            )
                        }
                    }

                    // Floating toolbar at bottom - zIndex 2 to stay above explorers
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .zIndex(2f),
                        contentAlignment = Alignment.BottomCenter
                    ) {
                        Toolbar(
                            currentExplorer = currentExplorer,
                            onExplorerChange = { newExplorer ->
                                currentExplorer = newExplorer
                            },
                            onResetMakePost = { makePostResetKey++ },
                            onResetSearch = { searchResetKey++ },
                            onResetUsers = { usersResetKey++ }
                        )
                    }
                }
            }
        }
    }

    @Composable
    fun MainContentView() {
        var backgroundColor by remember { mutableStateOf(Color.Gray) }

        LaunchedEffect(Unit) {
            while (true) {
                val isConnected = withContext(Dispatchers.IO) {
                    testConnection()
                }
                backgroundColor = if (isConnected) {
                    AppColors.background
                } else {
                    Color.Gray
                }
                delay(1000)
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
                color = AppColors.textPrimary
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
