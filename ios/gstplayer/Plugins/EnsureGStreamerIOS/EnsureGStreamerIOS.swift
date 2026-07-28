import Foundation
import PackagePlugin

/// Runs before `gstp_player_c` compiles so SPM hosts get the iOS GStreamer SDK
/// without CocoaPods / manual installer.
@main
struct EnsureGStreamerIOS: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let packageDir = URL(fileURLWithPath: context.package.directory.string)
        let wrapper = packageDir
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/ensure_gstreamer_ios_prebuild.sh")
            .path
        let outDir = context.pluginWorkDirectory.appending("gstreamer-ios-sdk")

        return [
            .prebuildCommand(
                displayName: "Ensure GStreamer iOS SDK",
                executable: Path("/bin/sh"),
                arguments: [wrapper, outDir.string],
                outputFilesDirectory: outDir
            ),
        ]
    }
}
