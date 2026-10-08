package com.example.truthworld.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.os.Process
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import kotlin.system.exitProcess

/**
 * 🛡️ Runtime Application Self-Protection (RASP) Manager
 *
 * Provides multi-layered runtime defenses:
 * 1. Anti-Hooking & Frida Injection Detection
 * 2. Anti-Debugging & Ptrace TracerPid Detection
 * 3. Root & Privilege Escalation Detection
 * 4. Tampering & Reverse Engineering Framework Detection
 */
object RaspSecurityManager {

    private const val TAG = "RaspSecurityManager"

    // Default Frida server ports
    private val FRIDA_PORTS = listOf(27042, 27043)

    // Known hooking/Frida library signatures in /proc/self/maps
    private val HOOKING_LIBRARIES = listOf(
        "frida-agent",
        "frida-gadget",
        "libfrida",
        "frida",
        "xposed",
        "edxposed",
        "lsposed",
        "substrate",
        "cydia",
        "sandhook",
        "libepic",
        "inline-hook"
    )

    // Known Frida thread names
    private val FRIDA_THREAD_NAMES = listOf(
        "gum-js-loop",
        "gmain",
        "gdbus",
        "frida"
    )

    // Standard root binary locations
    private val ROOT_PATHS = listOf(
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su"
    )

    // Root management package names
    private val ROOT_PACKAGES = listOf(
        "com.topjohnwu.magisk",
        "eu.chainfire.supersu",
        "com.noshufou.android.su",
        "com.koushikdutta.superuser",
        "com.thirdparty.superuser"
    )

    /**
     * Performs a comprehensive security threat scan.
     */
    fun checkSecurityThreats(context: Context): Map<String, Any> {
        val fridaDetected = isFridaDetected()
        val debuggerAttached = isDebuggerAttached()
        val hookingDetected = isHookingFrameworkDetected()
        val rootDetected = isRootDetected(context)
        val emulatorDetected = isEmulator()
        val signatureValid = isSignatureValid(context)

        val threatDetails = mutableListOf<String>()
        if (fridaDetected) threatDetails.add("Frida dynamic instrumentation detected")
        if (debuggerAttached) threatDetails.add("Active debugger or ptrace tracer detected")
        if (hookingDetected) threatDetails.add("Hooking framework injected into memory")
        if (rootDetected) threatDetails.add("Rooted device or su binary detected")
        if (emulatorDetected) threatDetails.add("Untrusted emulator environment detected")
        if (!signatureValid) threatDetails.add("APK signature mismatch: tampered or re-signed modded binary detected")

        // Critical threats that require immediate session termination in release builds
        val isSecure = !fridaDetected && !debuggerAttached && !hookingDetected && signatureValid

        return mapOf(
            "fridaDetected" to fridaDetected,
            "debuggerAttached" to debuggerAttached,
            "hookingDetected" to hookingDetected,
            "rootDetected" to rootDetected,
            "emulatorDetected" to emulatorDetected,
            "signatureValid" to signatureValid,
            "isSecure" to isSecure,
            "threatCount" to threatDetails.size,
            "threatDetails" to threatDetails
        )
    }

    /**
     * Checks for active Frida instrumentation via port scanning, memory maps, and threads.
     */
    fun isFridaDetected(): Boolean {
        // 1. Check memory maps for Frida binaries
        if (checkProcMapsForFrida()) return true

        // 2. Check running thread names
        if (checkThreadNamesForFrida()) return true

        // 3. Check for Frida server listening on localhost ports
        if (checkFridaPorts()) return true

        // 4. Check for frida-server in /data/local/tmp
        val tmpFrida = File("/data/local/tmp/frida-server")
        if (tmpFrida.exists()) return true

        return false
    }

