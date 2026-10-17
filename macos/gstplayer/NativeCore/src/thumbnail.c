#include "gstp_internal.h"
#include "pixel_copy.h"
#include "http_source.h"

#include <gst/app/gstappsink.h>
#include <gst/video/video.h>
#include <string.h>

/*
 * Follows the official GStreamer snapshot example:
 *   gst-plugins-base/tests/examples/snapshot/snapshot.c
 *
 *   uridecodebin ! videoconvert ! videoscale ! appsink
 *   → PAUSED → (optional seek KEY_UNIT|FLUSH) → pull-preroll
 *
 * Android extras (still GStreamer decodebin APIs, not third-party players):
 * - autoplug-continue: skip audio so amcaudiodec is never created
 *   (unlinked amcaudiodec asserts / SIGABRT on this platform).
 * - autoplug-select: skip androidmedia video factories so appsink receives
 *   system-memory frames (snapshot.c assumes CPU-mappable buffers; external-oes
 *   cannot be mapped — see gst-plugins-base gstglmemory.c).
 */

/* Cancellation is nonblocking and safe to call from the UI isolate. */
static gint gstp_thumbnail_generation = 0;
void gstp_thumbnail_cancel(void) {
  g_atomic_int_inc(&gstp_thumbnail_generation);
}

static gboolean gstp_thumb_cancelled(gint generation) {
  return g_atomic_int_get(&gstp_thumbnail_generation) != generation;
}

static GstStateChangeReturn gstp_thumb_wait_state(GstElement *pipeline,
    GstClockTime timeout, gint generation) {
  const gint64 deadline = g_get_monotonic_time() + timeout / GST_USECOND;
  while (!gstp_thumb_cancelled(generation)) {
    GstStateChangeReturn state = gst_element_get_state(
        pipeline, NULL, NULL, 100 * GST_MSECOND);
    if (state != GST_STATE_CHANGE_ASYNC) return state;
    if (g_get_monotonic_time() >= deadline) break;
  }
  return GST_STATE_CHANGE_FAILURE;
}

static GstSample *gstp_thumb_pull(GstElement *sink, gboolean preroll,
    GstClockTime timeout, gint generation) {
  const gint64 deadline = g_get_monotonic_time() + timeout / GST_USECOND;
  while (!gstp_thumb_cancelled(generation) && g_get_monotonic_time() < deadline) {
    GstSample *sample = preroll
        ? gst_app_sink_try_pull_preroll(GST_APP_SINK(sink), 100 * GST_MSECOND)
        : gst_app_sink_try_pull_sample(GST_APP_SINK(sink), 100 * GST_MSECOND);
    if (sample) return sample;
    if (gst_app_sink_is_eos(GST_APP_SINK(sink))) break;
  }
  return NULL;
}

typedef struct {
  const char *uri;
  int64_t position_ms;
  int32_t max_width;
  GHashTable *http_headers;
  bool verify_tls;
  uint8_t **out_bgra;
  uint32_t *out_len;
  int32_t *out_width;
  int32_t *out_height;
  int32_t *out_stride;
  int32_t result;
} GstpThumbnailOp;

typedef struct {
  GHashTable *headers;
  bool verify_tls;
} GstpThumbnailHttp;

static void gstp_thumb_on_source_setup(GstElement *bin, GstElement *source,
                                       gpointer user_data) {
  (void)bin;
  GstpThumbnailHttp *http = user_data;
  gstp_configure_http_source_with_tls(source, http->headers, http->verify_tls);
}

static void gstp_thumb_on_element_setup(GstBin *bin, GstBin *sub_bin,
                                        GstElement *element, gpointer user_data) {
  (void)bin;
  (void)sub_bin;
  GstpThumbnailHttp *http = user_data;
  gstp_configure_http_source_with_tls(element, http->headers, http->verify_tls);
}

