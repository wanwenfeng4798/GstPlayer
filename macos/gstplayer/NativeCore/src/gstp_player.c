#include "gstp_internal.h"
#include "http_source.h"

#include <string.h>

#if defined(__ANDROID__)
#include <android/native_window.h>
#endif

void gstp_player_emit(GstpPlayer *p, int32_t kind, const char *message) {
  if (!p || !p->event_cb) {
    return;
  }
  /* Copy before callback: Dart NativeCallable.listener is async; stack
   * buffers (e.g. GST_MESSAGE_ERROR) would be freed before Dart reads them. */
  strncpy(p->event_message, message ? message : "",
          sizeof(p->event_message) - 1);
  p->event_message[sizeof(p->event_message) - 1] = '\0';
  p->event_cb(p->event_ctx, kind, p->position_ms, p->duration_ms, p->width,
              p->height, p->buffering_percent, p->player_state, p->event_message,
              p->fps, p->par_n, p->par_d, p->dar_n, p->dar_d, p->interlaced,
              p->color_matrix, p->color_range, p->hdr_format, p->seekable);
}

void gstp_player_set_state(GstpPlayer *p, int32_t state) {
  if (!p || p->player_state == state) {
    return;
  }
  p->player_state = state;
  gstp_player_emit(p, GSTP_EVENT_STATE_CHANGED, "");
}

const char *gstp_version(void) { return "0.0.4"; }

int32_t gstp_init(void) { return gstp_runtime_start(); }

void gstp_shutdown(void) { gstp_runtime_stop(); }

GstpPlayerId gstp_player_create(void) {
  if (gstp_init() != GSTP_ERR_OK) {
    return 0;
  }
  GstpRuntime *rt = gstp_runtime();
  g_mutex_lock(&rt->players_mu);
  for (int i = 0; i < GSTP_MAX_PLAYERS; i++) {
    if (!rt->players[i].in_use) {
      GstpPlayer *p = &rt->players[i];
      GMutex frame_mu = p->frame_mu;
      memset(p, 0, sizeof(*p));
      p->frame_mu = frame_mu;
      p->in_use = true;
      p->id = rt->next_id++;
      p->volume = 1.0;
      p->speed = 1.0;
      p->player_state = GSTP_STATE_IDLE;
      p->par_n = 1;
      p->par_d = 1;
      p->buffering_percent = 100;
      p->asset_temp_path[0] = '\0';
      gstp_frame_init(p);
      GstpPlayerId id = p->id;
      g_mutex_unlock(&rt->players_mu);
      return id;
    }
  }
  g_mutex_unlock(&rt->players_mu);
  return 0;
}

typedef struct {
  GstpPlayerId id;
  int32_t result;
} GstpOp;

static gboolean gstp_op_dispose(gpointer data) {
  GstpOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    return G_SOURCE_REMOVE;
  }
#if defined(__ANDROID__)
  gstp_android_clear_overlay(p);
#endif
  gstp_pipeline_destroy(p);
  gstp_http_headers_free(p->http_headers);
  p->http_headers = NULL;
  gstp_frame_clear(p);
  p->event_cb = NULL;
  p->frame_cb = NULL;
  p->in_use = false;
  return G_SOURCE_REMOVE;
}

void gstp_player_dispose(GstpPlayerId id) {
  GstpPlayer *p = gstp_player_lookup(id);
  if (!p) {
    return;
  }
  GstpOp op = {.id = id};
  gstp_runtime_invoke_sync(gstp_op_dispose, &op);
}

void gstp_player_set_event_callback(GstpPlayerId id, void *ctx,
                                    GstpEventCallback cb) {
  GstpPlayer *p = gstp_player_lookup(id);
  if (!p) {
    return;
  }
  p->event_ctx = ctx;
  p->event_cb = cb;
}

typedef struct {
  GstpPlayerId id;
  char *uri;
  bool auto_play;
  char *http_headers_json;
  int32_t result;
} GstpLoadUriOp;

static gboolean gstp_op_load_uri(gpointer data) {
  GstpLoadUriOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_load_uri(p, op->uri, op->auto_play,
                                      op->http_headers_json);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_load_uri(GstpPlayerId id, const char *uri, bool auto_play,
                             const char *http_headers_json) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpLoadUriOp op = {
      .id = id,
      .uri = g_strdup(uri ? uri : ""),
      .auto_play = auto_play,
      .http_headers_json =
          (http_headers_json && *http_headers_json)
              ? g_strdup(http_headers_json)
              : NULL,
      .result = GSTP_ERR_FAIL,
  };
  gstp_runtime_invoke_sync(gstp_op_load_uri, &op);
  g_free(op.uri);
  g_free(op.http_headers_json);
  return op.result;
}

