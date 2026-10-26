allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Every Flutter plugin is an Android subproject compiled against whatever SDK
// it was published with, and that is independent of the app's own compileSdk.
// :flutter_ringtone_player hardcodes `compileSdkVersion 33` in its own
// build.gradle while its androidx dependencies (fragment 1.7.1, core-ktx
// 1.13.1, lifecycle 2.7.0, ...) require 34+, so `checkDebugAarMetadata` failed
// with 15 "requires libraries and applications that depend on it to compile
// against version 34 or later" errors and no APK was produced.
//
// This must run in afterEvaluate, not in a `plugins.withId` callback: the
// plugin's own `android { compileSdkVersion 33 }` block is evaluated after its
// plugin is applied, so an earlier assignment is simply overwritten. Pinning
// every Android subproject here also fixes the whole class of problem rather
// than one plugin at a time.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            when (ext) {
                is com.android.build.gradle.BaseExtension -> {
                    @Suppress("DEPRECATION")
                    ext.compileSdkVersion(36)
                }
                is com.android.build.api.dsl.LibraryExtension -> {
                    ext.compileSdk = 36
                }
                is com.android.build.api.dsl.ApplicationExtension -> {
                    ext.compileSdk = 36
                }
            }
        }

        // AGP 9 / Gradle 9 validation requires R-def.txt to exist before GenerateLibraryRFileTask runs,
        // even when a library has no resources and parseLocalResources is skipped.
        listOf("release", "debug").forEach { variant ->
            val cap = variant.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
            try {
                val dir = layout.buildDirectory.dir("intermediates/local_only_symbol_list/$variant/parse${cap}LocalResources").get().asFile
                val file = java.io.File(dir, "R-def.txt")
                if (!file.exists()) {
                    dir.mkdirs()
                    file.createNewFile()
                }
            } catch (_: Exception) {}
        }

        tasks.configureEach {
            if (name.startsWith("parse") && name.endsWith("LocalResources")) {
                doLast {
                    val variant = if (name.contains("Release")) "release" else "debug"
                    val cap = if (name.contains("Release")) "Release" else "Debug"
                    try {
                        val dir = project.layout.buildDirectory.dir("intermediates/local_only_symbol_list/$variant/parse${cap}LocalResources").get().asFile
                        val file = java.io.File(dir, "R-def.txt")
                        if (!file.exists()) {
                            dir.mkdirs()
                            file.createNewFile()
                        }
                    } catch (_: Exception) {}
                }
            }
        }
    }
}

gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        if (task.name.startsWith("generate") && task.name.endsWith("RFile")) {
            val variant = if (task.name.contains("Release")) "release" else "debug"
            val cap = if (task.name.contains("Release")) "Release" else "Debug"
            try {
                val dir = task.project.layout.buildDirectory.dir("intermediates/local_only_symbol_list/$variant/parse${cap}LocalResources").get().asFile
                val file = java.io.File(dir, "R-def.txt")
                if (!file.exists()) {
                    dir.mkdirs()
                    file.createNewFile()
                }
            } catch (_: Exception) {}
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

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