/* decodebin/uridecodebin: return FALSE to stop autoplugging this stream. */
static gboolean gstp_thumb_autoplug_continue(GstElement *bin, GstPad *pad,
                                             GstCaps *caps,
                                             gpointer user_data) {
  (void)bin;
  (void)pad;
  (void)user_data;
  if (!caps || gst_caps_is_empty(caps)) {
    return TRUE;
  }
  const GstStructure *s = gst_caps_get_structure(caps, 0);
  const char *name = s ? gst_structure_get_name(s) : NULL;
  /* Snapshot path is video-only; skip audio/text to avoid unused amc decoders. */
  if (name && (g_str_has_prefix(name, "audio/") ||
               g_str_has_prefix(name, "text/") ||
               g_str_has_prefix(name, "application/x-subtitle") ||
               g_str_has_prefix(name, "subpicture/"))) {
    return FALSE;
  }
  return TRUE;
}

#if defined(__ANDROID__)
#ifndef GST_AUTOPLUG_SELECT_TRY
#define GST_AUTOPLUG_SELECT_TRY 0
#endif
#ifndef GST_AUTOPLUG_SELECT_EXPOSE
#define GST_AUTOPLUG_SELECT_EXPOSE 1
#endif
#ifndef GST_AUTOPLUG_SELECT_SKIP
#define GST_AUTOPLUG_SELECT_SKIP 2
#endif

/* Prefer non-AMC video decoders so snapshot gets system memory like desktop. */
static gint gstp_thumb_autoplug_select(GstElement *bin, GstPad *pad,
                                       GstCaps *caps,
                                       GstElementFactory *factory,
                                       gpointer user_data) {
  (void)bin;
  (void)pad;
  (void)caps;
  (void)user_data;
  if (!factory) {
    return GST_AUTOPLUG_SELECT_TRY;
  }
  const gchar *name = gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
  if (name && (g_str_has_prefix(name, "amcvideodec") ||
               g_str_has_prefix(name, "amcaudiodec") ||
               g_strcmp0(name, "androidmedia") == 0)) {
    return GST_AUTOPLUG_SELECT_SKIP;
  }
  return GST_AUTOPLUG_SELECT_TRY;
}
#endif

static void gstp_thumb_connect_decodebin_signals(GstElement *src,
                                                 GstpThumbnailHttp *http) {
  if (!src) {
    return;
  }
  g_signal_connect(src, "source-setup", G_CALLBACK(gstp_thumb_on_source_setup),
                   http);
  g_signal_connect(src, "deep-element-added",
                   G_CALLBACK(gstp_thumb_on_element_setup), http);
  g_signal_connect(src, "autoplug-continue",
                   G_CALLBACK(gstp_thumb_autoplug_continue), NULL);
#if defined(__ANDROID__)
  g_signal_connect(src, "autoplug-select",
                   G_CALLBACK(gstp_thumb_autoplug_select), NULL);
#endif
}

static int32_t gstp_thumb_copy_sample(GstSample *sample, uint8_t **out_bgra,
                                      uint32_t *out_len, int32_t *out_width,
                                      int32_t *out_height, int32_t *out_stride) {
  if (!sample || !out_bgra || !out_len) {
    return GSTP_ERR_FAIL;
  }
  GstCaps *caps = gst_sample_get_caps(sample);
  GstBuffer *buffer = gst_sample_get_buffer(sample);
  if (!caps || !buffer) {
    return GSTP_ERR_FAIL;
  }
  GstStructure *s = gst_caps_get_structure(caps, 0);
  int width = 0;
  int height = 0;
  if (!gst_structure_get_int(s, "width", &width) ||
      !gst_structure_get_int(s, "height", &height) || width <= 0 ||
      height <= 0) {
    return GSTP_ERR_FAIL;
  }

  /* Official snapshot uses RGB; we keep BGRA for existing Dart PNG path. */
  GstMapInfo map;
  if (!gst_buffer_map(buffer, &map, GST_MAP_READ)) {
    return GSTP_ERR_FAIL;
  }

  if (width > INT32_MAX / 4 ||
      (uint64_t)width * 4 * (uint64_t)height > UINT32_MAX) {
    gst_buffer_unmap(buffer, &map);
    return GSTP_ERR_FAIL;
  }
  const int dst_stride = width * 4;
  const uint32_t needed = (uint32_t)((uint64_t)dst_stride * (uint64_t)height);
  int src_stride = dst_stride;
  GstVideoMeta *vmeta = gst_buffer_get_video_meta(buffer);
  if (vmeta) {
    src_stride = vmeta->stride[0];
  }

  uint8_t *dst = g_malloc(needed);
  const gsize offset = vmeta ? vmeta->offset[0] : 0;
  if (offset > map.size ||
      !gstp_copy_bgra_rows(dst, needed, map.data + offset,
                           map.size - offset, width, height, src_stride)) {
    g_free(dst);
    gst_buffer_unmap(buffer, &map);
    return GSTP_ERR_FAIL;
  }
  gst_buffer_unmap(buffer, &map);

  *out_bgra = dst;
  *out_len = needed;
  if (out_width) {
    *out_width = width;
  }
  if (out_height) {
    *out_height = height;
  }
  if (out_stride) {
    *out_stride = dst_stride;
  }
  return GSTP_ERR_OK;
}

