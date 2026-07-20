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
            val debugToken = "5542fb9f-655d-48d1-a32a-eefa5dc82365"
            // Set the static App Check debug token in debug mode so the emulator/device doesn't generate a new one
            val prefsKeys = listOf(
                "com.google.firebase.appcheck.debug.store.[DEFAULT]",
                "com.google.firebase.appcheck.debug.store.truthworld-1"
            )
            for (prefsKey in prefsKeys) {
                val prefs = getSharedPreferences(prefsKey, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", debugToken)
                    .apply()
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
