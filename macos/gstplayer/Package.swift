// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let gstVer = Context.environment["GST_VER"] ?? "1.28.5"
let home = Context.environment["HOME"] ?? ""
let gstCache = "\(home)/Library/Caches/gstplayer/gstreamer/\(gstVer)"

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
            ]
        ),
    ]
)
