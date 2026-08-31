#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef _WIN32
#ifdef GSTP_BUILDING
#define GSTP_EXPORT __declspec(dllexport)
#else
#define GSTP_EXPORT __declspec(dllimport)
#endif
#else
/* visibility + used: keep Dart FFI symbols visible to dlsym on Apple Release. */
#define GSTP_EXPORT                                                            \
  __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t GstpPlayerId;

/** Matches Dart [PlayerEventKind] ordinal order. */
enum GstpEventKind {
  GSTP_EVENT_DURATION_CHANGED = 0,
  GSTP_EVENT_POSITION_CHANGED = 1,
  GSTP_EVENT_VIDEO_SIZE = 2,
  GSTP_EVENT_STATE_CHANGED = 3,
  GSTP_EVENT_BUFFERING = 4,
  GSTP_EVENT_EOS = 5,
  GSTP_EVENT_ERROR = 6,
  GSTP_EVENT_TRACKS_CHANGED = 7,
  GSTP_EVENT_METADATA_CHANGED = 8,
};

/** Matches Dart [PlayerState] ordinal order. */
enum GstpPlayerState {
  GSTP_STATE_IDLE = 0,
  GSTP_STATE_READY = 1,
  GSTP_STATE_BUFFERING = 2,
  GSTP_STATE_PLAYING = 3,
  GSTP_STATE_PAUSED = 4,
  GSTP_STATE_STOPPED = 5,
  GSTP_STATE_COMPLETED = 6,
  GSTP_STATE_ERROR = 7,
};

/** Matches Dart [TrackType] ordinal order. */
enum GstpTrackType {
  GSTP_TRACK_AUDIO = 0,
  GSTP_TRACK_VIDEO = 1,
  GSTP_TRACK_SUBTITLE = 2,
};

/** Matches Dart [AspectRatioMode] ordinal order. */
enum GstpAspectRatioMode {
  GSTP_ASPECT_FIT = 0,
  GSTP_ASPECT_FILL = 1,
  GSTP_ASPECT_STRETCH = 2,
};

typedef void (*GstpEventCallback)(void *ctx, int32_t kind, int64_t position_ms,
                                  int64_t duration_ms, int32_t width,
                                  int32_t height, int32_t buffering_percent,
                                  int32_t state, const char *message,
                                  double fps, int32_t par_n, int32_t par_d,
                                  int32_t dar_n, int32_t dar_d, bool interlaced,
                                  const char *color_matrix,
                                  const char *color_range,
                                  const char *hdr_format, bool is_seekable);

typedef void (*GstpFrameReadyFn)(void *ctx);

/** Called when [gstp_init_async] finishes; [code] is [GSTP_ERR_*]. */
typedef void (*GstpInitDoneFn)(void *ctx, int32_t code);

GSTP_EXPORT const char *gstp_version(void);
GSTP_EXPORT int32_t gstp_init(void);
/**
 * Starts runtime init on a background thread (does not block the caller).
 * Invokes [cb] once finished. Concurrent [gstp_init] waits on the same gate.
 * If already initialized, [cb] is invoked immediately on the calling thread.
 */
GSTP_EXPORT void gstp_init_async(GstpInitDoneFn cb, void *ctx);
GSTP_EXPORT void gstp_shutdown(void);

/**
 * Overrides the default HTTP User-Agent when custom headers omit User-Agent.
 * Pass NULL or "" to revert to the platform-detected default.
 */
GSTP_EXPORT void gstp_set_default_user_agent(const char *ua);

/** Platform-detected default; overridden by [gstp_set_default_user_agent]. */
GSTP_EXPORT const char *gstp_get_default_user_agent(void);

GSTP_EXPORT GstpPlayerId gstp_player_create(void);
GSTP_EXPORT void gstp_player_dispose(GstpPlayerId id);
GSTP_EXPORT void gstp_player_set_event_callback(GstpPlayerId id, void *ctx,
                                                GstpEventCallback cb);

GSTP_EXPORT int32_t gstp_player_load_uri(GstpPlayerId id, const char *uri,
                                         bool auto_play,
                                         const char *http_headers_json);
