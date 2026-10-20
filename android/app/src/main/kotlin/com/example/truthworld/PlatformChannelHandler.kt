package com.example.truthworld

import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.WindowManager
import com.example.truthworld.security.RaspSecurityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class PlatformChannelHandler(private val activity: Activity) {
    companion object {
        private const val INSTALLER_CHANNEL = "com.example.truthworld/installer"
        private const val RASP_CHANNEL = "com.example.truthworld/rasp"
        private const val SCREEN_SECURITY_CHANNEL = "com.example.truthworld/screen_security"
        private const val TAG = "PlatformChannelHandler"
    }

    fun registerChannels(messenger: BinaryMessenger) {
        setupInstallerChannel(messenger)
        setupRaspChannel(messenger)
        setupScreenSecurityChannel(messenger)
    }

    @Suppress("TooGenericExceptionCaught")
    private fun setupInstallerChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstallerSource") {
                try {
                    val pkg = activity.packageName
                    val pm = activity.packageManager
                    val installer: String? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            pm.getInstallSourceInfo(pkg).installingPackageName
                        } else {
                            @Suppress("DEPRECATION")
                            pm.getInstallerPackageName(pkg)
                        }
                    val source =
                        when (installer) {
                            "com.android.vending" -> "play_store"
                            "com.sec.android.app.samsungapps" -> "samsung_galaxy_store"
                            "com.amazon.venezia" -> "amazon_appstore"
                            else -> "sideloaded"
                        }
                    result.success(source)
                } catch (e: Exception) {
                    Log.w(TAG, "getInstallerSource error: ${e.message}")
                    result.success("sideloaded")
                }
            } else {
                result.notImplemented()
            }
        }
    }

    @Suppress("TooGenericExceptionCaught")
    private fun setupRaspChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, RASP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSecurityThreats" -> {
                    Thread {
                        try {
                            val threats = RaspSecurityManager.checkSecurityThreats(activity.applicationContext)
                            activity.runOnUiThread {
                                result.success(threats)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "checkSecurityThreats failed: ${e.message}")
                            activity.runOnUiThread {
                                result.error("RASP_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "terminateApp" -> {
                    RaspSecurityManager.terminateApp()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Screen Security channel: FLAG_SECURE protection against screenshots,
    // screen recording, and task switcher preview leaks
    @Suppress("TooGenericExceptionCaught")
    private fun setupScreenSecurityChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, SCREEN_SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureMode" -> {
                    try {
                        activity.runOnUiThread {
                            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "enableSecureMode failed: ${e.message}")
                        result.error("FLAG_SECURE_ERROR", e.message, null)
                    }
                }
                "disableSecureMode" -> {
                    try {
                        activity.runOnUiThread {
                            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "disableSecureMode failed: ${e.message}")
                        result.error("FLAG_SECURE_ERROR", e.message, null)
                    }
                }
                "isSecureModeEnabled" -> {
                    val isSecure = (activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
                    result.success(isSecure)
                }
                else -> result.notImplemented()
            }
        }
    }
}
