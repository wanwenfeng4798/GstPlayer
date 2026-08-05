import Foundation
import PackagePlugin

/// Runs before `gstp_player_c` compiles so SPM hosts get the iOS GStreamer SDK
/// without CocoaPods / manual installer.
@main
struct EnsureGStreamerIOS: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Flutter SPM links this package as `.packages/GstPlayer` → `ios/gstplayer`.
        // Resolve symlinks so `../scripts/` is `ios/scripts/`, not `.packages/scripts/`.
        let packageDir = URL(fileURLWithPath: context.package.directory.string)
            .resolvingSymlinksInPath()
        let wrapper = packageDir
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/ensure_gstreamer_ios_prebuild.sh")
            .path
        guard FileManager.default.isReadableFile(atPath: wrapper) else {
            throw PluginError.missingScript(wrapper)
        }
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

enum PluginError: Error, CustomStringConvertible {
    case missingScript(String)

    var description: String {
        switch self {
        case .missingScript(let path):
            return "[gstplayer] missing ensure script at \(path)"
        }
    }
}
