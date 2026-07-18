package com.example.truthworld

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