typedef struct {
  GstpPlayerId id;
  uint8_t *bytes;
  uint32_t len;
  bool auto_play;
  int32_t result;
} GstpLoadAssetOp;

static gboolean gstp_op_load_asset(gpointer data) {
  GstpLoadAssetOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_load_asset(p, op->bytes, op->len, op->auto_play);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_load_asset(GstpPlayerId id, const char *asset_key,
                               const char *package, const uint8_t *bytes,
                               uint32_t len, bool auto_play) {
  (void)asset_key;
  (void)package;
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpLoadAssetOp op = {
      .id = id,
      .bytes = (uint8_t *)bytes,
      .len = len,
      .auto_play = auto_play,
      .result = GSTP_ERR_FAIL,
  };
  gstp_runtime_invoke_sync(gstp_op_load_asset, &op);
  return op.result;
}

#define GSTP_DEFINE_SIMPLE_OP(name, call)                                      \
  static gboolean gstp_op_##name(gpointer data) {                              \
    GstpOp *op = data;                                                         \
    GstpPlayer *p = gstp_player_lookup(op->id);                                \
    if (!p) {                                                                  \
      op->result = GSTP_ERR_BAD_ID;                                            \
      return G_SOURCE_REMOVE;                                                  \
    }                                                                          \
    op->result = call;                                                         \
    return G_SOURCE_REMOVE;                                                    \
  }                                                                            \
  int32_t gstp_player_##name(GstpPlayerId id) {                                \
    if (!gstp_player_lookup(id))                                               \
      return GSTP_ERR_BAD_ID;                                                  \
    GstpOp op = {.id = id, .result = GSTP_ERR_FAIL};                           \
    gstp_runtime_invoke_sync(gstp_op_##name, &op);                             \
    return op.result;                                                          \
  }

GSTP_DEFINE_SIMPLE_OP(play, gstp_pipeline_play(p))
GSTP_DEFINE_SIMPLE_OP(pause, gstp_pipeline_pause(p))
GSTP_DEFINE_SIMPLE_OP(stop, gstp_pipeline_stop(p))

typedef struct {
  GstpPlayerId id;
  int64_t position_ms;
  int32_t result;
} GstpSeekOp;

static gboolean gstp_op_seek(gpointer data) {
  GstpSeekOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_seek(p, op->position_ms);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_seek(GstpPlayerId id, int64_t position_ms) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpSeekOp op = {
      .id = id, .position_ms = position_ms, .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_seek, &op);
  return op.result;
}

typedef struct {
  GstpPlayerId id;
  double value;
  bool flag;
  int32_t result;
} GstpScalarOp;

static gboolean gstp_op_set_volume(gpointer data) {
  GstpScalarOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_set_volume(p, op->value);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_set_volume(GstpPlayerId id, double volume) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpScalarOp op = {.id = id, .value = volume, .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_set_volume, &op);
  return op.result;
}

static gboolean gstp_op_set_mute(gpointer data) {
  GstpScalarOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_set_mute(p, op->flag);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_set_mute(GstpPlayerId id, bool mute) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpScalarOp op = {.id = id, .flag = mute, .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_set_mute, &op);
  return op.result;
}

static gboolean gstp_op_set_speed(gpointer data) {
  GstpScalarOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_set_speed(p, op->value);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_set_speed(GstpPlayerId id, double speed) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpScalarOp op = {.id = id, .value = speed, .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_set_speed, &op);
  return op.result;
}

static gboolean gstp_op_set_looping(gpointer data) {
  GstpScalarOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  p->looping = op->flag;
  op->result = GSTP_ERR_OK;
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_set_looping(GstpPlayerId id, bool looping) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpScalarOp op = {.id = id, .flag = looping, .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_set_looping, &op);
  return op.result;
}

int32_t gstp_player_get_capabilities(GstpPlayerId id, bool *seek, bool *tracks,
                                     bool *orientation) {
  GstpPlayer *p = gstp_player_lookup(id);
  if (!p) {
    return GSTP_ERR_BAD_ID;
  }
  if (seek) {
    *seek = p->seekable;
  }
  if (tracks) {
    *tracks = p->stream_collection != NULL || p->track_count > 0;
  }
  if (orientation) {
    *orientation = true;
  }
  return GSTP_ERR_OK;
}

