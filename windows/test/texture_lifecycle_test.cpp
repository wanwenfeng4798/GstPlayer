#include "gstplayer_texture.h"

#include <cassert>
#include <functional>
#include <map>
#include <vector>

namespace {
std::map<int64_t, void*> callbacks;
int unregister_count = 0;
}

extern "C" {
void gstp_texture_register(int64_t id, void* context, void (*)(void*)) {
  callbacks[id] = context;
}
void gstp_texture_unregister(int64_t id) {
  ++unregister_count;
  callbacks.erase(id);
}
bool gstp_texture_frame_info(int64_t, int32_t*, int32_t*, int32_t*, uint32_t*) {
  return false;
}
bool gstp_texture_copy_latest(int64_t, uint8_t*, uint32_t, int32_t*, int32_t*,
                              int32_t*) {
  return false;
}
}

class Registrar : public flutter::TextureRegistrar {
 public:
  bool fail_registration = false;
  int64_t next_id = 1;
  std::vector<std::function<void()>> pending;

  int64_t RegisterTexture(flutter::TextureVariant*) override {
    return fail_registration ? -1 : next_id++;
  }
  bool MarkTextureFrameAvailable(int64_t) override { return true; }
  bool UnregisterTexture(int64_t) override { return true; }
  void UnregisterTexture(int64_t, std::function<void()> callback) override {
    pending.push_back(std::move(callback));
  }
  void CompleteUnregister() {
    auto completed = std::move(pending);
    pending.clear();
    for (auto& callback : completed) callback();
    // Destroy callbacks here, as the engine does when unregistration completes.
  }
};

int main() {
  Registrar registrar;
  {
    gstplayer::VideoTextureRegistry textures(&registrar);
    assert(textures.Create(1) >= 0);
    textures.Dispose(1);
    assert(callbacks.count(1) == 0);
    assert(textures.Create(1) >= 0);
    void* replacement = callbacks.at(1);
    int count = unregister_count;
    registrar.CompleteUnregister();
    assert(callbacks.at(1) == replacement);
    assert(unregister_count == count);

    // Failed registration must neither publish a callback nor poison retries.
    registrar.fail_registration = true;
    assert(textures.Create(2) < 0);
    assert(callbacks.count(2) == 0);
    registrar.fail_registration = false;
    assert(textures.Create(2) >= 0);
    assert(callbacks.count(2) == 1);
  }
  registrar.CompleteUnregister();
  assert(callbacks.empty());
}
