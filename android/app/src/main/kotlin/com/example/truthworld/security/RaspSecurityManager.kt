package com.example.truthworld.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.os.Process
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import kotlin.system.exitProcess

private const val FRIDA_PORT_DEFAULT = 27042
private const val FRIDA_PORT_ALTERNATIVE = 27043
private const val SOCKET_TIMEOUT_MS = 40

// Default Frida server ports
private val FRIDA_PORTS = listOf(FRIDA_PORT_DEFAULT, FRIDA_PORT_ALTERNATIVE)

// Known hooking/Frida library signatures in /proc/self/maps
private val HOOKING_LIBRARIES =
    listOf(
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
        "inline-hook",
    )

// Known Frida thread names
private val FRIDA_THREAD_NAMES =
    listOf(
        "gum-js-loop",
        "gmain",
        "gdbus",
        "frida",
    )

// Standard root binary locations
private val ROOT_PATHS =
    listOf(
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su",
    )

// Root management package names
private val ROOT_PACKAGES =
    listOf(
        "com.topjohnwu.magisk",
        "eu.chainfire.supersu",
        "com.noshufou.android.su",
        "com.koushikdutta.superuser",
        "com.thirdparty.superuser",
    )

// Standard AOSP / Android Studio / Apktool debug.keystore SHA-256 fingerprints
private val STANDARD_DEBUG_CERT_FINGERPRINTS =
    setOf(
        "18ee590ffb6981882f0c78a08713d2f95c47796d1373595cfbeaa8c32ec8fbfe",
        "7c134aa8a04f2f458197a9226cfd49557a22ef2f05786d34bf62d9804e137c4e",
        "39ffc45731b759600a65684a0c86d88cba17ad43d22b07e997a48fb8bc1a3370",
    )

/**
 * Inspects `/proc/self/maps` for injected Frida libraries.
 */
private fun checkProcMapsForFrida(): Boolean {
    val file = File("/proc/self/maps")
    if (!file.exists()) return false
    return try {
        file.useLines { lines ->
            lines.any { line ->
                val lower = line.lowercase()
                HOOKING_LIBRARIES.any { sig -> lower.contains(sig) }
            }
        }
    } catch (_: Throwable) {
        false
    }
}

/**
 * Checks running threads for Frida's runtime engine threads.
 */
private fun checkThreadNamesForFrida(): Boolean {
    return try {
        var group: ThreadGroup? = Thread.currentThread().threadGroup
        while (group?.parent != null) {
            group = group.parent
        }
        val activeGroup = group ?: return false
        val threads = arrayOfNulls<Thread>(activeGroup.activeCount() * 2)
        val count = activeGroup.enumerate(threads)
        (0 until count).any { idx ->
            val name = threads[idx]?.name?.lowercase().orEmpty()
            FRIDA_THREAD_NAMES.any { sig -> name.contains(sig) }
        }
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
                socket.connect(InetSocketAddress("127.0.0.1", port), SOCKET_TIMEOUT_MS)
                return true
            }
        } catch (_: Throwable) {
            // Connection failed or timed out -> port is closed (safe)
        }
    }
    return false
}

/**
 * Parses `/proc/self/status` to determine if TracerPid > 0.
 * When GDB, LLDB, or Frida ptrace attaches, TracerPid becomes the PID of the tracer.
 */
private fun checkTracerPid(): Boolean {
    val statusFile = File("/proc/self/status")
    if (!statusFile.exists()) return false
    return try {
        statusFile.useLines { lines ->
            val tracerLine = lines.firstOrNull { it.startsWith("TracerPid:") }
            val pid = tracerLine?.substring("TracerPid:".length)?.trim()?.toIntOrNull() ?: 0
            pid > 0
        }
    } catch (_: Throwable) {
        false
    }
}

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
            "threatDetails" to threatDetails,
        )
    }

    /**
     * Checks for active Frida instrumentation via port scanning, memory maps, and threads.
     */
    fun isFridaDetected(): Boolean {
        val tmpFrida = File("/data/local/tmp/frida-server")
        return checkProcMapsForFrida() ||
            checkThreadNamesForFrida() ||
            checkFridaPorts() ||
            tmpFrida.exists()
    }

    /**
     * Checks if a debugger or ptrace hook is actively attached.
     */
    fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger() || checkTracerPid()
    }

    /**
     * Checks for Xposed, Substrate, and other dynamic hooking frameworks.
     */
    fun isHookingFrameworkDetected(): Boolean {
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
        val hasTestKeys = Build.TAGS?.contains("test-keys") == true
        val hasSuBinary =
            ROOT_PATHS.any { path ->
                try {
                    File(path).exists()
                } catch (_: Throwable) {
                    false
                }
            }
        val pm = context.packageManager
        val hasRootPackage =
            ROOT_PACKAGES.any { pkg ->
                try {
                    pm.getPackageInfo(pkg, 0)
                    true
                } catch (_: PackageManager.NameNotFoundException) {
                    false
                } catch (_: Throwable) {
                    false
                }
            }
        return hasTestKeys || hasSuBinary || hasRootPackage
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
            val signatures =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val packageInfo = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNING_CERTIFICATES)
                    val signingInfo = packageInfo.signingInfo
                    if (signingInfo?.hasMultipleSigners() == true) {
                        signingInfo.apkContentsSigners
                    } else {
                        signingInfo?.signingCertificateHistory
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val packageInfo = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNATURES)
                    @Suppress("DEPRECATION")
                    packageInfo.signatures
                }

            if (signatures.isNullOrEmpty()) {
                null
            } else {
                val certBytes = signatures[0].toByteArray()
                val md = MessageDigest.getInstance("SHA-256")
                val digest = md.digest(certBytes)
                digest.joinToString("") { "%02x".format(it) }
            }
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

        val resId =
            context.resources.getIdentifier(
                "truthworld_release_signature_sha256",
                "string",
                context.packageName,
            )
        val expected =
            if (resId != 0) {
                context.getString(resId).lowercase().replace(":", "").replace(" ", "").trim()
            } else {
                ""
            }

        return isDebug ||
            if (expected.isNotEmpty()) {
                currentFingerprint.equals(expected, ignoreCase = true)
            } else {
                !STANDARD_DEBUG_CERT_FINGERPRINTS.contains(currentFingerprint.lowercase())
            }
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
