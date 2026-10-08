# TruthWorld Production ProGuard & R8 Configuration

# Flutter Framework & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Cashfree Payment Gateway SDK
-keep class com.cashfree.** { *; }
-dontwarn com.cashfree.**
-keep class com.flutter.cashfree_pg_sdk.** { *; }
-dontwarn com.flutter.cashfree_pg_sdk.**

# Firebase SDKs
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# UCrop (Image Cropper)
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Media3 & ExoPlayer Video Engine
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Kotlin Coroutines & Reflection
-keepclassmembers class * extends kotlin.jvm.internal.CallableReference {
    public java.lang.String getName();
    public java.lang.String getSignature();
}
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# Native JNI Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve Serializable & Enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# -----------------------------------------------------------------------------
# Security & Anti-Reverse Engineering Hardening
# -----------------------------------------------------------------------------
# Strip non-critical Android logging in release builds to prevent information leakage
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# R8 Optimization & Method inlining
-allowaccessmodification
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Preserve RASP Security Manager entry points for Flutter MethodChannel
-keep class com.example.truthworld.security.RaspSecurityManager {
    public static *** checkSecurityThreats(...);
    public static *** terminateApp(...);
    public static *** isSignatureValid(...);
    public static *** isFridaDetected(...);
    public static *** isDebuggerAttached(...);
    public static *** isHookingFrameworkDetected(...);
    public static *** isRootDetected(...);
}

# Google Play Core & Flutter Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Google Play Integrity & Firebase App Check
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**


