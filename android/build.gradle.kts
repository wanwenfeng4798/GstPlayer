// The Android Gradle Plugin builds the native code with the Android NDK.

import com.android.build.gradle.LibraryExtension
import org.gradle.api.tasks.Exec
import org.gradle.internal.os.OperatingSystem
import java.util.LinkedHashSet

group = "com.gstplayer"
version = "1.0.0"

val gstVer: String = System.getenv("GST_VER") ?: "1.28.6"

fun defaultGstreamerAndroidCacheRoot(): String {
    val home = System.getProperty("user.home")
    val os = OperatingSystem.current()
    return when {
        os.isMacOsX -> "$home/Library/Caches/gstplayer/gstreamer/android/$gstVer"
        os.isWindows -> {
            val localAppData =
                System.getenv("LOCALAPPDATA") ?: "$home/AppData/Local"
            "$localAppData/gstplayer/gstreamer/android/$gstVer"
        }
        else -> {
            val xdgCache = System.getenv("XDG_CACHE_HOME") ?: "$home/.cache"
            "$xdgCache/gstplayer/gstreamer/android/$gstVer"
        }
    }
}

val gstRoot: String =
    System.getenv("GSTREAMER_ROOT_ANDROID") ?: defaultGstreamerAndroidCacheRoot()
val gstJniOut: String =
    layout.buildDirectory
        .get()
        .asFile
        .resolve("gstreamer/jniLibs")
        .absolutePath
val gstScriptsDir: String = projectDir.resolve("scripts").absolutePath

extra["gstreamerRootAndroid"] = gstRoot
extra["gstreamerVersion"] = gstVer

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Keep classpath for standalone/plugin-module resolution; apps use AGP from settings.
        classpath("com.android.tools.build:gradle:9.3.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.gstplayer"

    // Align with current Flutter example / AGP expectations.
    // `flutter.*` is injected when this module is included from a Flutter app
    // (same pattern as first-party plugins such as shared_preferences_android).
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("proguard-rules.pro")
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
        }
        externalNativeBuild {
            cmake {
                arguments +=
                    listOf(
                        "-DGSTREAMER_ROOT_ANDROID=$gstRoot",
                        "-DGSTREAMER_JNI_LIBS=$gstJniOut",
                    )
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir(gstJniOut)
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.14.2")
}

// --- GStreamer (Android) dynamic build --------------------------------------
// On every Android build the plugin downloads the official GStreamer Android SDK
// (if missing) and runs ndk-build to produce libgstreamer_android.so per ABI
// (souphttpsrc and other plugins from Android.mk). Override
// GSTREAMER_ROOT_ANDROID / GST_VER for offline or custom SDK paths.
// See android/scripts/ and the plugin README, "Android".

fun resolveGstreamerAbis(): List<String> {
    // Always match plugin abiFilters so CMake never links an ABI without
    // libgstreamer_android.so (Flutter target platforms may omit x86).
    val androidExt = project.extensions.getByType(LibraryExtension::class.java)
    return androidExt.defaultConfig.ndk.abiFilters.toList()
}

tasks.register<Exec>("ensureGstreamerAndroid") {
    group = "gstreamer"
    description = "Download GStreamer Android SDK into the user cache if missing."
    environment("GST_VER", gstVer)
    System.getenv("GSTREAMER_ROOT_ANDROID")?.let {
        environment("GSTREAMER_ROOT_ANDROID", it)
    }
    System.getenv("GSTPLAYER_GSTREAMER_ROOT")?.let {
        environment("GSTPLAYER_GSTREAMER_ROOT", it)
    }
    commandLine("sh", "$gstScriptsDir/ensure_gstreamer_android.sh")
}

val buildGstreamerUmbrella =
    tasks.register<Exec>("buildGstreamerUmbrella") {
        group = "gstreamer"
        description = "ndk-build libgstreamer_android.so for the requested ABIs."
        dependsOn("ensureGstreamerAndroid")

        inputs.files(
            file("$projectDir/gstreamer_build/jni/Android.mk"),
            file("$projectDir/gstreamer_build/jni/Application.mk"),
            file("$projectDir/gstreamer_build/jni/dummy.c"),
            file("$gstScriptsDir/build_gstreamer_umbrella.sh"),
        )

        outputs.dir(gstJniOut)

        outputs.upToDateWhen {
            val abis = resolveGstreamerAbis()
            abis.isNotEmpty() &&
                abis.all { abi ->
                    file("$gstJniOut/$abi/libgstreamer_android.so").exists() &&
                        file("$gstJniOut/$abi/libc++_shared.so").exists() &&
                        file("$gstJniOut/$abi/.gstreamer-umbrella-soup").exists()
                }
        }

        doFirst {
            val androidExt = project.extensions.getByType(LibraryExtension::class.java)
            val ndkVersion =
                androidExt.ndkVersion
                    ?: throw GradleException(
                        "Please set 'android.ndkVersion' in the app build.gradle.",
                    )
            val abis = resolveGstreamerAbis()
            val ndkPath = "${androidExt.sdkDirectory}/ndk/$ndkVersion"
            environment("GST_VER", gstVer)
            environment("GSTREAMER_ROOT_ANDROID", gstRoot)
            commandLine(
                listOf(
                    "sh",
                    "$gstScriptsDir/build_gstreamer_umbrella.sh",
                    ndkPath,
                    gstJniOut,
                ) + abis,
            )
        }
    }

fun wireGstreamerDeps(task: Task) {
    if (task.name.startsWith("externalNativeBuild") ||
        task.name.startsWith("buildCMake") ||
        (
            task.name.startsWith("merge") &&
                (
                    task.name.endsWith("NativeLibs") ||
                        task.name.endsWith("JniLibFolders")
                )
        )
    ) {
        task.dependsOn(buildGstreamerUmbrella)
    }
}

gradle.afterProject {
    if (this != project) {
        return@afterProject
    }
    tasks.configureEach { wireGstreamerDeps(this) }
}

tasks.whenTaskAdded { wireGstreamerDeps(this) }