static int32_t gstp_thumb_run(const char *uri, int64_t position_ms,
                              int32_t max_width, GHashTable *http_headers, bool verify_tls,
                              uint8_t **out_bgra, uint32_t *out_len,
                              int32_t *out_width, int32_t *out_height,
                              int32_t *out_stride) {
  if (!uri || !*uri || !out_bgra || !out_len) {
    return GSTP_ERR_FAIL;
  }
  *out_bgra = NULL;
  *out_len = 0;

  const gint generation = g_atomic_int_get(&gstp_thumbnail_generation);
  if (max_width <= 0) {
    max_width = 320;
  }

  /* Same pipeline shape as official snapshot.c (BGRA instead of RGB for Dart). */
  gchar *descr = g_strdup_printf(
      "uridecodebin name=src uri=\"%s\" ! videoconvert ! videoscale ! "
      "appsink name=sink caps=\"video/x-raw,format=BGRA,width=(int)[1,%d],"
      "pixel-aspect-ratio=1/1\"",
      "", max_width);
  GError *error = NULL;
  GstElement *pipeline = gst_parse_launch(descr, &error);
  g_free(descr);
  if (error != NULL) {
    g_error_free(error);
    if (pipeline) {
      gst_object_unref(pipeline);
    }
    return GSTP_ERR_FAIL;
  }
  if (!pipeline) {
    return GSTP_ERR_FAIL;
  }

  GstElement *src = gst_bin_get_by_name(GST_BIN(pipeline), "src");
  if (src) g_object_set(src, "uri", uri, NULL);
  GstpThumbnailHttp http = {.headers = http_headers, .verify_tls = verify_tls};
  gstp_thumb_connect_decodebin_signals(src, &http);
  if (src) {
    gst_object_unref(src);
  }

  GstElement *sink = gst_bin_get_by_name(GST_BIN(pipeline), "sink");
  if (!sink) {
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    return GSTP_ERR_FAIL;
  }
  g_object_set(sink, "sync", FALSE, "max-buffers", 1, "drop", TRUE, NULL);

  /* Official: set to PAUSED so the first frame arrives in the sink. */
  GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PAUSED);
  switch (ret) {
  case GST_STATE_CHANGE_FAILURE:
    gst_object_unref(sink);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    return GSTP_ERR_FAIL;
  case GST_STATE_CHANGE_NO_PREROLL:
    /* Live sources not supported (same as snapshot.c). */
    gst_object_unref(sink);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    return GSTP_ERR_FAIL;
  default:
    break;
  }

  ret = gstp_thumb_wait_state(pipeline, 15 * GST_SECOND, generation);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    gst_object_unref(sink);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    return GSTP_ERR_FAIL;
  }

  gint64 duration = GST_CLOCK_TIME_NONE;
  gst_element_query_duration(pipeline, GST_FORMAT_TIME, &duration);

  /* Official seek policy, plus optional caller position (current playback). */
  gint64 seek_pos;
  if (position_ms >= 0) {
    seek_pos = (gint64)position_ms * GST_MSECOND;
  } else if (GST_CLOCK_TIME_IS_VALID(duration) && duration > 0) {
    seek_pos = duration * 5 / 100;
  } else {
    seek_pos = 1 * GST_SECOND;
  }
  if (GST_CLOCK_TIME_IS_VALID(duration) && duration > 0 &&
      seek_pos >= duration) {
    seek_pos = duration > GST_SECOND ? duration - GST_SECOND : 0;
  }

  /* Official flags: KEY_UNIT | FLUSH. */
  if (gst_element_seek_simple(pipeline, GST_FORMAT_TIME,
                              (GstSeekFlags)(GST_SEEK_FLAG_KEY_UNIT |
                                             GST_SEEK_FLAG_FLUSH),
                              seek_pos)) {
    if (gstp_thumb_wait_state(pipeline, 10 * GST_SECOND, generation) ==
        GST_STATE_CHANGE_FAILURE) {
      gst_object_unref(sink);
      gst_element_set_state(pipeline, GST_STATE_NULL);
      gst_object_unref(pipeline);
      return GSTP_ERR_FAIL;
    }
  }

  /* Official: pull-preroll from appsink. */
  GstSample *sample = NULL;
  sample = gstp_thumb_pull(sink, TRUE, 5 * GST_SECOND, generation);
  if (!sample) {
    sample = gstp_thumb_pull(sink, FALSE, 2 * GST_SECOND, generation);
  }

  int32_t rc = GSTP_ERR_FAIL;
  if (sample) {
    rc = gstp_thumb_copy_sample(sample, out_bgra, out_len, out_width,
                                out_height, out_stride);
    gst_sample_unref(sample);
  }

  gst_object_unref(sink);
  gst_element_set_state(pipeline, GST_STATE_NULL);
  gst_object_unref(pipeline);
  return rc;
}

