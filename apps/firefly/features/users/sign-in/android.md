# sign-in Android/e/OS implementation
*client-side authentication UI for Firefly Android app*

## File Structure

Create new files:
- `apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/Storage.kt`
- `apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/SignInView.kt`

Modify existing:
- `apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/MainActivity.kt`

## Storage.kt

SharedPreferences wrapper for login state management:

```kotlin
package com.miso.noobtest

import android.content.Context
import android.content.SharedPreferences
import java.util.UUID

object Storage {
    private lateinit var prefs: SharedPreferences
    private const val PREFS_NAME = "firefly_prefs"
    private const val KEY_DEVICE_ID = "device_id"
    private const val KEY_EMAIL = "email"
    private const val KEY_IS_LOGGED_IN = "is_logged_in"

    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun getDeviceID(): String {
        var deviceID = prefs.getString(KEY_DEVICE_ID, null)
        if (deviceID == null) {
            deviceID = UUID.randomUUID().toString()
            prefs.edit().putString(KEY_DEVICE_ID, deviceID).apply()
            Logger.log("[Storage] Generated new device ID: $deviceID")
        }
        return deviceID
    }

    fun saveLoginState(email: String, isLoggedIn: Boolean) {
        prefs.edit()
            .putString(KEY_EMAIL, email)
            .putBoolean(KEY_IS_LOGGED_IN, isLoggedIn)
            .apply()
        Logger.log("[Storage] Saved login state: email=$email, isLoggedIn=$isLoggedIn")
    }

    fun getLoginState(): Pair<String?, Boolean> {
        val email = prefs.getString(KEY_EMAIL, null)
        val isLoggedIn = prefs.getBoolean(KEY_IS_LOGGED_IN, false)
        return Pair(email, isLoggedIn)
    }

    fun clearLoginState() {
        prefs.edit()
            .remove(KEY_EMAIL)
            .putBoolean(KEY_IS_LOGGED_IN, false)
            .apply()
        Logger.log("[Storage] Cleared login state")
    }
}
```

## SignInView.kt

Jetpack Compose sign-in screen with two-state flow:

