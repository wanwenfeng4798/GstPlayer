import Foundation
import PackagePlugin

/// Runs before `gstp_player_c` compiles so SPM hosts get the macOS GStreamer SDK
/// without CocoaPods / manual installer.
@main
struct EnsureGStreamerMacOS: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let packageDir = URL(fileURLWithPath: context.package.directory.string)
        let ensureScript = packageDir
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/ensure_gstreamer_macos.sh")
            .path
        let outDir = context.pluginWorkDirectory.appending("gstreamer-macos-sdk")

        return [
            .prebuildCommand(
                displayName: "Ensure GStreamer macOS SDK",
                executable: Path("/bin/sh"),
                arguments: [ensureScript, outDir.string],
                outputFilesDirectory: outDir
            ),
        ]
    }
}
