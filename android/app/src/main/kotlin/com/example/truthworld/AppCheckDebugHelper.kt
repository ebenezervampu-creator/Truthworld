package com.example.truthworld

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Base64
import android.util.Log

object AppCheckDebugHelper {
    private const val TAG = "AppCheckDebugHelper"
    private const val DEBUG_STORE_PREFIX = "com.google.firebase.appcheck.debug.store."
    private const val DEFAULT_DEBUG_TOKEN = "26B7C98E-FC8F-4580-BA97-455ADBE131BC"

    private val STATIC_TOKEN_SUFFIXES =
        listOf(
            "W0RFRkFVTFRd+MTo3NjgyNjYxMDIyNjM6YW5kcm9pZDowZDMzYTAyNDJmMjEwNmFjMTQzYWYy",
            "W0RFRkFVTFRd+MTo3NjgyNjYxMDIyNjM6YW5kcm9pZDpjMDc2YTE0NTU1MjBmNWNkMTQzYWYy",
            "W0RFRkFVTFRd+MTo3NjgyNjYxMDIyNjM6YW5kcm9pZDplOTg5NTIwM2VmMTcyZWM2MTQzYWYy",
            "W0RFRkFVTFRd+MTo3NjgyNjYxMDIyNjM6YW5kcm9pZDo5NjVkOThlMjQ0MjI1ZGM0MTQzYWYy",
            "W0RFRkFVTFRd+MTo3NjgyNjYxMDIyNjM6YW5kcm9pZDplNWM5OGRkM2ZiNmM2Nzg4MTQzYWYy",
            "[DEFAULT]",
            "truthworld-1",
        )

    @Suppress("TooGenericExceptionCaught")
    fun init(context: Context) {
        val isDebug = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebug) return

        val tokenResId =
            context.resources.getIdentifier(
                "firebase_app_check_debug_token",
                "string",
                context.packageName,
            )
        val debugToken = if (tokenResId != 0) context.getString(tokenResId) else DEFAULT_DEBUG_TOKEN
        val prefsKeys = resolveAppCheckStoreKeys(context)

        for (prefsKey in prefsKeys) {
            try {
                val prefs = context.getSharedPreferences(prefsKey, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", debugToken)
                    .apply()
                Log.d(TAG, "Set App Check debug token ($debugToken) in prefs: $prefsKey")
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to write debug token to prefs $prefsKey: ${t.message}")
            }
        }
    }

    @Suppress("TooGenericExceptionCaught")
    private fun resolveAppCheckStoreKeys(context: Context): Set<String> {
        val prefsKeys = mutableSetOf<String>()

        // 1. Retrieve persistenceKey via reflection
        try {
            val firebaseAppClass = Class.forName("com.google.firebase.FirebaseApp")
            val getAppsMethod = firebaseAppClass.getMethod("getApps", Context::class.java)
            val apps = getAppsMethod.invoke(null, context) as? List<*>
            if (!apps.isNullOrEmpty()) {
                val getInstanceMethod = firebaseAppClass.getMethod("getInstance")
                val app = getInstanceMethod.invoke(null)
                val getPersistenceKeyMethod = firebaseAppClass.getMethod("getPersistenceKey")
                val persistenceKey = getPersistenceKeyMethod.invoke(app) as String
                prefsKeys.add("$DEBUG_STORE_PREFIX$persistenceKey")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to get Firebase persistence key: ${t.message}")
        }

        // 2. Dynamic key variants based on google_app_id
        try {
            val appIdResId = context.resources.getIdentifier("google_app_id", "string", context.packageName)
            if (appIdResId != 0) {
                val appId = context.getString(appIdResId)
                val nameBytes = "[DEFAULT]".toByteArray(Charsets.UTF_8)
                val appIdBytes = appId.toByteArray(Charsets.UTF_8)

                val nameB64Def = Base64.encodeToString(nameBytes, Base64.DEFAULT)
                val appIdB64Def = Base64.encodeToString(appIdBytes, Base64.DEFAULT)
                prefsKeys.add("$DEBUG_STORE_PREFIX$nameB64Def+$appIdB64Def")

                val nameB64NoWrap = Base64.encodeToString(nameBytes, Base64.NO_WRAP)
                val appIdB64NoWrap = Base64.encodeToString(appIdBytes, Base64.NO_WRAP)
                prefsKeys.add("$DEBUG_STORE_PREFIX$nameB64NoWrap+$appIdB64NoWrap")
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to resolve google_app_id dynamically: ${t.message}")
        }

        // 3. Fallback pre-calculated keys
        for (suffix in STATIC_TOKEN_SUFFIXES) {
            prefsKeys.add("$DEBUG_STORE_PREFIX$suffix")
        }

        return prefsKeys
    }
}
