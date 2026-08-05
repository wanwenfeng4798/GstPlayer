// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let gstVer = Context.environment["GST_VER"] ?? "1.28.5"
let home = Context.environment["HOME"] ?? NSHomeDirectory()
let gstCache = "\(home)/Library/Caches/gstplayer/gstreamer/\(gstVer)"

func ensureGStreamerMacOS(gstVer: String) {
    if Context.environment["GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER"] == "1" {
        return
    }
    if Context.environment["GSTPLAYER_GSTREAMER_ROOT"] != nil
        || Context.environment["GSTREAMER_FRAMEWORK_SRC"] != nil
    {
        return
    }
    let macosDir = URL(fileURLWithPath: #filePath)
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let ensureScript = macosDir.appendingPathComponent("scripts/ensure_gstreamer_macos.sh").path
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
        fputs("[gstplayer] failed to start ensure_gstreamer_macos.sh: \(error)\n", stderr)
        return
    }
    if process.terminationStatus != 0 {
        fputs(
            """
            [gstplayer] ensure_gstreamer_macos.sh failed (exit \(process.terminationStatus)).
            Run: sh \(ensureScript)

            """,
            stderr
        )
    }
}

ensureGStreamerMacOS(gstVer: gstVer)

let package = Package(
    name: "gstplayer",
    platforms: [
        .macOS("10.15"),
    ],
    products: [
        .library(name: "gstplayer", targets: ["gstplayer"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .plugin(
            name: "EnsureGStreamerMacOS",
            capability: .buildTool(),
            path: "Plugins/EnsureGStreamerMacOS"
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
                "src/ios_plugins.c",
                "src/ios_tls.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src"),
                .define("GSTP_BUILDING"),
                .unsafeFlags([
                    "-I\(gstCache)/GStreamer.framework/Headers",
                    "-I/Library/Frameworks/GStreamer.framework/Headers",
                ]),
            ],
            linkerSettings: [
                .linkedFramework("GStreamer"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVFAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
                .linkedLibrary("iconv"),
                .linkedLibrary("resolv"),
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                .unsafeFlags([
                    "-F\(gstCache)",
                    "-F/Library/Frameworks",
                ]),
            ],
            plugins: [
                .plugin(name: "EnsureGStreamerMacOS"),
            ]
        ),
    ]
)
