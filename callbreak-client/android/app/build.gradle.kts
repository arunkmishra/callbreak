plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.akm.callbreak_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.akm.callbreak_client"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        var admobAppId = "ca-app-pub-3940256099942544~3347511713"
        val envFile = file("../../.env")
        if (envFile.exists()) {
            envFile.readLines().forEach { line ->
                if (line.startsWith("ADMOB_APP_ID=")) {
                    val envId = line.substringAfter("=").trim().removeSurrounding("\"").removeSurrounding("'")
                    if (envId.isNotEmpty()) {
                        // Validate format: must start with ca-app-pub- and contain a tilde (~)
                        // If it contains a slash (/) it's an Ad Unit ID, not an App ID!
                        if (envId.startsWith("ca-app-pub-") && envId.contains("~")) {
                            admobAppId = envId
                        } else {
                            println("WARNING: Invalid ADMOB_APP_ID '$envId'. It must start with 'ca-app-pub-' and contain a '~'. Falling back to test ID.")
                        }
                    }
                }
            }
        }
        manifestPlaceholders += mapOf("admobAppId" to admobAppId)
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
