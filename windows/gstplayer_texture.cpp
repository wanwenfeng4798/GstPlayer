#include "../native/src/pixel_copy.h"
#include "gstplayer_texture.h"

#include <algorithm>
#include <cstring>

extern "C" {
void gstp_texture_register(int64_t player_id,
                           void* ctx,
                           void (*on_frame)(void*));
void gstp_texture_unregister(int64_t player_id);
bool gstp_texture_frame_info(int64_t player_id,
                             int32_t* out_width,
                             int32_t* out_height,
                             int32_t* out_stride,
                             uint32_t* out_bytes);
bool gstp_texture_copy_latest(int64_t player_id,
                              uint8_t* dst,
                              uint32_t dst_len,
                              int32_t* out_width,
                              int32_t* out_height,
                              int32_t* out_stride);
}

namespace {

void GstpTextureOnFrame(void* ctx) {
  if (!ctx) {
    return;
  }
  static_cast<gstplayer::VideoTexture*>(ctx)->OnFrameAvailable();
}


}  // namespace

namespace gstplayer {

VideoTexture::VideoTexture(int64_t player_id,
                           flutter::TextureRegistrar* registrar)
    : player_id_(player_id), registrar_(registrar) {
  texture_variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [this](size_t width, size_t height) {
            return CopyPixelBuffer(width, height);
          }));
  texture_id_ = registrar_->RegisterTexture(texture_variant_.get());
  if (texture_id_ >= 0) {
    gstp_texture_register(player_id_, this, GstpTextureOnFrame);
    frame_callback_registered_ = true;
  }
}

VideoTexture::~VideoTexture() {
  if (frame_callback_registered_) {
    gstp_texture_unregister(player_id_);
  }
  if (registrar_ && texture_id_ >= 0) {
    registrar_->UnregisterTexture(texture_id_, []() {});
  }
}

void VideoTexture::Release(std::unique_ptr<VideoTexture> texture) {
  if (!texture) return;
  if (texture->frame_callback_registered_) {
    gstp_texture_unregister(texture->player_id_);
    // The delayed destructor must not unregister a replacement texture.
    texture->frame_callback_registered_ = false;
  }
  auto owner = std::shared_ptr<VideoTexture>(std::move(texture));
  const auto id = owner->texture_id_;
  owner->texture_id_ = -1;
  if (!owner->registrar_ || id < 0) return;
  // Flutter can still be reading the pixel buffer until unregistration finishes.
  owner->registrar_->UnregisterTexture(id, [owner]() {});
}

void VideoTexture::OnFrameAvailable() {
  if (registrar_ && texture_id_ >= 0) {
    registrar_->MarkTextureFrameAvailable(texture_id_);
  }
}

const FlutterDesktopPixelBuffer* VideoTexture::CopyPixelBuffer(size_t width,
                                                               size_t height) {
  (void)width;
  (void)height;

  std::lock_guard<std::mutex> guard(lock_);

  int32_t frame_width = 0;
  int32_t frame_height = 0;
  int32_t frame_stride = 0;
  uint32_t frame_bytes = 0;
  if (!gstp_texture_frame_info(player_id_, &frame_width, &frame_height,
                               &frame_stride, &frame_bytes) ||
      frame_width <= 0 || frame_height <= 0 || frame_bytes == 0) {
    return nullptr;
  }

  if (staging_bgra_.size() < frame_bytes) {
    staging_bgra_.resize(frame_bytes);
  }

  int32_t copied_w = 0;
  int32_t copied_h = 0;
  int32_t copied_stride = 0;
  if (!gstp_texture_copy_latest(player_id_, staging_bgra_.data(), frame_bytes,
                                &copied_w, &copied_h, &copied_stride) ||
      copied_w <= 0 || copied_h <= 0) {
    return nullptr;
  }

  const size_t rgba_bytes =
      static_cast<size_t>(copied_w) * static_cast<size_t>(copied_h) * 4;
  if (rgba_.size() < rgba_bytes) {
    rgba_.resize(rgba_bytes);
  }

  gstp_bgra_to_rgba(staging_bgra_.data(), copied_w, copied_h, copied_stride,
                  rgba_.data());

  frame_width_ = copied_w;
  frame_height_ = copied_h;
  pixel_buffer_.buffer = rgba_.data();
  pixel_buffer_.width = static_cast<size_t>(frame_width_);
  pixel_buffer_.height = static_cast<size_t>(frame_height_);
  pixel_buffer_.release_callback = nullptr;
  pixel_buffer_.release_context = nullptr;
  return &pixel_buffer_;
}

VideoTextureRegistry::VideoTextureRegistry(
    flutter::TextureRegistrar* registrar)
    : registrar_(registrar) {}

VideoTextureRegistry::~VideoTextureRegistry() {
  while (!textures_.empty()) Dispose(textures_.begin()->first);
}

int64_t VideoTextureRegistry::Create(int64_t player_id) {
  if (player_id == 0) {
    return -1;
  }
  std::lock_guard<std::mutex> guard(lock_);
  auto it = textures_.find(player_id);
  if (it != textures_.end()) {
    return it->second->texture_id();
  }
  auto texture = std::make_unique<VideoTexture>(player_id, registrar_);
  const int64_t texture_id = texture->texture_id();
  if (texture_id < 0) return texture_id;
  textures_.emplace(player_id, std::move(texture));
  return texture_id;
}

void VideoTextureRegistry::Dispose(int64_t player_id) {
  std::lock_guard<std::mutex> guard(lock_);
  auto found = textures_.find(player_id);
  if (found == textures_.end()) return;
  auto texture = std::move(found->second);
  textures_.erase(found);
  VideoTexture::Release(std::move(texture));
}

}  // namespace gstplayer
