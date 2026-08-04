#include "gstp_internal.h"

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

typedef struct {
  const char *uri;
  int64_t position_ms;
  int32_t max_width;
  uint8_t **out_bgra;
  uint32_t *out_len;
  int32_t *out_width;
  int32_t *out_height;
  int32_t *out_stride;
  int32_t result;
} GstpThumbnailOp;

static void gstp_thumb_configure_http(GstElement *element) {
  if (!element) {
    return;
  }
  GObjectClass *klass = G_OBJECT_GET_CLASS(element);
  if (g_object_class_find_property(klass, "ssl-strict")) {
    g_object_set(element, "ssl-strict", FALSE, NULL);
  }
  if (g_object_class_find_property(klass, "tls-validation-flags")) {
    g_object_set(element, "tls-validation-flags", 0, NULL);
  }
  if (g_object_class_find_property(klass, "user-agent")) {
    g_object_set(element, "user-agent",
                 "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                 "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 "
                 "Mobile/15E148 Safari/604.1",
                 NULL);
  }
}

static void gstp_thumb_on_source_setup(GstElement *bin, GstElement *source,
                                       gpointer user_data) {
  (void)bin;
  (void)user_data;
  gstp_thumb_configure_http(source);
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

static void gstp_thumb_connect_decodebin_signals(GstElement *src) {
  if (!src) {
    return;
  }
  g_signal_connect(src, "source-setup", G_CALLBACK(gstp_thumb_on_source_setup),
                   NULL);
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

  const int dst_stride = width * 4;
  const uint32_t needed = (uint32_t)(dst_stride * height);
  int src_stride = dst_stride;
  GstVideoMeta *vmeta = gst_buffer_get_video_meta(buffer);
  if (vmeta && vmeta->stride[0] > 0) {
    src_stride = vmeta->stride[0];
  }

  uint8_t *dst = g_malloc(needed);
  if (src_stride == dst_stride && map.size >= needed) {
    memcpy(dst, map.data, needed);
  } else {
    const uint8_t *src = map.data;
    for (int row = 0; row < height; row++) {
      const gsize row_off = (gsize)row * (gsize)src_stride;
      const gsize copy_n = (gsize)dst_stride;
      if (row_off + copy_n > map.size) {
        memset(dst + (gsize)row * (gsize)dst_stride, 0, copy_n);
        continue;
      }
      memcpy(dst + (gsize)row * (gsize)dst_stride, src + row_off, copy_n);
    }
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
                              int32_t max_width, uint8_t **out_bgra,
                              uint32_t *out_len, int32_t *out_width,
                              int32_t *out_height, int32_t *out_stride) {
  if (!uri || !*uri || !out_bgra || !out_len) {
    return GSTP_ERR_FAIL;
  }
  *out_bgra = NULL;
  *out_len = 0;

  if (max_width <= 0) {
    max_width = 320;
  }

  /* Same pipeline shape as official snapshot.c (BGRA instead of RGB for Dart). */
  gchar *descr = g_strdup_printf(
      "uridecodebin name=src uri=\"%s\" ! videoconvert ! videoscale ! "
      "appsink name=sink caps=\"video/x-raw,format=BGRA,width=(int)[1,%d],"
      "pixel-aspect-ratio=1/1\"",
      uri, max_width);
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
  gstp_thumb_connect_decodebin_signals(src);
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

  ret = gst_element_get_state(pipeline, NULL, NULL, 15 * GST_SECOND);
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
    (void)gst_element_get_state(pipeline, NULL, NULL, 10 * GST_SECOND);
  }

  /* Official: pull-preroll from appsink. */
  GstSample *sample = NULL;
  g_signal_emit_by_name(sink, "pull-preroll", &sample, NULL);
  if (!sample) {
    sample = gst_app_sink_try_pull_preroll(GST_APP_SINK(sink), 5 * GST_SECOND);
  }
  if (!sample) {
    sample = gst_app_sink_try_pull_sample(GST_APP_SINK(sink), 2 * GST_SECOND);
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
                              op->out_bgra, op->out_len, op->out_width,
                              op->out_height, op->out_stride);
  return NULL;
}

int32_t gstp_thumbnail_capture(const char *uri, int64_t position_ms,
                               int32_t max_width, uint8_t **out_bgra,
                               uint32_t *out_len, int32_t *out_width,
                               int32_t *out_height, int32_t *out_stride) {
  if (gstp_init() != GSTP_ERR_OK) {
    return GSTP_ERR_FAIL;
  }
  if (!out_bgra || !out_len) {
    return GSTP_ERR_FAIL;
  }
  *out_bgra = NULL;
  *out_len = 0;

  /* Dedicated thread so blocking preroll/seek/pull does not stall gstp-gst. */
  GstpThumbnailOp op = {.uri = uri,
                        .position_ms = position_ms,
                        .max_width = max_width,
                        .out_bgra = out_bgra,
                        .out_len = out_len,
                        .out_width = out_width,
                        .out_height = out_height,
                        .out_stride = out_stride,
                        .result = GSTP_ERR_FAIL};
  GThread *thread = g_thread_new("gstp-thumb", gstp_thumb_thread_main, &op);
  if (!thread) {
    return GSTP_ERR_FAIL;
  }
  g_thread_join(thread);
  return op.result;
}

void gstp_thumbnail_free(uint8_t *data) { g_free(data); }
