// Top-level build file where you can add configuration options common to all sub-projects/modules.
// This file is for the root 'android' project.

import org.gradle.api.file.Directory

// Define repositories for all projects (including sub-projects like 'app', 'arcore_flutter_plugin', etc.)
allprojects {
    repositories {
        // Google's Maven repository for AndroidX, Google Play Services, Firebase, etc.
        google()
        // Maven Central repository for other common libraries
        mavenCentral()
    }
}

// Custom build directory configuration. This moves the main 'build' directory
// from 'android/build' to 'build' at the root of the Flutter project.
// This is a common setup in Flutter to keep all build artifacts in one place.
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Apply the same custom build directory configuration to all sub-projects.
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// This block ensures that the 'app' project is evaluated before other subprojects.
// This can be useful for certain dependency ordering or configuration needs,
// though it's less common in newer Flutter setups.
subprojects {
    project.evaluationDependsOn(":app")
}

// Define a 'clean' task to delete the custom build directory.
// This is equivalent to `flutter clean` but specifically for the Android build artifacts.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}