int32_t gstp_player_get_track_count(GstpPlayerId id) {
  GstpPlayer *p = gstp_player_lookup(id);
  if (!p) {
    return 0;
  }
  return p->track_count;
}

int32_t gstp_player_get_track(GstpPlayerId id, int32_t index, int32_t *out_id,
                              int32_t *out_type, char *language,
                              uint32_t language_len, char *label,
                              uint32_t label_len, bool *selected) {
  GstpPlayer *p = gstp_player_lookup(id);
  if (!p || index < 0 || index >= p->track_count) {
    return GSTP_ERR_FAIL;
  }
  GstpTrackInfo *t = &p->tracks[index];
  if (out_id) {
    *out_id = t->id;
  }
  if (out_type) {
    *out_type = t->type;
  }
  if (language && language_len > 0) {
    strncpy(language, t->language, language_len - 1);
    language[language_len - 1] = '\0';
  }
  if (label && label_len > 0) {
    strncpy(label, t->label, label_len - 1);
    label[label_len - 1] = '\0';
  }
  if (selected) {
    *selected = t->selected;
  }
  return GSTP_ERR_OK;
}

typedef struct {
  GstpPlayerId id;
  int32_t track_id;
  int32_t track_type;
  bool enable;
  int32_t result;
} GstpSelectTrackOp;

static gboolean gstp_op_select_track(gpointer data) {
  GstpSelectTrackOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result =
      gstp_pipeline_select_track(p, op->track_id, op->track_type, op->enable);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_select_track(GstpPlayerId id, int32_t track_id,
                                 int32_t track_type, bool enable) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpSelectTrackOp op = {.id = id,
                          .track_id = track_id,
                          .track_type = track_type,
                          .enable = enable,
                          .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_select_track, &op);
  return op.result;
}

typedef struct {
  GstpPlayerId id;
  int32_t degrees;
  int32_t result;
} GstpRotationOp;

static gboolean gstp_op_set_rotation(gpointer data) {
  GstpRotationOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  op->result = gstp_pipeline_set_rotation(p, op->degrees);
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_set_video_rotation(GstpPlayerId id,
                                       int32_t rotate_degrees) {
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpRotationOp op = {
      .id = id, .degrees = rotate_degrees, .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_set_rotation, &op);
  return op.result;
}

int32_t gstp_player_set_aspect_ratio_mode(GstpPlayerId id, int32_t mode) {
  GstpPlayer *p = gstp_player_lookup(id);
  if (!p) {
    return GSTP_ERR_BAD_ID;
  }
  return gstp_pipeline_set_aspect(p, mode);
}

typedef struct {
  GstpPlayerId id;
  int64_t window;
  int32_t w;
  int32_t h;
} GstpAndroidSurfaceOp;

static gboolean gstp_op_android_surface(gpointer data) {
  GstpAndroidSurfaceOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
#if defined(__ANDROID__)
    if (op->window != 0) {
      ANativeWindow_release((ANativeWindow *)(intptr_t)op->window);
    }
#endif
    return G_SOURCE_REMOVE;
  }
#if defined(__ANDROID__)
  if (p->android_window != 0 && p->android_window != op->window) {
    /* Different Surface: unbind overlay and drop previous ANativeWindow ref. */
    gstp_android_clear_overlay(p);
  }
  p->android_window = op->window;
  p->android_w = op->w;
  p->android_h = op->h;
  gstp_android_apply_overlay(p);
#else
  (void)op;
#endif
  return G_SOURCE_REMOVE;
}

void gstp_player_notify_android_surface(GstpPlayerId id, int64_t native_window,
                                        int32_t width, int32_t height) {
  if (!gstp_player_lookup(id)) {
#if defined(__ANDROID__)
    if (native_window != 0) {
      ANativeWindow_release((ANativeWindow *)(intptr_t)native_window);
    }
#endif
    return;
  }
  /* Sync: GST must hold the new window before Java returns from setSize/bind,
   * so a late onSurfaceCleanup cannot clear android_window before apply. */
  GstpAndroidSurfaceOp op = {
      .id = id, .window = native_window, .w = width, .h = height};
  gstp_runtime_invoke_sync(gstp_op_android_surface, &op);
}

