package com.example.truthworld

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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
