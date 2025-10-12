package com.miso.noobtest

import android.content.Context
import android.provider.Settings
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * Simple logging system that writes locally and sends to server
 */
object Logger {
    private const val TAG = "MisoLogger"
    private const val SERVER_URL = "http://185.96.221.52:8080"
    private const val LOG_FILE_NAME = "app.log"

    private lateinit var context: Context
    private lateinit var deviceID: String

    private val client = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .writeTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .build()

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    /**
     * Initialize the logger with application context
     * Must be called from Application.onCreate() or MainActivity.onCreate()
     */
    fun init(appContext: Context) {
        context = appContext.applicationContext
        deviceID = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        Log.d(TAG, "Logger initialized. Device ID: $deviceID")
    }

    /**
     * Log a message - writes locally and sends to server
     */
    fun log(message: String) {
        Log.d(TAG, "log() called: $message")
        val timestamp = System.currentTimeMillis() / 1000.0
        val formattedTime = dateFormat.format(Date())
        val entry = "$formattedTime | $message\n"

        // 1. Write to local file (synchronously - we want this to succeed)
        writeToLocalFile(entry)

        // 2. Send to server (asynchronously - fire and forget)
        CoroutineScope(Dispatchers.IO).launch {
            sendToServer(message, timestamp)
        }
    }

    private fun writeToLocalFile(entry: String) {
        try {
            val logFile = File(context.filesDir, LOG_FILE_NAME)
            logFile.appendText(entry)
        } catch (e: Exception) {
            // Silently fail - don't want logging to crash the app
        }
    }

    private fun sendToServer(message: String, timestamp: Double) {
        try {
            Log.d(TAG, "sendToServer() called")
            val json = JSONObject().apply {
                put("device_id", deviceID)
                put("timestamp", timestamp)
                put("message", message)
            }

            val body = json.toString().toRequestBody("application/json".toMediaType())

            val request = Request.Builder()
                .url("$SERVER_URL/api/log")
                .post(body)
                .build()

            Log.d(TAG, "Making HTTP POST to $SERVER_URL/api/log")
            // Fire and forget - don't care if it fails
            val response = client.newCall(request).execute()
            Log.d(TAG, "Server response: ${response.code}")
            response.close()
        } catch (e: Exception) {
            Log.e(TAG, "sendToServer() failed: ${e.message}", e)
        }
    }

    /**
     * Get the local log file path (for debugging)
     */
    fun getLogFilePath(): String {
        return File(context.filesDir, LOG_FILE_NAME).absolutePath
    }

    /**
     * Get device ID (for querying server logs)
     */
    fun getDeviceID(): String {
        return deviceID
    }
}
