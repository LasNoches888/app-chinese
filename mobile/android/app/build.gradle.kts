plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_chinese"
    // thermion_flutter's Android dependencies (androidx.annotation,
    // androidx.exifinterface) need compileSdk 34+; flutter.compileSdkVersion
    // was still 33.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.app_chinese"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // llamadart's llama.cpp native runtime ships for arm64/x64 — real
        // phones are arm64, so restrict to that and skip x86/armv7 .so files.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    // Checked-in debug.keystore (not secret — it's the debug key) so every
    // build, local or CI, signs with the same key. Without this, each fresh
    // CI runner auto-generates its own random debug key and Android refuses
    // to install the new APK over the previous one ("package conflicts with
    // an existing package") — updates silently fail to land on the device.
    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // llamadart's native bindings and Dart native-assets resolution
            // rely on reflection R8 can't see and would strip.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
