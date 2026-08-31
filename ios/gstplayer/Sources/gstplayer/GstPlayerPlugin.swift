import Flutter
import UIKit
import WebKit

@_silgen_name("gstp_ffi_retain_symbols")
func gstp_ffi_retain_symbols()

public class GstPlayerPlugin: NSObject, FlutterPlugin {
    public static let textureChannelName = "gstplayer/texture"

    private let textures: FlutterTextureRegistry
    private var videoTextures: [Int64: GstVideoTexture] = [:]
    private let lock = NSLock()

    init(textures: FlutterTextureRegistry) {
        self.textures = textures
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Keep Dart FFI ABI symbols alive for DynamicLibrary.process() / dlsym.
        gstp_ffi_retain_symbols()
        let instance = GstPlayerPlugin(textures: registrar.textures())
        let channel = FlutterMethodChannel(
            name: textureChannelName, binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDefaultUserAgent":
            DispatchQueue.main.async {
                let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
                if let ua = webView.value(forKey: "userAgent") as? String, !ua.isEmpty {
                    result(ua)
                } else {
                    result(nil)
                }
            }
            return
        default:
            break
        }
        let args = call.arguments as? [String: Any]
        let playerId = (args?["playerId"] as? NSNumber)?.int64Value ?? 0
        switch call.method {
        case "createTexture":
            lock.lock()
            defer { lock.unlock() }
            if let existing = videoTextures[playerId] {
                result(NSNumber(value: existing.textureId))
                return
            }
            let texture = GstVideoTexture(playerId: playerId, registry: textures)
            videoTextures[playerId] = texture
            result(NSNumber(value: texture.textureId))
        case "disposeTexture":
            lock.lock()
            defer { lock.unlock() }
            if let texture = videoTextures.removeValue(forKey: playerId) {
                texture.dispose()
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
