pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false

<<<<<<< HEAD
    // KEEP THIS — needed for Firebase/M-Pesa callbacks (google-services plugin)
=======
    // FlutterFire Configuration (keep this)
>>>>>>> ce324ff6a0fd363be9cf254a16e043d71983c212
    id("com.google.gms.google-services") version "4.3.15" apply false

    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
