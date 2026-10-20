import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

android {
    namespace = "com.example.truthworld"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.truthworld.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    signingConfigs {
        create("release") {
            val keyAliasProp =
                keystoreProperties.getProperty("keyAlias")
                    ?: localProperties.getProperty("keyAlias")
                    ?: System.getenv("KEY_ALIAS")
            val keyPasswordProp =
                keystoreProperties.getProperty("keyPassword")
                    ?: localProperties.getProperty("keyPassword")
                    ?: System.getenv("KEY_PASSWORD")
            val storeFileProp =
                keystoreProperties.getProperty("storeFile")
                    ?: localProperties.getProperty("storeFile")
                    ?: System.getenv("KEYSTORE_FILE")
            val storePasswordProp =
                keystoreProperties.getProperty("storePassword")
                    ?: localProperties.getProperty("storePassword")
                    ?: System.getenv("KEYSTORE_PASSWORD")

            if (storeFileProp != null) {
                val candidate = File(storeFileProp)
                val resolvedFile =
                    when {
                        candidate.isAbsolute && candidate.exists() -> candidate
                        rootProject.file(storeFileProp).exists() -> rootProject.file(storeFileProp)
                        rootProject.file("../$storeFileProp").exists() -> rootProject.file("../$storeFileProp")
                        else -> null
                    }
                if (resolvedFile != null && resolvedFile.exists()) {
                    keyAlias = keyAliasProp
                    keyPassword = keyPasswordProp
                    storeFile = resolvedFile
                    storePassword = storePasswordProp
                }
            }
        }
    }

    androidResources {
        noCompress += listOf("bin", "Z", "frag", "glsl", "json", "ttf", "otf")
    }

    buildTypes {
        debug {
            isCrunchPngs = false
        }
        release {
            val releaseSigning = signingConfigs.findByName("release")
            if (releaseSigning != null && releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                signingConfig = releaseSigning
            } else {
                throw GradleException(
                    "Release keystore not found. Set KEYSTORE_FILE, KEYSTORE_PASSWORD, " +
                        "KEY_ALIAS, and KEY_PASSWORD environment variables, or configure " +
                        "signing in local.properties. Never ship with debug signing.",
                )
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    flavorDimensions += "mode"
    productFlavors {
        create("app") {
            dimension = "mode"
            applicationId = "com.truthworld.app"
            resValue("string", "app_name", "Truthworld")
        }
        create("studio") {
            dimension = "mode"
            applicationId = "com.truthworld.studio"
            resValue("string", "app_name", "Truthworld Studio")
        }
        create("admin") {
            dimension = "mode"
            applicationId = "com.truthworld.admin"
            resValue("string", "app_name", "Truthworld Admin")
        }
        create("advertiser") {
            dimension = "mode"
            applicationId = "com.truthworld.advertiser"
            resValue("string", "app_name", "Truthworld Advertiser")
        }
    }

    bundle {
        abi {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        language {
            enableSplit = true
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
