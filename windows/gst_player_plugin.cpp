#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "gstplayer_texture.h"

namespace {

constexpr char kTextureChannelName[] = "gstplayer/texture";

int64_t Int64FromValue(const flutter::EncodableValue& value) {
  if (const auto* n = std::get_if<int32_t>(&value)) {
    return *n;
  }
  if (const auto* n = std::get_if<int64_t>(&value)) {
    return *n;
  }
  if (const auto* n = std::get_if<double>(&value)) {
    return static_cast<int64_t>(*n);
  }
  return 0;
}

int64_t PlayerIdFromArgs(const flutter::EncodableValue& args) {
  const auto* map = std::get_if<flutter::EncodableMap>(&args);
  if (!map) {
    return 0;
  }
  auto it = map->find(flutter::EncodableValue("playerId"));
  if (it == map->end()) {
    return 0;
  }
  return Int64FromValue(it->second);
}

class GstPlayerPlugin : public flutter::Plugin {
 public:
  GstPlayerPlugin(
      flutter::BinaryMessenger* messenger,
      std::shared_ptr<gstplayer::VideoTextureRegistry> textures)
      : textures_(std::move(textures)) {
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, kTextureChannelName,
        &flutter::StandardMethodCodec::GetInstance());

    channel_->SetMethodCallHandler(
        [textures = textures_](const auto& call, auto result) {
          const std::string& method = call.method_name();
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("invalid_args", "Expected map arguments");
            return;
          }
          const int64_t player_id = PlayerIdFromArgs(*args);
          if (method == "createTexture") {
            const int64_t texture_id = textures->Create(player_id);
            if (texture_id < 0) {
              result->Error("create_failed", "Failed to create texture");
              return;
            }
            result->Success(flutter::EncodableValue(texture_id));
            return;
          }
          if (method == "disposeTexture") {
            textures->Dispose(player_id);
            result->Success();
            return;
          }
          result->NotImplemented();
        });
  }

 private:
  std::shared_ptr<gstplayer::VideoTextureRegistry> textures_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void GstPlayerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);

  auto textures = std::make_shared<gstplayer::VideoTextureRegistry>(
      windows_registrar->texture_registrar());
  auto plugin = std::make_unique<GstPlayerPlugin>(
      windows_registrar->messenger(), textures);
  windows_registrar->AddPlugin(std::move(plugin));
}

extern "C" __declspec(dllexport) void GstPlayerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  GstPlayerPluginRegisterWithRegistrar(registrar);
}
