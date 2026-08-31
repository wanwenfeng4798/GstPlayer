#include "gstp_player.h"

/*
 * Dart resolves gstp_* via DynamicLibrary.process() / dlsym on Apple.
 * Release builds dead-strip unreferenced globals; Swift only calls
 * gstp_texture_*. Holding function pointers here (and calling this from
 * plugin register) keeps the ABI in the final binary.
 */
void gstp_ffi_retain_symbols(void) {
  static void *const keep[] = {
      (void *)gstp_version,
      (void *)gstp_init,
      (void *)gstp_init_async,
      (void *)gstp_shutdown,
      (void *)gstp_set_default_user_agent,
      (void *)gstp_get_default_user_agent,
      (void *)gstp_player_create,
      (void *)gstp_player_dispose,
      (void *)gstp_player_set_event_callback,
      (void *)gstp_player_load_uri,
      (void *)gstp_player_load_asset,
      (void *)gstp_player_play,
      (void *)gstp_player_pause,
      (void *)gstp_player_stop,
      (void *)gstp_player_seek,
      (void *)gstp_player_set_volume,
      (void *)gstp_player_set_mute,
      (void *)gstp_player_set_speed,
      (void *)gstp_player_set_looping,
      (void *)gstp_player_get_capabilities,
      (void *)gstp_player_get_track_count,
      (void *)gstp_player_get_track,
      (void *)gstp_player_select_track,
      (void *)gstp_player_set_video_rotation,
      (void *)gstp_player_set_aspect_ratio_mode,
      (void *)gstp_player_notify_android_surface,
      (void *)gstp_player_clear_android_surface,
      (void *)gstp_texture_register,
      (void *)gstp_texture_unregister,
      (void *)gstp_texture_frame_info,
      (void *)gstp_texture_copy_latest,
      (void *)gstp_thumbnail_capture,
      (void *)gstp_player_capture_frame,
      (void *)gstp_thumbnail_free,
  };
  /* Volatile read so the compiler cannot elide the table. */
  (void)*(volatile void *const *)&keep[0];
}
