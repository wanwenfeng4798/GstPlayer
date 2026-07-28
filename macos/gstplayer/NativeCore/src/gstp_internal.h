#pragma once

#include "gstp_player.h"

#include <gst/app/gstappsink.h>
#include <gst/gst.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#define GSTP_MAX_PLAYERS 32
#define GSTP_MAX_TRACKS 64
#define GSTP_ERR_OK 0
#define GSTP_ERR_FAIL -1
#define GSTP_ERR_BAD_ID -2
#define GSTP_ERR_NOT_READY -3

typedef struct GstpTrackInfo {
  int32_t id;
  int32_t type;
  char language[32];
  char label[128];
  char stream_id[256];
  bool selected;
} GstpTrackInfo;

typedef struct GstpFrameBuffer {
  uint8_t *data;
  uint32_t capacity;
  uint32_t size;
  int32_t width;
  int32_t height;
  int32_t stride;
  bool valid;
} GstpFrameBuffer;

typedef struct GstpPlayer {
  GstpPlayerId id;
  bool in_use;

  GstElement *pipeline;
  GstElement *appsink;
  GstElement *appsrc;
  GstElement *orient_element; /* videoflip or glvideoflip; owned by sink bin */
  guint bus_watch_id;
  guint position_timer_id;

  GstpEventCallback event_cb;
  void *event_ctx;

  GstpFrameReadyFn frame_cb;
  void *frame_ctx;

  GMutex frame_mu;
  GstpFrameBuffer frames[2];
  int latest_frame;

  double volume;
  bool muted;
  double speed;
  bool looping;
  bool desired_playing;
  bool at_eos;
  bool is_uri;
  bool seekable;
  bool pending_rate_seek;
  int32_t rotate_degrees;
  int32_t aspect_mode;
  int32_t player_state;

  int64_t duration_ms;
  int64_t position_ms;
  int32_t width;
  int32_t height;
  double fps;
  int32_t par_n;
  int32_t par_d;
  int32_t dar_n;
  int32_t dar_d;
  bool interlaced;
  char color_matrix[64];
  char color_range[64];
  char hdr_format[64];
  /* Durable copy for async NativeCallable.listener (no stack pointers). */
  char event_message[512];

  GstpTrackInfo tracks[GSTP_MAX_TRACKS];
  int32_t track_count;
  GstStreamCollection *stream_collection;
  int32_t buffering_percent;

  /* Android overlay */
  int64_t android_window; /* ANativeWindow* as intptr; owned when non-zero */
  int32_t android_w;
  int32_t android_h;
  bool android_overlay_bound;
  bool pending_auto_play;
  GstElement *overlay_element; /* non-owning; child of video-sink bin */

  uint8_t *asset_bytes;
  uint32_t asset_len;
  uint32_t asset_offset;
  char asset_temp_path[512];
} GstpPlayer;

typedef struct GstpRuntime {
  bool initialized;
  GMainContext *ctx;
  GMainLoop *loop;
  GThread *thread;
  GMutex players_mu;
  GstpPlayer players[GSTP_MAX_PLAYERS];
  int64_t next_id;
} GstpRuntime;

GstpRuntime *gstp_runtime(void);
GstpPlayer *gstp_player_lookup(GstpPlayerId id);
int32_t gstp_runtime_start(void);
void gstp_runtime_stop(void);
void gstp_runtime_invoke_sync(GSourceFunc func, gpointer data);
void gstp_runtime_invoke_async(GSourceFunc func, gpointer data);

#if defined(__APPLE__)
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
void gstp_setup_ios_env(void);
void gstp_register_ios_static_plugins(void);
void gstp_register_ios_tls_backend(void);
#else
void gstp_setup_macos_env(void);
#endif
#endif

#if defined(_WIN32)
void gstp_setup_windows_env(void);
#endif

void gstp_player_emit(GstpPlayer *p, int32_t kind, const char *message);
void gstp_player_set_state(GstpPlayer *p, int32_t state);

int32_t gstp_pipeline_load_uri(GstpPlayer *p, const char *uri, bool auto_play);
int32_t gstp_pipeline_load_asset(GstpPlayer *p, const uint8_t *bytes,
                                 uint32_t len, bool auto_play);
int32_t gstp_pipeline_play(GstpPlayer *p);
int32_t gstp_pipeline_pause(GstpPlayer *p);
int32_t gstp_pipeline_stop(GstpPlayer *p);
int32_t gstp_pipeline_seek(GstpPlayer *p, int64_t position_ms);
int32_t gstp_pipeline_set_volume(GstpPlayer *p, double volume);
int32_t gstp_pipeline_set_mute(GstpPlayer *p, bool mute);
int32_t gstp_pipeline_set_speed(GstpPlayer *p, double speed);
int32_t gstp_pipeline_apply_rate(GstpPlayer *p);
void gstp_pipeline_destroy(GstpPlayer *p);
void gstp_pipeline_refresh_tracks(GstpPlayer *p);
void gstp_pipeline_apply_streams_selected(GstpPlayer *p, GstMessage *msg);
void gstp_pipeline_update_seekable(GstpPlayer *p);
int32_t gstp_pipeline_select_track(GstpPlayer *p, int32_t track_id,
                                   int32_t track_type, bool enable);
int32_t gstp_pipeline_set_rotation(GstpPlayer *p, int32_t degrees);
int32_t gstp_pipeline_set_aspect(GstpPlayer *p, int32_t mode);

void gstp_bus_attach(GstpPlayer *p);
void gstp_bus_detach(GstpPlayer *p);

void gstp_frame_init(GstpPlayer *p);
void gstp_frame_clear(GstpPlayer *p);
GstFlowReturn gstp_frame_on_new_sample(GstAppSink *sink, gpointer user_data);
bool gstp_frame_info(GstpPlayer *p, int32_t *w, int32_t *h, int32_t *stride,
                     uint32_t *bytes);
bool gstp_frame_copy(GstpPlayer *p, uint8_t *dst, uint32_t dst_len, int32_t *w,
                     int32_t *h, int32_t *stride);

#if defined(__ANDROID__)
void gstp_android_apply_overlay(GstpPlayer *p);
void gstp_android_clear_overlay(GstpPlayer *p);
void gstp_android_release_window(GstpPlayer *p);
GstElement *gstp_android_make_video_sink(GstpPlayer *p);
#else
GstElement *gstp_desktop_make_video_sink(GstpPlayer *p);
#endif
