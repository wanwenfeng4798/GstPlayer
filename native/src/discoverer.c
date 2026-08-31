#include "gstp_internal.h"

#include <gst/pbutils/pbutils.h>

typedef struct {
  GstpPlayerId id;
} GstpDiscoverOp;

static void gstp_on_discoverer_source_setup(GstDiscoverer *disc,
                                            GstElement *source,
                                            gpointer user_data) {
  (void)disc;
  gstp_configure_uri_child((GstpPlayer *)user_data, source);
}

static void gstp_on_discoverer_discovered(GstDiscoverer *disc,
                                          GstDiscovererInfo *info, GError *err,
                                          gpointer user_data) {
  GstpDiscoverOp *op = user_data;
  GstpPlayerId id = op ? op->id : 0;
  g_free(op);

  GstpPlayer *p = gstp_player_lookup(id);
  if (p && p->uri_discoverer == disc) {
    p->uri_discoverer = NULL;
  }

  gst_discoverer_stop(disc);
  g_object_unref(disc);

  if (!p || err || !info) {
    return;
  }
  if (gst_discoverer_info_get_result(info) != GST_DISCOVERER_OK) {
    return;
  }

  const GstClockTime dur = gst_discoverer_info_get_duration(info);
  if (!GST_CLOCK_TIME_IS_VALID(dur)) {
    return;
  }
  const int64_t ms = (int64_t)(dur / GST_MSECOND);
  if (ms <= 0) {
    return;
  }

  p->discovered_duration_ms = ms;
  if (gst_discoverer_info_get_seekable(info)) {
    p->seekable = true;
  }
  gstp_media_set_duration_ms(p, ms);
}

static gboolean gstp_discoverer_probe_cb(gpointer data) {
  GstpDiscoverOp *op = data;
  if (!op) {
    return G_SOURCE_REMOVE;
  }
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (!p || !p->media_uri[0]) {
    g_free(op);
    return G_SOURCE_REMOVE;
  }

  gstp_discoverer_cancel(p);
  p->discovered_duration_ms = -1;

  GError *err = NULL;
  GstDiscoverer *discoverer = gst_discoverer_new(20 * GST_SECOND, &err);
  if (!discoverer) {
    if (err) {
      g_error_free(err);
    }
    g_free(op);
    return G_SOURCE_REMOVE;
  }

  g_signal_connect(discoverer, "source-setup",
                   G_CALLBACK(gstp_on_discoverer_source_setup), p);
  g_signal_connect(discoverer, "discovered",
                   G_CALLBACK(gstp_on_discoverer_discovered), op);

  p->uri_discoverer = discoverer;

  if (!gst_discoverer_discover_uri_async(discoverer, p->media_uri)) {
    g_signal_handlers_disconnect_by_data(discoverer, op);
    p->uri_discoverer = NULL;
    g_object_unref(discoverer);
    g_free(op);
    return G_SOURCE_REMOVE;
  }
  gst_discoverer_start(discoverer);
  return G_SOURCE_REMOVE;
}

void gstp_discoverer_cancel(GstpPlayer *p) {
  if (!p || !p->uri_discoverer) {
    return;
  }
  GstDiscoverer *discoverer = p->uri_discoverer;
  p->uri_discoverer = NULL;
  gst_discoverer_stop(discoverer);
}

void gstp_discoverer_schedule(GstpPlayer *p) {
  if (!p || !p->media_uri[0]) {
    return;
  }
  GstpDiscoverOp *op = g_new(GstpDiscoverOp, 1);
  op->id = p->id;
  gstp_runtime_invoke_async(gstp_discoverer_probe_cb, op);
}
