//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <gstplayer/gst_player_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) gstplayer_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "GstPlayerPlugin");
  gst_player_plugin_register_with_registrar(gstplayer_registrar);
}
