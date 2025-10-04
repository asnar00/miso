package com.miso.noobtest

import android.os.Bundle
import android.util.Log
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException

class MainActivity : ComponentActivity() {
    private val client = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var backgroundColor by remember { mutableStateOf(Color.Gray) }
            val scope = rememberCoroutineScope()

            LaunchedEffect(Unit) {
                scope.launch {
                    while (true) {
                        backgroundColor = testConnection()
                        delay(1000) // Check every second
                    }
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
                    fontSize = 60.sp,
                    color = Color.Black
                )
            }
        }
    }

    private suspend fun testConnection(): Color {
        return withContext(Dispatchers.IO) {
            try {
                Log.d("NoobTest", "Attempting connection...")
                val request = Request.Builder()
                    .url("http://185.96.221.52:8080/api/ping")
                    .build()

                val response = client.newCall(request).execute()
                Log.d("NoobTest", "Response code: ${response.code}")
                if (response.isSuccessful) {
                    Log.d("NoobTest", "Connection successful!")
                    Color(0xFF40E0D0) // Turquoise
                } else {
                    Log.d("NoobTest", "Connection failed: ${response.code}")
                    Color.Gray
                }
            } catch (e: IOException) {
                Log.e("NoobTest", "Connection error: ${e.message}")
                Color.Gray
            }
        }
    }
}
