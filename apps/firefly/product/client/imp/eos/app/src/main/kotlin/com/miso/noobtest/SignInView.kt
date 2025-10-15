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