typedef struct {
  GstpPlayerId id;
} GstpAndroidClearOp;

static gboolean gstp_op_clear_android_surface(gpointer data) {
  GstpAndroidClearOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (p) {
#if defined(__ANDROID__)
    gstp_android_clear_overlay(p);
#endif
  }
  return G_SOURCE_REMOVE;
}

void gstp_player_clear_android_surface(GstpPlayerId id) {
  if (!gstp_player_lookup(id)) {
    return;
  }
  /* Sync: must finish set_window_handle(0)+ANativeWindow_release before Java
   * destroys the Surface (setSize / release), or glimagesink aborts on a
   * destroyed mutex in eglCreateWindowSurface. */
  GstpAndroidClearOp op = {.id = id};
  gstp_runtime_invoke_sync(gstp_op_clear_android_surface, &op);
}

void gstp_texture_register(int64_t player_id, void *ctx,
                           GstpFrameReadyFn on_frame) {
  GstpPlayer *p = gstp_player_lookup(player_id);
  if (!p) {
    return;
  }
  p->frame_ctx = ctx;
  p->frame_cb = on_frame;
}

void gstp_texture_unregister(int64_t player_id) {
  GstpPlayer *p = gstp_player_lookup(player_id);
  if (!p) {
    return;
  }
  p->frame_ctx = NULL;
  p->frame_cb = NULL;
}

bool gstp_texture_frame_info(int64_t player_id, int32_t *out_width,
                             int32_t *out_height, int32_t *out_stride,
                             uint32_t *out_bytes) {
  GstpPlayer *p = gstp_player_lookup(player_id);
  if (!p) {
    return false;
  }
  return gstp_frame_info(p, out_width, out_height, out_stride, out_bytes);
}

bool gstp_texture_copy_latest(int64_t player_id, uint8_t *dst, uint32_t dst_len,
                              int32_t *out_width, int32_t *out_height,
                              int32_t *out_stride) {
  GstpPlayer *p = gstp_player_lookup(player_id);
  if (!p) {
    return false;
  }
  return gstp_frame_copy(p, dst, dst_len, out_width, out_height, out_stride);
}

typedef struct {
  GstpPlayerId id;
  uint8_t **out_bgra;
  uint32_t *out_len;
  int32_t *out_width;
  int32_t *out_height;
  int32_t *out_stride;
  int32_t result;
} GstpCaptureFrameOp;

static gboolean gstp_op_capture_frame(gpointer data) {
  GstpCaptureFrameOp *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p) {
    op->result = GSTP_ERR_BAD_ID;
    return G_SOURCE_REMOVE;
  }
  int32_t w = 0;
  int32_t h = 0;
  int32_t stride = 0;
  uint32_t bytes = 0;
  if (!gstp_frame_info(p, &w, &h, &stride, &bytes) || bytes == 0) {
    op->result = GSTP_ERR_NOT_READY;
    return G_SOURCE_REMOVE;
  }
  uint8_t *buf = g_malloc(bytes);
  if (!gstp_frame_copy(p, buf, bytes, &w, &h, &stride)) {
    g_free(buf);
    op->result = GSTP_ERR_FAIL;
    return G_SOURCE_REMOVE;
  }
  *op->out_bgra = buf;
  *op->out_len = bytes;
  if (op->out_width) {
    *op->out_width = w;
  }
  if (op->out_height) {
    *op->out_height = h;
  }
  if (op->out_stride) {
    *op->out_stride = stride;
  }
  op->result = GSTP_ERR_OK;
  return G_SOURCE_REMOVE;
}

int32_t gstp_player_capture_frame(GstpPlayerId id, uint8_t **out_bgra,
                                  uint32_t *out_len, int32_t *out_width,
                                  int32_t *out_height, int32_t *out_stride) {
  if (!out_bgra || !out_len) {
    return GSTP_ERR_FAIL;
  }
  *out_bgra = NULL;
  *out_len = 0;
  if (!gstp_player_lookup(id)) {
    return GSTP_ERR_BAD_ID;
  }
  GstpCaptureFrameOp op = {.id = id,
                           .out_bgra = out_bgra,
                           .out_len = out_len,
                           .out_width = out_width,
                           .out_height = out_height,
                           .out_stride = out_stride,
                           .result = GSTP_ERR_FAIL};
  gstp_runtime_invoke_sync(gstp_op_capture_frame, &op);
  return op.result;
}
