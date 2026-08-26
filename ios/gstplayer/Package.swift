// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let gstVer = Context.environment["GST_VER"] ?? "1.28.6"
let home = Context.environment["HOME"] ?? NSHomeDirectory()
let gstCache = "\(home)/Library/Caches/gstplayer/gstreamer/\(gstVer)/ios/iPhone.sdk"
let gstLegacy = "\(home)/Library/Developer/GStreamer/iPhone.sdk"
let gstRoot = Context.environment["GSTREAMER_ROOT_IOS"] ?? gstCache

/// SPM never loads the CocoaPods podspec, so download/extract the iOS SDK here.
/// `ensure_gstreamer_ios.sh` is a no-op when the cache is already valid.
func ensureGStreamerIOS(gstVer: String) {
    if Context.environment["GSTREAMER_ROOT_IOS"] != nil {
        return
    }
    // Flutter SPM may load this Package.swift via `.packages/GstPlayer` symlink;
    // resolve so `ios/scripts/` is found (not `.packages/scripts/`).
    let iosDir = URL(fileURLWithPath: #filePath)
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let ensureScript = iosDir.appendingPathComponent("scripts/ensure_gstreamer_ios.sh").path
    guard FileManager.default.isReadableFile(atPath: ensureScript) else {
        fputs("[gstplayer] missing ensure script at \(ensureScript)\n", stderr)
        return
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [ensureScript]
    var env = ProcessInfo.processInfo.environment
    env["GST_VER"] = gstVer
    process.environment = env
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("[gstplayer] failed to start ensure_gstreamer_ios.sh: \(error)\n", stderr)
        return
    }
    if process.terminationStatus != 0 {
        fputs(
            """
            [gstplayer] ensure_gstreamer_ios.sh failed (exit \(process.terminationStatus)).
            Fix: sh \(ensureScript)
            Or set GSTREAMER_ROOT_IOS to an existing iPhone.sdk directory.

            """,
            stderr
        )
    }
}

ensureGStreamerIOS(gstVer: gstVer)

let gstHeaders = "\(gstRoot)/GStreamer.framework/Headers"
if !FileManager.default.fileExists(atPath: "\(gstHeaders)/gst/gst.h"),
   !FileManager.default.fileExists(atPath: "\(gstLegacy)/GStreamer.framework/Headers/gst/gst.h")
{
    fputs(
        """
        [gstplayer] GStreamer iOS headers not found at:
          \(gstHeaders)
          \(gstLegacy)/GStreamer.framework/Headers
        Run: sh \(URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("scripts/ensure_gstreamer_ios.sh").path)

        """,
        stderr
    )
}

let package = Package(
    name: "gstplayer",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "gstplayer", targets: ["gstplayer"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .plugin(
            name: "EnsureGStreamerIOS",
            capability: .buildTool(),
            path: "Plugins/EnsureGStreamerIOS"
        ),
        .target(
            name: "gstplayer",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "gstp_player_c",
            ]
        ),
        .target(
            name: "gstp_player_c",
            path: "NativeCore",
            exclude: [
                "src/android_jni.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src"),
                .define("GSTP_BUILDING"),
                .define("TARGET_OS_IPHONE", to: "1"),
                .unsafeFlags([
                    "-I\(gstRoot)/GStreamer.framework/Headers",
                    "-I\(gstLegacy)/GStreamer.framework/Headers",
                ]),
            ],
            linkerSettings: [
                .linkedFramework("GStreamer"),
                .linkedFramework("UIKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOSurface"),
                .linkedFramework("Metal"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVFAudio"),
                .linkedFramework("AssetsLibrary"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("OpenGLES"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
                .linkedLibrary("iconv"),
                .linkedLibrary("resolv"),
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                .unsafeFlags([
                    "-F\(gstRoot)",
                    "-F\(gstLegacy)",
                ]),
            ],
            plugins: [
                .plugin(name: "EnsureGStreamerIOS"),
            ]
        ),
    ]
)
