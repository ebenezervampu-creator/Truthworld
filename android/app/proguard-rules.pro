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
