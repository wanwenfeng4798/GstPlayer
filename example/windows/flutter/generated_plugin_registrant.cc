//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <gstplayer/gst_player_plugin_c_api.h>
#include <screen_brightness_windows/screen_brightness_windows_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  GstPlayerPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GstPlayerPluginCApi"));
  ScreenBrightnessWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenBrightnessWindowsPluginCApi"));
}
