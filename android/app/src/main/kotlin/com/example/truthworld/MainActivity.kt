package com.example.truthworld

import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PIP_CHANNEL = "com.example.truthworld/pip"
    private var pipChannel: MethodChannel? = null
    private var isAutoEnterPipEnabled = false
    private var pipAspectRatioWidth = 16
    private var pipAspectRatioHeight = 9

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create high-importance notification channel for Android 8.0+
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channelId = "truthworld_notifications"
            val channelName = "Truthworld Notifications"
            val channelDescription = "High importance notifications from Truthworld"
            val importance = android.app.NotificationManager.IMPORTANCE_HIGH
            val channel = android.app.NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                lightColor = android.graphics.Color.RED
                enableVibration(true)
                setShowBadge(true)
                val audioAttributes = android.media.AudioAttributes.Builder()
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, audioAttributes)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.createNotificationChannel(channel)
        }

        // Check if the application is running in debug/development mode
        val isDebug = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebug) {
            val tokenResId = resources.getIdentifier("firebase_app_check_debug_token", "string", packageName)
            val debugToken = if (tokenResId != 0) getString(tokenResId) else "26B7C98E-FC8F-4580-BA97-455ADBE131BC"
            val prefsKeys = mutableListOf<String>()

            // 1. Try dynamic generation using resource lookup for google_app_id
            try {
                val appIdResId = resources.getIdentifier("google_app_id", "string", packageName)
                if (appIdResId != 0) {
                    val appId = getString(appIdResId)
                    val nameBytes = "[DEFAULT]".toByteArray(Charsets.UTF_8)
                    val appIdBytes = appId.toByteArray(Charsets.UTF_8)
                    val nameBase64 = android.util.Base64.encodeToString(nameBytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP).trim()
                    val appIdBase64 = android.util.Base64.encodeToString(appIdBytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP).trim()
                    prefsKeys.add("com.google.firebase.appcheck.debug.store.$nameBase64+$appIdBase64")
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to resolve google_app_id dynamically: ${e.message}", e)
            }

            // 2. Add pre-calculated key for current config
            prefsKeys.add("com.google.firebase.appcheck.debug.store.W0RFRkFVTFRd+MTo3NjgyNjYxMDIyNjM6YW5kcm9pZDplNWM5OGRkM2ZiNmM2Nzg4MTQzYWYy")

            // 3. Keep old keys just in case
            prefsKeys.add("com.google.firebase.appcheck.debug.store.[DEFAULT]")
            prefsKeys.add("com.google.firebase.appcheck.debug.store.truthworld-1")

            for (prefsKey in prefsKeys) {
                try {
                    val prefs = getSharedPreferences(prefsKey, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", debugToken)
                        .apply()
                    android.util.Log.d("MainActivity", "Set App Check debug token in prefs: $prefsKey")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to write to prefs $prefsKey: ${e.message}")
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val ratio = call.argument<Double>("aspectRatio") ?: 1.777
                    enterPipMode(ratio)
                    result.success(null)
                }
                "setAutoEnterPip" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val ratio = call.argument<Double>("aspectRatio") ?: 1.777
                    updateAutoPipSettings(enabled, ratio)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enterPipMode(ratio: Double) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val rational = Rational((ratio * 10000).toInt(), 10000)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rational)
                .build()
            enterPictureInPictureMode(params)
        }
    }

    private fun updateAutoPipSettings(enabled: Boolean, ratio: Double) {
        isAutoEnterPipEnabled = enabled
        pipAspectRatioWidth = (ratio * 10000).toInt()
        pipAspectRatioHeight = 10000
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val rational = Rational(pipAspectRatioWidth, pipAspectRatioHeight)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rational)
                .setAutoEnterEnabled(enabled)
                .build()
            setPictureInPictureParams(params)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isAutoEnterPipEnabled) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val rational = Rational(pipAspectRatioWidth, pipAspectRatioHeight)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .build()
                enterPictureInPictureMode(params)
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }
}
