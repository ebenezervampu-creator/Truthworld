package com.example.truthworld

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.util.Rational
import com.example.truthworld.security.RaspSecurityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val PIP_CHANNEL = "com.example.truthworld/pip"

        private const val DEFAULT_PIP_ASPECT_RATIO = 1.777
        private const val MIN_PIP_ASPECT_RATIO = 0.418
        private const val MAX_PIP_ASPECT_RATIO = 2.39
        private const val PIP_RATIO_MULTIPLIER = 10000
        private const val DEFAULT_PIP_WIDTH = 16
        private const val DEFAULT_PIP_HEIGHT = 9

        private const val ACTION_PIP_PREV = "com.example.truthworld.PIP_PREV"
        private const val ACTION_PIP_PLAY_PAUSE = "com.example.truthworld.PIP_PLAY_PAUSE"
        private const val ACTION_PIP_NEXT = "com.example.truthworld.PIP_NEXT"

        private const val REQUEST_CODE_PREV = 101
        private const val REQUEST_CODE_PLAY_PAUSE = 102
        private const val REQUEST_CODE_NEXT = 103

        private const val TAG = "MainActivity"
    }

    private var pipChannel: MethodChannel? = null
    private var isAutoEnterPipEnabled = false
    private var pipAspectRatioWidth = DEFAULT_PIP_WIDTH
    private var pipAspectRatioHeight = DEFAULT_PIP_HEIGHT
    private var pipIsPlaying = true
    private var pipHasPrevious = false
    private var pipHasNext = true

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_PIP_PREV -> pipChannel?.invokeMethod("onPipActionPrevious", null)
                ACTION_PIP_PLAY_PAUSE -> pipChannel?.invokeMethod("onPipActionPlayPause", null)
                ACTION_PIP_NEXT -> pipChannel?.invokeMethod("onPipActionNext", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerPipReceiver()
        initNotificationChannel()
        AppCheckDebugHelper.init(this)
        checkSecurityOnLaunch()
    }

    private fun registerPipReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_PIP_PREV)
            addAction(ACTION_PIP_PLAY_PAUSE)
            addAction(ACTION_PIP_NEXT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipActionReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(pipActionReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "unregisterReceiver failed: ${e.message}")
        }
        super.onDestroy()
    }

    private fun initNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "truthworld_notifications"
            val channelName = "Truthworld Notifications"
            val channelDescription = "High importance notifications from Truthworld"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel =
                NotificationChannel(channelId, channelName, importance).apply {
                    description = channelDescription
                    enableLights(true)
                    lightColor = Color.parseColor("#14EAB2")
                    enableVibration(true)
                    setShowBadge(true)
                    val audioAttributes =
                        AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .build()
                    setSound(Settings.System.DEFAULT_NOTIFICATION_URI, audioAttributes)
                }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun checkSecurityOnLaunch() {
        val isDebug = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebug) return
        if (RaspSecurityManager.isFridaDetected() ||
            RaspSecurityManager.isDebuggerAttached() ||
            !RaspSecurityManager.isSignatureValid(applicationContext)
        ) {
            Log.e(TAG, "Critical security integrity violation detected at launch. Terminating.")
            RaspSecurityManager.terminateApp()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        setupPipChannel(messenger)
        PlatformChannelHandler(this).registerChannels(messenger)
    }

    private fun setupPipChannel(messenger: BinaryMessenger) {
        pipChannel = MethodChannel(messenger, PIP_CHANNEL)
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val ratio = call.argument<Double>("aspectRatio") ?: DEFAULT_PIP_ASPECT_RATIO
                    pipIsPlaying = call.argument<Boolean>("isPlaying") ?: pipIsPlaying
                    pipHasPrevious = call.argument<Boolean>("hasPrevious") ?: pipHasPrevious
                    pipHasNext = call.argument<Boolean>("hasNext") ?: pipHasNext
                    enterPipMode(ratio)
                    result.success(null)
                }
                "setAutoEnterPip" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val ratio = call.argument<Double>("aspectRatio") ?: DEFAULT_PIP_ASPECT_RATIO
                    pipIsPlaying = call.argument<Boolean>("isPlaying") ?: pipIsPlaying
                    pipHasPrevious = call.argument<Boolean>("hasPrevious") ?: pipHasPrevious
                    pipHasNext = call.argument<Boolean>("hasNext") ?: pipHasNext
                    updateAutoPipSettings(enabled, ratio)
                    result.success(null)
                }
                "updatePipActions" -> {
                    pipIsPlaying = call.argument<Boolean>("isPlaying") ?: pipIsPlaying
                    pipHasPrevious = call.argument<Boolean>("hasPrevious") ?: pipHasPrevious
                    pipHasNext = call.argument<Boolean>("hasNext") ?: pipHasNext
                    updatePipParams(isAutoEnterPipEnabled)
                    result.success(null)
                }
                "isPipSupported" -> {
                    val supported =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        } else {
                            false
                        }
                    result.success(supported)
                }
                "isInPip" -> {
                    val inPip =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            isInPictureInPictureMode
                        } else {
                            false
                        }
                    result.success(inPip)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildPipActions(): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()

        val actions = ArrayList<RemoteAction>(3)

        // Previous Video Action
        val prevIntent = PendingIntent.getBroadcast(
            this,
            REQUEST_CODE_PREV,
            Intent(ACTION_PIP_PREV).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val prevIcon = Icon.createWithResource(this, android.R.drawable.ic_media_previous)
        val prevAction = RemoteAction(prevIcon, "Previous", "Previous video", prevIntent)
        prevAction.isEnabled = pipHasPrevious
        actions.add(prevAction)

        // Play / Pause Action
        val playPauseIntent = PendingIntent.getBroadcast(
            this,
            REQUEST_CODE_PLAY_PAUSE,
            Intent(ACTION_PIP_PLAY_PAUSE).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val iconRes = if (pipIsPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val title = if (pipIsPlaying) "Pause" else "Play"
        val playPauseIcon = Icon.createWithResource(this, iconRes)
        val playPauseAction = RemoteAction(playPauseIcon, title, title, playPauseIntent)
        actions.add(playPauseAction)

        // Next Video Action
        val nextIntent = PendingIntent.getBroadcast(
            this,
            REQUEST_CODE_NEXT,
            Intent(ACTION_PIP_NEXT).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val nextIcon = Icon.createWithResource(this, android.R.drawable.ic_media_next)
        val nextAction = RemoteAction(nextIcon, "Next", "Next video", nextIntent)
        nextAction.isEnabled = pipHasNext
        actions.add(nextAction)

        return actions
    }

    private fun buildPipParams(autoEnter: Boolean): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null

        val clampedRatio = (pipAspectRatioWidth.toDouble() / pipAspectRatioHeight.toDouble())
            .coerceIn(MIN_PIP_ASPECT_RATIO, MAX_PIP_ASPECT_RATIO)
        val rational = Rational((clampedRatio * PIP_RATIO_MULTIPLIER).toInt(), PIP_RATIO_MULTIPLIER)

        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(rational)
            .setActions(buildPipActions())

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
        }

        return builder.build()
    }

    private fun updatePipParams(autoEnter: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = buildPipParams(autoEnter)
                if (params != null) {
                    setPictureInPictureParams(params)
                }
            } catch (e: Exception) {
                Log.e(TAG, "setPictureInPictureParams failed: ${e.message}")
            }
        }
    }

    @Suppress("TooGenericExceptionCaught")
    private fun enterPipMode(ratio: Double) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (isInPictureInPictureMode) return
            val clampedRatio = ratio.coerceIn(MIN_PIP_ASPECT_RATIO, MAX_PIP_ASPECT_RATIO)
            pipAspectRatioWidth = (clampedRatio * PIP_RATIO_MULTIPLIER).toInt()
            pipAspectRatioHeight = PIP_RATIO_MULTIPLIER
            try {
                val params = buildPipParams(isAutoEnterPipEnabled)
                if (params != null) {
                    enterPictureInPictureMode(params)
                }
            } catch (e: Exception) {
                Log.e(TAG, "enterPictureInPictureMode failed: ${e.message}")
            }
        }
    }

    @Suppress("TooGenericExceptionCaught")
    private fun updateAutoPipSettings(
        enabled: Boolean,
        ratio: Double,
    ) {
        isAutoEnterPipEnabled = enabled
        val clampedRatio = ratio.coerceIn(MIN_PIP_ASPECT_RATIO, MAX_PIP_ASPECT_RATIO)
        pipAspectRatioWidth = (clampedRatio * PIP_RATIO_MULTIPLIER).toInt()
        pipAspectRatioHeight = PIP_RATIO_MULTIPLIER
        updatePipParams(enabled)
    }

    @Suppress("TooGenericExceptionCaught")
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (isInPictureInPictureMode || !isAutoEnterPipEnabled) return

            // On Android 12+ (API 31+), if autoEnterEnabled is true, the OS handles
            // the transition automatically during gestures. Calling enterPictureInPictureMode()
            // here causes a window collision and aborts PiP.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return
            }

            // For Android 8.0 - 11 (API 26 - 30), manually trigger PiP transition
            try {
                val params = buildPipParams(false)
                if (params != null) {
                    enterPictureInPictureMode(params)
                }
            } catch (e: Exception) {
                Log.e(TAG, "onUserLeaveHint enterPictureInPictureMode failed: ${e.message}")
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
        if (isInPictureInPictureMode) {
            updatePipParams(isAutoEnterPipEnabled)
        }
    }
}
