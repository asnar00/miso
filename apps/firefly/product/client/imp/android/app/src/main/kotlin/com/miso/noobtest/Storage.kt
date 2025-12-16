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
