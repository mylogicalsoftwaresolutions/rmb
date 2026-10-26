import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Applies google-services.json for firebase_core/firebase_messaging.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.rmbconnect.app.rmb_connect_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (push notifications) requires this.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rmbconnect.app.rmb_connect_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 5.0+ is the broadest supported range for the current
        // Flutter plugins used by this app.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Keep Android's update identity explicit so a stale Flutter/Gradle
        // cache cannot package the previous APK version.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Keep the release APK smaller by targeting only the most common
        // architecture and avoiding multi-ABI packaging for a single-device app.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    // Lint loads a large classloader that exhausted metaspace on this machine
    // and contributes nothing to the packaged APK.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    signingConfigs {
        getByName("debug") {
            // AGP drops v1 (JAR) signing when minSdk >= 24, but many sideload
            // paths still require it — without it Android reports
            // "There was a problem parsing the package".
            enableV1Signing = true
            enableV2Signing = true
        }

        create("release") {
            enableV1Signing = true
            enableV2Signing = true
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties()
                keyPropertiesFile.inputStream().use { keyProperties.load(it) }
                val storePath = keyProperties["storeFile"]?.toString()
                if (storePath != null) {
                    val candidate = file(storePath)
                    storeFile = if (candidate.exists()) candidate else rootProject.file(storePath.removePrefix("../"))
                }
                storePassword = keyProperties["storePassword"]?.toString()
                keyAlias = keyProperties["keyAlias"]?.toString()
                keyPassword = keyProperties["keyPassword"]?.toString()
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false

            // Use the production keystore when android/key.properties exists.
            // Until then, leave the bundle unsigned instead of using debug keys.
            if (rootProject.file("key.properties").exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
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
// Required by flutter_local_notifications' core library desugaring.
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Ensure Flutter assets (MaterialIcons font, FontManifest.json, AssetManifest.bin, images)
// are properly copied and packaged into the APK under AGP 9.
tasks.matching { it.name.startsWith("merge") && it.name.endsWith("Assets") }.configureEach {
    val taskName = name
    val variant = if (taskName.contains("Release", ignoreCase = true)) "release" else "debug"
    val capVariant = if (taskName.contains("Release", ignoreCase = true)) "Release" else "Debug"
    doLast {
        val flutterAssetsSrc = project.layout.buildDirectory.dir("intermediates/flutter/$variant/flutter_assets").get().asFile
        val agpAssetsDest = project.layout.buildDirectory.dir("intermediates/assets/$variant/merge${capVariant}Assets/flutter_assets").get().asFile
        if (flutterAssetsSrc.exists()) {
            flutterAssetsSrc.copyRecursively(agpAssetsDest, overwrite = true)
        }
    }
}

tasks.matching { it.name.startsWith("compress") && it.name.endsWith("Assets") }.configureEach {
    val taskName = name
    val variant = if (taskName.contains("Release", ignoreCase = true)) "release" else "debug"
    val capVariant = if (taskName.contains("Release", ignoreCase = true)) "Release" else "Debug"
    doFirst {
        val flutterAssetsSrc = project.layout.buildDirectory.dir("intermediates/flutter/$variant/flutter_assets").get().asFile
        val agpAssetsDest = project.layout.buildDirectory.dir("intermediates/assets/$variant/merge${capVariant}Assets/flutter_assets").get().asFile
        if (flutterAssetsSrc.exists()) {
            flutterAssetsSrc.copyRecursively(agpAssetsDest, overwrite = true)
        }
    }
}