static gpointer gstp_thumb_thread_main(gpointer data) {
  GstpThumbnailOp *op = data;
  op->result = gstp_thumb_run(op->uri, op->position_ms, op->max_width,
                              op->http_headers, op->verify_tls, op->out_bgra, op->out_len,
                              op->out_width, op->out_height, op->out_stride);
  return NULL;
}

int32_t gstp_thumbnail_capture(const char *uri, int64_t position_ms,
    int32_t max_width, const char *http_headers_json, uint8_t **out_bgra,
    uint32_t *out_len, int32_t *out_width, int32_t *out_height, int32_t *out_stride) {
  return gstp_thumbnail_capture_with_tls(uri, position_ms, max_width,
      http_headers_json, true, out_bgra, out_len, out_width, out_height, out_stride);
}

int32_t gstp_thumbnail_capture_with_tls(const char *uri, int64_t position_ms,
    int32_t max_width, const char *http_headers_json, bool verify_tls,
    uint8_t **out_bgra, uint32_t *out_len, int32_t *out_width,
    int32_t *out_height, int32_t *out_stride) {
  if (gstp_init() != GSTP_ERR_OK) {
    return GSTP_ERR_FAIL;
  }
  if (!out_bgra || !out_len) {
    return GSTP_ERR_FAIL;
  }
  *out_bgra = NULL;
  *out_len = 0;

  GHashTable *headers = gstp_http_headers_from_json(http_headers_json);

  /* Dedicated thread so blocking preroll/seek/pull does not stall gstp-gst. */
  GstpThumbnailOp op = {.uri = uri,
                        .position_ms = position_ms,
                        .max_width = max_width,
                        .http_headers = headers,
                        .verify_tls = verify_tls,
                        .out_bgra = out_bgra,
                        .out_len = out_len,
                        .out_width = out_width,
                        .out_height = out_height,
                        .out_stride = out_stride,
                        .result = GSTP_ERR_FAIL};
  GThread *thread = g_thread_new("gstp-thumb", gstp_thumb_thread_main, &op);
  if (!thread) {
    gstp_http_headers_free(headers);
    return GSTP_ERR_FAIL;
  }
  g_thread_join(thread);
  gstp_http_headers_free(headers);
  return op.result;
}

void gstp_thumbnail_free(uint8_t *data) { g_free(data); }