```kotlin
package com.miso.noobtest

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

enum class SignInState {
    ENTER_EMAIL,
    ENTER_CODE
}

@Composable
fun SignInView(
    onAuthenticated: (Boolean) -> Unit // Callback with isNewUser flag
) {
    val serverURL = "http://185.96.221.52:8080"
    var currentState by remember { mutableStateOf(SignInState.ENTER_EMAIL) }
    var email by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF40E0D0)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(30.dp)
        ) {
            // Logo
            Text(
                text = "ᕦ(ツ)ᕤ",
                fontSize = 64.sp,
                color = Color.Black
            )

            // Title
            Text(
                text = "Welcome to Firefly",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.Black
            )

            // Content based on state
            when (currentState) {
                SignInState.ENTER_EMAIL -> {
                    EmailEntryView(
                        email = email,
                        onEmailChange = { email = it },
                        isLoading = isLoading,
                        onSendCode = {
                            scope.launch {
                                errorMessage = ""
                                isLoading = true
                                val result = sendCode(serverURL, email)
                                isLoading = false
                                if (result.first) {
                                    currentState = SignInState.ENTER_CODE
                                } else {
                                    errorMessage = result.second
                                }
                            }
                        }
                    )
                }
                SignInState.ENTER_CODE -> {
                    CodeEntryView(
                        email = email,
                        code = code,
                        onCodeChange = { if (it.length <= 4) code = it },
                        isLoading = isLoading,
                        onVerifyCode = {
                            scope.launch {
                                errorMessage = ""
                                isLoading = true
                                val result = verifyCode(serverURL, email, code)
                                isLoading = false
                                if (result.first != null) {
                                    val isNewUser = result.first!!
                                    Storage.saveLoginState(email, true)
                                    Logger.log("[SignIn] User authenticated: $email (new_user: $isNewUser)")
                                    onAuthenticated(isNewUser)
                                } else {
                                    errorMessage = result.second
                                }
                            }
                        },
                        onBackToEmail = {
                            currentState = SignInState.ENTER_EMAIL
                            code = ""
                            errorMessage = ""
                        }
                    )
                }
            }

            // Error message
            if (errorMessage.isNotEmpty()) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.8f))
                ) {
                    Text(
                        text = errorMessage,
                        color = Color.Red,
                        modifier = Modifier.padding(16.dp),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }

        // Loading overlay
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Color.White)
            }
        }
    }
}

@Composable
fun EmailEntryView(
    email: String,
    onEmailChange: (String) -> Unit,
    isLoading: Boolean,
    onSendCode: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Enter your email address",
            color = Color.Black
        )

        TextField(
            value = email,
            onValueChange = onEmailChange,
            placeholder = { Text("email@example.com") },
            enabled = !isLoading,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color.White
            ),
            modifier = Modifier.fillMaxWidth()
        )

        Button(
            onClick = onSendCode,
            enabled = !isLoading && email.isNotEmpty(),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Send Code", fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
fun CodeEntryView(
    email: String,
    code: String,
    onCodeChange: (String) -> Unit,
    isLoading: Boolean,
    onVerifyCode: () -> Unit,
    onBackToEmail: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Enter the 4-digit code",
            color = Color.Black
        )

        Text(
            text = "sent to $email",
            fontSize = 12.sp,
            color = Color.Black.copy(alpha = 0.7f)
        )

        TextField(
            value = code,
            onValueChange = onCodeChange,
            placeholder = { Text("0000") },
            enabled = !isLoading,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            textStyle = LocalTextStyle.current.copy(
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            ),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color.White
            ),
            modifier = Modifier.fillMaxWidth()
        )

        Button(
            onClick = onVerifyCode,
            enabled = !isLoading && code.length == 4,
            colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Verify Code", fontWeight = FontWeight.SemiBold)
        }

        TextButton(
            onClick = onBackToEmail,
            enabled = !isLoading
        ) {
            Text("Use different email", color = Color.Black)
        }
    }
}

// Network functions
private suspend fun sendCode(serverURL: String, email: String): Pair<Boolean, String> {
    return withContext(Dispatchers.IO) {
        try {
            val url = URL("$serverURL/api/auth/send-code")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true

            val jsonBody = JSONObject().apply {
                put("email", email.lowercase().trim())
            }

            connection.outputStream.use { it.write(jsonBody.toString().toByteArray()) }

            val responseCode = connection.responseCode
            val response = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()

            val json = JSONObject(response)
            val status = json.getString("status")

            if (status == "success") {
                Pair(true, "")
            } else {
                Pair(false, json.optString("message", "Failed to send code"))
            }
        } catch (e: Exception) {
            Pair(false, "Connection error: ${e.message}")
        }
    }
}

private suspend fun verifyCode(serverURL: String, email: String, code: String): Pair<Boolean?, String> {
    return withContext(Dispatchers.IO) {
        try {
            val url = URL("$serverURL/api/auth/verify-code")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true

            val deviceID = Storage.getDeviceID()
            val jsonBody = JSONObject().apply {
                put("email", email.lowercase().trim())
                put("code", code)
                put("device_id", deviceID)
            }

            connection.outputStream.use { it.write(jsonBody.toString().toByteArray()) }

            val responseCode = connection.responseCode
            val response = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()

            val json = JSONObject(response)
            val status = json.getString("status")

            if (status == "success") {
                val isNewUser = json.optBoolean("is_new_user", false)
                Pair(isNewUser, "")
            } else {
                Pair(null, json.optString("message", "Verification failed"))
            }
        } catch (e: Exception) {
            Pair(null, "Connection error: ${e.message}")
        }
    }
}
```

## MainActivity.kt

Update to handle three-state authentication:

```kotlin
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

        // Initialize storage and logger
        Storage.init(this)
        Logger.init(this)

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
                MainContentView()
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
                    Color(0xFF40E0D0)
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
```

## Testing

Build and deploy:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.miso.noobtest/.MainActivity
```

Test clear-login endpoint:
```bash
# Setup USB forwarding (once)
adb forward tcp:8081 tcp:8081

# Clear login state
curl http://localhost:8081/test/clear-login

# Restart app
adb shell am force-stop com.miso.noobtest
adb shell am start -n com.miso.noobtest/.MainActivity
```

## UI Design Notes

- Background: Turquoise (#40E0D0) matching iOS
- Logo: ᕦ(ツ)ᕤ at top
- Text fields: Material 3 TextField with white background
- Buttons: Black background with white text
- Loading: Full-screen overlay with CircularProgressIndicator
- Errors: White card with red text
- Uses Jetpack Compose with Material 3
