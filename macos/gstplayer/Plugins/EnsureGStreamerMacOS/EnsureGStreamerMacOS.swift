import Foundation
import PackagePlugin

/// Runs before `gstp_player_c` compiles so SPM hosts get the macOS GStreamer SDK
/// without CocoaPods / manual installer.
@main
struct EnsureGStreamerMacOS: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Flutter SPM links this package as `.packages/...` → `macos/gstplayer`.
        // Resolve symlinks so `../scripts/` is `macos/scripts/`, not `.packages/scripts/`.
        let packageDir = URL(fileURLWithPath: context.package.directory.string)
            .resolvingSymlinksInPath()
        let ensureScript = packageDir
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/ensure_gstreamer_macos.sh")
            .path
        guard FileManager.default.isReadableFile(atPath: ensureScript) else {
            throw PluginError.missingScript(ensureScript)
        }
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

enum PluginError: Error, CustomStringConvertible {
    case missingScript(String)

    var description: String {
        switch self {
        case .missingScript(let path):
            return "[gstplayer] missing ensure script at \(path)"
        }
    }
}
