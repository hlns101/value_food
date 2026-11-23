plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}

// Windows native build hooks need a Flutter executable path without spaces.
// Use the local junction only when it points to this project's configured SDK.
project(":app") {
    val sdkAlias = File("C:/flutter")
    if (File.separatorChar == '\\' && sdkAlias.isDirectory) {
        val local = java.util.Properties()
        rootProject.file("local.properties").inputStream().use { local.load(it) }
        val sdk = local.getProperty("flutter.sdk")?.let { File(it) }
        if (sdk != null && sdk.isDirectory && java.nio.file.Files.isSameFile(sdk.toPath(), sdkAlias.toPath())) {
            extensions.extraProperties["flutter.sdk"] = sdkAlias.absolutePath
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Build JNI with the same installed NDK as the app.
project(":jni") {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
            finalizeDsl { it.ndkVersion = "27.0.12077973" }
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// added for python
// buildscript {
//     repositories {
//         google()
//         mavenCentral()
//         maven { url "https://chaquo.com/maven" }
//     }
//     dependencies {
//         classpath "com.chaquo.python:gradle:13.0.0"
//     }
// }

