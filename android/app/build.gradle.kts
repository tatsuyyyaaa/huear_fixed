plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    ndkVersion = "27.0.12077973"
    namespace = "com.example.huear_fixed"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.huear_fixed"
        // minSdk is set to 26, which is suitable for Google ML Kit Object Detection.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    repositories {
        google()
        mavenCentral()
    }
}

dependencies {
    // Corrected Google ML Kit Object Detection dependency with Kotlin DSL syntax
    implementation("com.google.mlkit:object-detection:17.0.1")

    // IMPORTANT: If you had other dependencies in this block, you need to add them back here
    // using the correct Kotlin DSL syntax: implementation("group:artifact:version")
    // Example:
    // implementation("androidx.core:core-ktx:1.10.1")
    // implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.0")
}

flutter {
    source = "../../"
}
