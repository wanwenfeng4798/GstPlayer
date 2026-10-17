#include "gstp_internal.h"
#include "http_source.h"
#include "pixel_copy.h"
#include <glib.h>
#include <string.h>
#include <unistd.h>

static const char *messages[2];
static const char *matrices[2];
static int event_count, detach_count;
static void event_callback(void *ctx, int32_t kind, int64_t pos, int64_t dur,
    int32_t w, int32_t h, int32_t buffering, int32_t state, const char *message,
    double fps, int32_t pn, int32_t pd, int32_t dn, int32_t dd, bool interlaced,
    const char *matrix, const char *range, const char *hdr, bool seekable) {
  if (kind == -1) { detach_count++; return; }
  g_assert_cmpint(event_count, <, 2);
  messages[event_count] = message;
  matrices[event_count++] = matrix;
}
static gboolean emit_snapshots(gpointer data) {
  GstpPlayer *p = data;
  g_strlcpy(p->color_matrix, "bt709", sizeof(p->color_matrix));
  gstp_player_emit(p, GSTP_EVENT_ERROR, "first error");
  g_strlcpy(p->color_matrix, "bt2020", sizeof(p->color_matrix));
  gstp_player_emit(p, GSTP_EVENT_ERROR, "second error");
  return G_SOURCE_REMOVE;
}
static void test_event_snapshots(void) {
  GstpPlayerId id = gstp_player_create(); g_assert_cmpint(id, >, 0);
  gstp_player_set_event_callback(id, NULL, event_callback);
  gstp_runtime_invoke_sync(emit_snapshots, gstp_player_lookup(id));
  g_assert_cmpstr(messages[0], ==, "first error");
  g_assert_cmpstr(messages[1], ==, "second error");
  g_assert_cmpstr(matrices[0], ==, "bt709");
  g_assert_cmpstr(matrices[1], ==, "bt2020");
  g_assert_true(gstp_player_detach_event_callback(id));
  g_assert_cmpint(detach_count, ==, 1);
  g_assert_false(gstp_player_detach_event_callback(id));
  gstp_event_free(messages[0]); gstp_event_free(messages[1]);
  gstp_player_dispose(id);
}
static gint callback_started, callback_finished;
static void slow_frame(void *ctx) {
  g_atomic_int_set(&callback_started, 1);
  g_usleep(100000);
  g_atomic_int_set(&callback_finished, 1);
}
static void test_frame_detach(void) {
  GstpPlayerId id = gstp_player_create();
  GstpPlayer *p = gstp_player_lookup(id);
  GError *error = NULL;
  GstElement *pipeline = gst_parse_launch("videotestsrc num-buffers=1 ! "
      "video/x-raw,format=BGRA,width=16,height=16 ! appsink name=sink sync=false", &error);
  g_assert_no_error(error); g_assert_nonnull(pipeline);
  GstElement *sink = gst_bin_get_by_name(GST_BIN(pipeline), "sink");
  p->pipeline = pipeline; p->appsink = sink;
  GstAppSinkCallbacks callbacks = {.new_sample = gstp_frame_on_new_sample};
  gst_app_sink_set_callbacks(GST_APP_SINK(sink), &callbacks, p, NULL);
  gstp_texture_register(id, NULL, slow_frame);
  gst_element_set_state(pipeline, GST_STATE_PLAYING);
  const gint64 deadline = g_get_monotonic_time() + 5 * G_USEC_PER_SEC;
  while (!g_atomic_int_get(&callback_started) && g_get_monotonic_time() < deadline) g_usleep(1000);
  g_assert_true(g_atomic_int_get(&callback_started));
  gstp_texture_unregister(id);
  g_assert_true(g_atomic_int_get(&callback_finished));
  uint8_t pixels[16 * 16 * 4];
  g_assert_true(gstp_texture_copy_latest(id, pixels, sizeof(pixels), NULL, NULL, NULL));
  gstp_player_dispose(id); gst_object_unref(sink);
  /* Reuse the same player slot: initialized mutexes must survive reset. */
  id = gstp_player_create(); gstp_texture_register(id, NULL, slow_frame);
  gstp_texture_unregister(id); gstp_player_dispose(id);
}
static void test_pixels(void) {
  const uint8_t source[] = {1,2,3,4,99,99,99,99,5,6,7,8};
  uint8_t tight[8], rgba[8];
  g_assert_true(gstp_copy_bgra_rows(tight, 8, source, sizeof(source), 1, 2, 8));
  g_assert_cmpint(tight[4], ==, 5);
  g_assert_false(gstp_copy_bgra_rows(tight, 8, source, 8, 1, 2, 8));
  g_assert_false(gstp_copy_bgra_rows(tight, 8, source, sizeof(source), INT32_MAX, 2, 8));
  gstp_bgra_to_rgba(tight, 1, 2, 4, rgba);
  g_assert_cmpint(rgba[0], ==, 3); g_assert_cmpint(rgba[6], ==, 5);
}
static void test_tls_defaults(void) {
  GstElement *source = gst_element_factory_make("souphttpsrc", NULL);
  g_assert_nonnull(source);
  g_object_set(source, "ssl-strict", FALSE, NULL);
  gstp_configure_http_source(source, NULL);
  gboolean strict = FALSE; guint timeout = 0;
  g_object_get(source, "ssl-strict", &strict, "timeout", &timeout, NULL);
  g_assert_true(strict); g_assert_cmpuint(timeout, ==, 15);
  gstp_configure_http_source_with_tls(source, NULL, FALSE);
  g_object_get(source, "ssl-strict", &strict, NULL);
  g_assert_false(strict);
  gstp_configure_http_source(source, NULL);
  g_object_get(source, "ssl-strict", &strict, NULL);
  g_assert_true(strict);
  gst_object_unref(source);
}
static gint capture_finished;
static gpointer capture_stalled(gpointer uri) {
  uint8_t *pixels = NULL; uint32_t len = 0;
  int32_t result = gstp_thumbnail_capture(uri, 0, 32, NULL, &pixels, &len, NULL, NULL, NULL);
  g_assert_cmpint(result, !=, 0);
  gstp_thumbnail_free(pixels);
  g_atomic_int_set(&capture_finished, 1);
  return NULL;
}
static void test_thumbnail_cancel(void) {
  int pipes[2]; g_assert_cmpint(pipe(pipes), ==, 0);
  char *uri = g_strdup_printf("fd://%d", pipes[0]);
  GThread *thread = g_thread_new("stalled-capture", capture_stalled, uri);
  const gint64 deadline = g_get_monotonic_time() + 5 * G_USEC_PER_SEC;
  do {
    g_usleep(100000);
    gstp_thumbnail_cancel();
  } while (!g_atomic_int_get(&capture_finished) && g_get_monotonic_time() < deadline);
  g_assert_true(g_atomic_int_get(&capture_finished));
  g_thread_join(thread); g_free(uri); close(pipes[0]); close(pipes[1]);
}
static void test_thumbnail_local_video(void) {
  const char *path = g_getenv("GSTP_TEST_VIDEO");
  g_assert_nonnull(path);
  char *uri = g_filename_to_uri(path, NULL, NULL);
  uint8_t *pixels = NULL; uint32_t len = 0; int32_t w=0, h=0, stride=0;
  g_assert_cmpint(gstp_thumbnail_capture(uri, 1000, 64, NULL,
      &pixels, &len, &w, &h, &stride), ==, 0);
  g_assert_nonnull(pixels); g_assert_cmpint(w, >, 0); g_assert_cmpint(w, <=, 64);
  g_assert_cmpint(h, >, 0); g_assert_cmpuint(len, ==, (uint32_t)(stride * h));
  gstp_thumbnail_free(pixels); g_free(uri);
}
int main(int argc, char **argv) {
  /* Optional SDK plugins may log missing external Python modules at discovery. */
  g_assert_cmpint(gstp_init(), ==, 0);
  g_test_init(&argc, &argv, NULL);
  g_assert_cmpstr(gstp_version(), ==, "0.0.6");
  g_test_add_func("/native/event-snapshots-and-detach", test_event_snapshots);
  g_test_add_func("/native/frame-detach-and-slot-reuse", test_frame_detach);
  g_test_add_func("/native/pixel-copy-bounds", test_pixels);
  g_test_add_func("/native/tls-defaults", test_tls_defaults);
  g_test_add_func("/native/thumbnail-cancel-stalled-source", test_thumbnail_cancel);
  g_test_add_func("/native/thumbnail-local-video", test_thumbnail_local_video);
  int result = g_test_run(); gstp_shutdown(); return result;
}