GSTP_EXPORT int32_t gstp_player_load_asset(GstpPlayerId id,
                                           const char *asset_key,
                                           const char *package,
                                           const uint8_t *bytes, uint32_t len,
                                           bool auto_play);

GSTP_EXPORT int32_t gstp_player_play(GstpPlayerId id);
GSTP_EXPORT int32_t gstp_player_pause(GstpPlayerId id);
GSTP_EXPORT int32_t gstp_player_stop(GstpPlayerId id);
GSTP_EXPORT int32_t gstp_player_seek(GstpPlayerId id, int64_t position_ms,
                                     bool accurate);
GSTP_EXPORT int32_t gstp_player_set_volume(GstpPlayerId id, double volume);
GSTP_EXPORT int32_t gstp_player_set_mute(GstpPlayerId id, bool mute);
GSTP_EXPORT int32_t gstp_player_set_speed(GstpPlayerId id, double speed);
GSTP_EXPORT int32_t gstp_player_set_looping(GstpPlayerId id, bool looping);

GSTP_EXPORT int32_t gstp_player_get_capabilities(GstpPlayerId id, bool *seek,
                                                 bool *tracks,
                                                 bool *orientation);
GSTP_EXPORT int32_t gstp_player_get_track_count(GstpPlayerId id);
GSTP_EXPORT int32_t gstp_player_get_track(GstpPlayerId id, int32_t index,
                                          int32_t *out_id, int32_t *out_type,
                                          char *language, uint32_t language_len,
                                          char *label, uint32_t label_len,
                                          bool *selected);
GSTP_EXPORT int32_t gstp_player_select_track(GstpPlayerId id, int32_t track_id,
                                             int32_t track_type, bool enable);
GSTP_EXPORT int32_t gstp_player_set_video_rotation(GstpPlayerId id,
                                                   int32_t rotate_degrees);
GSTP_EXPORT int32_t gstp_player_set_aspect_ratio_mode(GstpPlayerId id,
                                                      int32_t mode);

/** Android: cache ANativeWindow pointer (as intptr) from JNI thread. */
GSTP_EXPORT void gstp_player_notify_android_surface(GstpPlayerId id,
                                                    int64_t native_window,
                                                    int32_t width,
                                                    int32_t height);
GSTP_EXPORT void gstp_player_clear_android_surface(GstpPlayerId id);

GSTP_EXPORT void gstp_texture_register(int64_t player_id, void *ctx,
                                       GstpFrameReadyFn on_frame);
GSTP_EXPORT void gstp_texture_unregister(int64_t player_id);
GSTP_EXPORT bool gstp_texture_frame_info(int64_t player_id, int32_t *out_width,
                                         int32_t *out_height,
                                         int32_t *out_stride,
                                         uint32_t *out_bytes);
GSTP_EXPORT bool gstp_texture_copy_latest(int64_t player_id, uint8_t *dst,
                                          uint32_t dst_len, int32_t *out_width,
                                          int32_t *out_height,
                                          int32_t *out_stride);

/**
 * One-shot cover frame from a URI (no player slot).
 * position_ms < 0 → auto (5% of duration, or 1s). max_width <= 0 → 320.
 * On success *out_bgra is g_malloc'd BGRA; free with gstp_thumbnail_free.
 */
GSTP_EXPORT int32_t gstp_thumbnail_capture(
    const char *uri, int64_t position_ms, int32_t max_width,
    const char *http_headers_json, uint8_t **out_bgra, uint32_t *out_len,
    int32_t *out_width, int32_t *out_height, int32_t *out_stride);

/** Copy the latest BGRA frame from an active player into a new buffer. */
GSTP_EXPORT int32_t gstp_player_capture_frame(
    GstpPlayerId id, uint8_t **out_bgra, uint32_t *out_len, int32_t *out_width,
    int32_t *out_height, int32_t *out_stride);

GSTP_EXPORT void gstp_thumbnail_free(uint8_t *data);

/**
 * Touch every Dart-looked-up ABI symbol so Apple Release dead-strip / LTO
 * cannot drop them. Call once from the Flutter plugin register path.
 */
GSTP_EXPORT void gstp_ffi_retain_symbols(void);

#ifdef __cplusplus
}
#endif