    /**
     * Inspects `/proc/self/maps` for injected Frida libraries.
     */
    private fun checkProcMapsForFrida(): Boolean {
        return try {
            val file = File("/proc/self/maps")
            if (!file.exists()) return false

            BufferedReader(FileReader(file)).use { reader ->
                var line = reader.readLine()
                while (line != null) {
                    val lower = line.lowercase()
                    for (sig in HOOKING_LIBRARIES) {
                        if (lower.contains(sig)) {
                            return true
                        }
                    }
                    line = reader.readLine()
                }
            }
            false
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * Checks running threads for Frida's runtime engine threads.
     */
    private fun checkThreadNamesForFrida(): Boolean {
        return try {
            val rootGroup = Thread.currentThread().threadGroup ?: return false
            var parentGroup = rootGroup
            while (parentGroup.parent != null) {
                parentGroup = parentGroup.parent
            }

            val threads = arrayOfNulls<Thread>(parentGroup.activeCount() * 2)
            val count = parentGroup.enumerate(threads)
            for (i in 0 until count) {
                val threadName = threads[i]?.name?.lowercase() ?: continue
                for (sig in FRIDA_THREAD_NAMES) {
                    if (threadName.contains(sig)) {
                        return true
                    }
                }
            }
            false
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * Attempts socket connection to standard Frida server ports.
     */
    private fun checkFridaPorts(): Boolean {
        for (port in FRIDA_PORTS) {
            try {
                Socket().use { socket ->
                    socket.connect(InetSocketAddress("127.0.0.1", port), 40)
                    return true // Port is open and responding -> Frida server is running!
                }
            } catch (_: Throwable) {
                // Connection failed or timed out -> port is closed (safe)
            }
        }
        return false
    }

    /**
     * Checks if a debugger or ptrace hook is actively attached.
     */
    fun isDebuggerAttached(): Boolean {
        // 1. Android runtime debugger check
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            return true
        }

        // 2. Native Linux ptrace TracerPid check
        return checkTracerPid()
    }

    /**
     * Parses `/proc/self/status` to determine if TracerPid > 0.
     * When GDB, LLDB, or Frida ptrace attaches, TracerPid becomes the PID of the tracer.
     */
    private fun checkTracerPid(): Boolean {
        return try {
            val statusFile = File("/proc/self/status")
            if (!statusFile.exists()) return false

            BufferedReader(FileReader(statusFile)).use { reader ->
                var line = reader.readLine()
                while (line != null) {
                    if (line.startsWith("TracerPid:")) {
                        val pidStr = line.substring("TracerPid:".length).trim()
                        val pid = pidStr.toIntOrNull() ?: 0
                        return pid > 0
                    }
                    line = reader.readLine()
                }
            }
            false
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * Checks for Xposed, Substrate, and other dynamic hooking frameworks.
     */
    fun isHookingFrameworkDetected(): Boolean {
        // Check loaded classes for XposedBridge
        return try {
            ClassLoader.getSystemClassLoader().loadClass("de.robv.android.xposed.XposedBridge")
            true
        } catch (_: ClassNotFoundException) {
            false
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * Checks for root binaries, test-keys build tags, and root management apps.
     */
    fun isRootDetected(context: Context): Boolean {
        // 1. Check build tags for test-keys
        val tags = Build.TAGS
        if (tags != null && tags.contains("test-keys")) {
            return true
        }

        // 2. Check for standard su binary locations
        for (path in ROOT_PATHS) {
            try {
                if (File(path).exists()) return true
            } catch (_: Throwable) {
                // Ignore permission denial
            }
        }

        // 3. Check for installed root manager packages
        val pm = context.packageManager
        for (pkg in ROOT_PACKAGES) {
            try {
                pm.getPackageInfo(pkg, 0)
                return true
            } catch (_: PackageManager.NameNotFoundException) {
                // Not installed
            } catch (_: Throwable) {
                // Ignore
            }
        }

        return false
    }

    /**
     * Detects if running inside an emulator or virtual container.
     */
    fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        val product = Build.PRODUCT.lowercase()

        return fingerprint.startsWith("generic") ||
                fingerprint.startsWith("unknown") ||
                model.contains("google_sdk") ||
                model.contains("emulator") ||
                model.contains("android sdk built for x86") ||
                manufacturer.contains("genymotion") ||
                hardware.contains("goldfish") ||
                hardware.contains("ranchu") ||
                product.contains("sdk_gphone") ||
                product.contains("vbox86p") ||
                File("/dev/socket/qemud").exists() ||
                File("/dev/qemu_pipe").exists()
    }

    /**
     * Computes the SHA-256 fingerprint (hex-encoded) of the APK signing certificate.
     */
    fun getApkSignatureFingerprint(context: Context): String? {
        return try {
            val pm = context.packageManager
            val pkgName = context.packageName
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val packageInfo = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = packageInfo.signingInfo ?: return null
                if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
            } else {
                @Suppress("DEPRECATION")
                val packageInfo = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures.isNullOrEmpty()) return null

            val certBytes = signatures[0].toByteArray()
            val md = MessageDigest.getInstance("SHA-256")
            val digest = md.digest(certBytes)
            digest.joinToString("") { "%02x".format(it) }
        } catch (_: Throwable) {
            null
        }
    }

    /**
     * Verifies that the running APK was signed with an authentic TruthWorld release key,
     * Google Play Signing Key, or legitimate local development key (in debug mode).
     *
     * Detects if an attacker unpacked the APK, modified bytecode/assets, and re-signed with
     * their own unauthorized custom keystore or standard debug.keystore.
     */
    fun isSignatureValid(context: Context): Boolean {
        val currentFingerprint = getApkSignatureFingerprint(context) ?: return false
        val isDebug = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

        // In debug builds, development keystores are permitted
        if (isDebug) {
            return true
        }

        // Check if an explicit release signature SHA-256 is configured in strings.xml
        val resId = context.resources.getIdentifier("truthworld_release_signature_sha256", "string", context.packageName)
        val expectedFingerprint = if (resId != 0) {
            context.getString(resId).lowercase().replace(":", "").replace(" ", "").trim()
        } else {
            null
        }

        if (!expectedFingerprint.isNullOrEmpty()) {
            return currentFingerprint.equals(expectedFingerprint, ignoreCase = true)
        }

        // Standard AOSP / Android Studio / Apktool debug.keystore SHA-256 fingerprints
        val standardDebugCertFingerprints = setOf(
            "18ee590ffb6981882f0c78a08713d2f95c47796d1373595cfbeaa8c32ec8fbfe",
            "7c134aa8a04f2f458197a9226cfd49557a22ef2f05786d34bf62d9804e137c4e",
            "39ffc45731b759600a65684a0c86d88cba17ad43d22b07e997a48fb8bc1a3370"
        )

        // Release build signed with known debug keystore = repackaged modded APK!
        if (standardDebugCertFingerprints.contains(currentFingerprint.lowercase())) {
            return false
        }

        return true
    }

    /**
     * Immediately terminates the application process.
     * Enforced when critical memory manipulation or debugging hooks are detected in release mode.
     */
    fun terminateApp() {
        try {
            Process.killProcess(Process.myPid())
            exitProcess(1)
        } catch (_: Throwable) {
            exitProcess(1)
        }
    }
}
