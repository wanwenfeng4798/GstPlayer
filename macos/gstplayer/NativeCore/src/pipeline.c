#include "gstp_internal.h"
#include "http_source.h"

#include <glib/gstdio.h>
#include <gst/video/video.h>
#include <stdio.h>
#include <string.h>

static void gstp_apply_orient_element(GstElement *el, int32_t degrees) {
  if (!el) {
    return;
  }
  if (g_object_class_find_property(G_OBJECT_GET_CLASS(el), "rotation-z")) {
    gfloat z = 0.f;
    switch (degrees) {
    case 90:
      z = -90.f;
      break;
    case 180:
      z = -180.f;
      break;
    case 270:
      z = -270.f;
      break;
    default:
      z = 0.f;
      break;
    }
    g_object_set(el, "rotation-z", z, NULL);
    return;
  }
  if (g_object_class_find_property(G_OBJECT_GET_CLASS(el), "video-direction")) {
    GstVideoOrientationMethod dir = GST_VIDEO_ORIENTATION_IDENTITY;
    switch (degrees) {
    case 90:
      dir = GST_VIDEO_ORIENTATION_90R;
      break;
    case 180:
      dir = GST_VIDEO_ORIENTATION_180;
      break;
    case 270:
      dir = GST_VIDEO_ORIENTATION_90L;
      break;
    default:
      dir = GST_VIDEO_ORIENTATION_IDENTITY;
      break;
    }
    g_object_set(el, "video-direction", dir, NULL);
    return;
  }
  if (g_object_class_find_property(G_OBJECT_GET_CLASS(el), "method")) {
    const char *method = "none";
    switch (degrees) {
    case 90:
      method = "clockwise";
      break;
    case 180:
      method = "rotate-180";
      break;
    case 270:
      method = "counterclockwise";
      break;
    default:
      method = "none";
      break;
    }
    gst_util_set_object_arg(G_OBJECT(el), "method", method);
  }
}

#if !defined(__ANDROID__)
GstElement *gstp_desktop_make_video_sink(GstpPlayer *p) {
  GstElement *appsink = gst_element_factory_make("appsink", "gstp-appsink");
  if (!appsink) {
    return NULL;
  }
  GstCaps *caps = gst_caps_from_string("video/x-raw,format=BGRA");
  g_object_set(appsink, "emit-signals", FALSE, "sync", TRUE, "max-buffers", 2,
               "drop", TRUE, "caps", caps, NULL);
  gst_caps_unref(caps);

  GstAppSinkCallbacks cbs = {
      .eos = NULL,
      .new_preroll = NULL,
      .new_sample = gstp_frame_on_new_sample,
  };
  gst_app_sink_set_callbacks(GST_APP_SINK(appsink), &cbs, p, NULL);
  p->appsink = appsink;

  GstElement *videoflip =
      gst_element_factory_make("videoflip", "gstp-videoflip");
  GstElement *convert =
      gst_element_factory_make("videoconvert", "gstp-vconvert");
  GstElement *capsfilter =
      gst_element_factory_make("capsfilter", "gstp-bgra-caps");
  if (!videoflip || !convert || !capsfilter) {
    if (videoflip) {
      gst_object_unref(videoflip);
    }
    if (convert) {
      gst_object_unref(convert);
    }
    if (capsfilter) {
      gst_object_unref(capsfilter);
    }
    p->orient_element = NULL;
    return appsink;
  }

  GstCaps *bgra = gst_caps_from_string("video/x-raw,format=BGRA");
  g_object_set(capsfilter, "caps", bgra, NULL);
  gst_caps_unref(bgra);

  GstElement *bin = gst_bin_new("gstp-video-sink");
  gst_bin_add_many(GST_BIN(bin), videoflip, convert, capsfilter, appsink,
                   NULL);
  if (!gst_element_link_many(videoflip, convert, capsfilter, appsink, NULL)) {
    gst_object_unref(bin);
    p->orient_element = NULL;
    p->appsink = NULL;
    return NULL;
  }
  GstPad *pad = gst_element_get_static_pad(videoflip, "sink");
  GstPad *ghost = gst_ghost_pad_new("sink", pad);
  gst_object_unref(pad);
  gst_element_add_pad(bin, ghost);
  p->orient_element = videoflip;
  gstp_apply_orient_element(videoflip, p->rotate_degrees);
  return bin;
}
#endif

#if defined(__ANDROID__)
#include <android/native_window.h>

/* Update layout metadata from negotiated video caps and notify Dart.
 * Display-only on Android: glupload → glcolorconvert → glvideoflip → queue →
 * glimagesink. No tee/gldownload/appsink — External-OES capture branch breaks
 * amcvideodec pause/resume under rapid toggles (see gst-plugins-bad amcvideodec
 * gl_sync warnings). Screenshots use headless captureThumbnail from Dart.
 */
static void gstp_apply_video_size_from_caps(GstpPlayer *p, GstCaps *caps) {
  if (!p || !caps || gst_caps_is_empty(caps) || gst_caps_is_any(caps)) {
    return;
  }
  const GstStructure *s = gst_caps_get_structure(caps, 0);
  if (!s) {
    return;
  }
  gint width = 0;
  gint height = 0;
  if (!gst_structure_get_int(s, "width", &width) ||
      !gst_structure_get_int(s, "height", &height) || width <= 0 ||
      height <= 0) {
    return;
  }
  gint par_n = 1;
  gint par_d = 1;
  gst_structure_get_fraction(s, "pixel-aspect-ratio", &par_n, &par_d);
  if (par_n <= 0) {
    par_n = 1;
  }
  if (par_d <= 0) {
    par_d = 1;
  }
  const gint dar_n = width * par_n;
  const gint dar_d = height * par_d;
  if (p->width == width && p->height == height && p->par_n == par_n &&
      p->par_d == par_d && p->dar_n == dar_n && p->dar_d == dar_d) {
    return;
  }
  p->width = width;
  p->height = height;
  p->par_n = par_n;
  p->par_d = par_d;
  p->dar_n = dar_n;
  p->dar_d = dar_d;
  p->suppress_timing_emit = false;
  gstp_player_emit(p, GSTP_EVENT_VIDEO_SIZE, "");
  gstp_player_emit(p, GSTP_EVENT_METADATA_CHANGED, "");
}

static GstPadProbeReturn gstp_android_sink_caps_probe(GstPad *pad,
                                                      GstPadProbeInfo *info,
                                                      gpointer user_data) {
  GstpPlayer *p = user_data;
  if (!p || !p->in_use) {
    return GST_PAD_PROBE_OK;
  }
  if (!(info->type & GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM)) {
    return GST_PAD_PROBE_OK;
  }
  GstEvent *event = GST_PAD_PROBE_INFO_EVENT(info);
  if (!event || GST_EVENT_TYPE(event) != GST_EVENT_CAPS) {
    return GST_PAD_PROBE_OK;
  }
  GstCaps *caps = NULL;
  gst_event_parse_caps(event, &caps);
  if (caps) {
    gstp_apply_video_size_from_caps(p, caps);
  }
  (void)pad;
  return GST_PAD_PROBE_OK;
}

static void gstp_try_update_video_size_from_sink(GstpPlayer *p) {
  if (!p || !p->pipeline) {
    return;
  }
  /* Prefer post-orient pad (glimagesink) so size reflects glvideoflip swap. */
  GstElement *vsink = NULL;
  g_object_get(p->pipeline, "video-sink", &vsink, NULL);
  if (!vsink) {
    return;
  }
  GstElement *probe_el = NULL;
  if (GST_IS_BIN(vsink)) {
    probe_el = gst_bin_get_by_name(GST_BIN(vsink), "gstp-glimagesink");
    if (!probe_el) {
      probe_el = gst_bin_get_by_name(GST_BIN(vsink), "gstp-glvideoflip");
    }
  }
  if (!probe_el) {
    probe_el = gst_object_ref(vsink);
  }
  gst_object_unref(vsink);
  GstPad *sinkpad = gst_element_get_static_pad(probe_el, "sink");
  gst_object_unref(probe_el);
  if (!sinkpad) {
    return;
  }
  GstCaps *caps = gst_pad_get_current_caps(sinkpad);
  if (caps) {
    gstp_apply_video_size_from_caps(p, caps);
    gst_caps_unref(caps);
  }
  gst_object_unref(sinkpad);
}

GstElement *gstp_android_make_video_sink(GstpPlayer *p) {
  GstElement *glupload =
      gst_element_factory_make("glupload", "gstp-glupload");
  GstElement *glcc =
      gst_element_factory_make("glcolorconvert", "gstp-glcolorconvert");
  GstElement *glflip =
      gst_element_factory_make("glvideoflip", "gstp-glvideoflip");
  GstElement *q_display =
      gst_element_factory_make("queue", "gstp-q-display");
  GstElement *sink =
      gst_element_factory_make("glimagesink", "gstp-glimagesink");

  if (!glupload || !glcc || !glflip || !q_display || !sink) {
    if (glupload) {
      gst_object_unref(glupload);
    }
    if (glcc) {
      gst_object_unref(glcc);
    }
    if (glflip) {
      gst_object_unref(glflip);
    }
    if (q_display) {
      gst_object_unref(q_display);
    }
    if (sink) {
      gst_object_unref(sink);
    }
    p->orient_element = NULL;
    p->overlay_element = NULL;
    p->appsink = NULL;
    return NULL;
  }

  /* Dart FittedBox owns fit/fill/stretch; native must fill the buffer or
   * portrait frames are letterboxed into a landscape SurfaceProducer. */
  g_object_set(sink, "force-aspect-ratio", FALSE, NULL);
  /* Keep display cadence smooth; avoid leaky queue frame drops. */
  g_object_set(q_display, "max-size-buffers", 0, "max-size-time", (guint64)0,
               "max-size-bytes", (guint)0, NULL);

  p->appsink = NULL;

  GstElement *bin = gst_bin_new("gstp-video-sink");
  gst_bin_add_many(GST_BIN(bin), glupload, glcc, glflip, q_display, sink, NULL);

  if (!gst_element_link_many(glupload, glcc, glflip, q_display, sink, NULL)) {
    gst_object_unref(bin);
    p->orient_element = NULL;
    p->overlay_element = NULL;
    p->appsink = NULL;
    return NULL;
  }

  GstPad *pad = gst_element_get_static_pad(glupload, "sink");
  GstPad *ghost = gst_ghost_pad_new("sink", pad);
  gst_object_unref(pad);
  gst_element_add_pad(bin, ghost);
  p->orient_element = glflip;
  p->overlay_element = GST_IS_VIDEO_OVERLAY(sink) ? sink : NULL;
  gstp_apply_orient_element(glflip, p->rotate_degrees);

  /* Post-orient pad: size matches glvideoflip output (axes swapped for 90/270). */
  GstPad *sink_pad = gst_element_get_static_pad(sink, "sink");
  if (sink_pad) {
    gst_pad_add_probe(sink_pad, GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM,
                      gstp_android_sink_caps_probe, p, NULL);
    gst_object_unref(sink_pad);
  }
  return bin;
}

static GstElement *gstp_resolve_overlay(GstpPlayer *p) {
  if (p->overlay_element && GST_IS_VIDEO_OVERLAY(p->overlay_element)) {
    return gst_object_ref(p->overlay_element);
  }
  if (!p->pipeline) {
    return NULL;
  }
  GstElement *sink = NULL;
  g_object_get(p->pipeline, "video-sink", &sink, NULL);
  if (!sink) {
    return NULL;
  }
  if (GST_IS_VIDEO_OVERLAY(sink)) {
    return sink;
  }
  if (GST_IS_BIN(sink)) {
    GstIterator *it = gst_bin_iterate_recurse(GST_BIN(sink));
    GValue item = G_VALUE_INIT;
    GstElement *found = NULL;
    while (gst_iterator_next(it, &item) == GST_ITERATOR_OK) {
      GstElement *child = g_value_get_object(&item);
      if (child && GST_IS_VIDEO_OVERLAY(child)) {
        found = gst_object_ref(child);
        g_value_unset(&item);
        break;
      }
      g_value_unset(&item);
    }
    gst_iterator_free(it);
    gst_object_unref(sink);
    if (found) {
      /* Non-owning cache; bin owns the element. */
      p->overlay_element = found;
      gst_object_unref(found);
      return gst_object_ref(p->overlay_element);
    }
    return NULL;
  }
  gst_object_unref(sink);
  return NULL;
}

void gstp_android_release_window(GstpPlayer *p) {
  if (p->android_window == 0) {
    return;
  }
  ANativeWindow *win = (ANativeWindow *)(intptr_t)p->android_window;
  ANativeWindow_release(win);
  p->android_window = 0;
  p->android_w = 0;
  p->android_h = 0;
  p->android_overlay_bound = false;
}

/* Detach VideoOverlay from the current pipeline without releasing the
 * ANativeWindow. SurfaceProducer does not re-fire onSurfaceAvailable on media
 * reload, so the window must survive destroy/load. */
static void gstp_android_unbind_overlay(GstpPlayer *p) {
  GstElement *overlay = gstp_resolve_overlay(p);
  if (overlay) {
    gst_video_overlay_set_window_handle(GST_VIDEO_OVERLAY(overlay), 0);
    gst_object_unref(overlay);
  }
  p->android_overlay_bound = false;
  p->overlay_element = NULL;
}

void gstp_android_clear_overlay(GstpPlayer *p) {
  /* Mid-play SurfaceProducer.setSize clears the window; glimagesink then
   * blocks the whole playbin (A+V). Remember resume intent so rebind plays. */
  if (p->desired_playing) {
    p->pending_auto_play = true;
  }
  gstp_android_unbind_overlay(p);
  gstp_android_release_window(p);
}

void gstp_android_apply_overlay(GstpPlayer *p) {
  if (!p->pipeline || p->android_window == 0) {
    return;
  }
  /* Prefer live ANativeWindow size over a stale first-bind cache. */
  ANativeWindow *win = (ANativeWindow *)(intptr_t)p->android_window;
  const int32_t live_w = ANativeWindow_getWidth(win);
  const int32_t live_h = ANativeWindow_getHeight(win);
  if (live_w > 0 && live_h > 0) {
    p->android_w = live_w;
    p->android_h = live_h;
  }
  GstElement *overlay = gstp_resolve_overlay(p);
  if (overlay) {
    gst_video_overlay_set_window_handle(GST_VIDEO_OVERLAY(overlay),
                                        (guintptr)p->android_window);
    if (p->android_w > 0 && p->android_h > 0) {
      gst_video_overlay_set_render_rectangle(GST_VIDEO_OVERLAY(overlay), 0, 0,
                                             p->android_w, p->android_h);
    }
    /* GStreamer Android tutorial: expose twice so GLES picks up size changes. */
    gst_video_overlay_expose(GST_VIDEO_OVERLAY(overlay));
    gst_video_overlay_expose(GST_VIDEO_OVERLAY(overlay));
    p->android_overlay_bound = true;
    gst_object_unref(overlay);
  }

  if (!(p->pending_auto_play || p->desired_playing)) {
    return;
  }
  /* Do not play before the pipeline has reached PAUSED (load mid-flight). */
  GstState cur = GST_STATE_NULL;
  gst_element_get_state(p->pipeline, &cur, NULL, 0);
  const bool gst_ready =
      (cur == GST_STATE_PAUSED || cur == GST_STATE_PLAYING);
  const bool ui_ready =
      p->player_state == GSTP_STATE_READY ||
      p->player_state == GSTP_STATE_BUFFERING ||
      p->player_state == GSTP_STATE_PLAYING ||
      p->player_state == GSTP_STATE_PAUSED;
  if (!gst_ready && !ui_ready) {
    return;
  }
  p->pending_auto_play = false;
  /* Always kick play after rebind — even if GST already reports PLAYING, a
   * prior window=0 stall may have left sinks blocked until play+expose. */
  gstp_pipeline_play(p);
}
#endif

static void gstp_reset_media_fields(GstpPlayer *p) {
  p->duration_ms = 0;
  p->position_ms = 0;
  p->tag_duration_ms = -1;
  p->last_frame_pts_ms = -1;
  p->play_wall_origin_us = 0;
  p->play_position_origin_ms = 0;
  p->scrub_hold_target_ms = 0;
  p->scrub_hold_until_us = 0;
  p->width = 0;
  p->height = 0;
  p->fps = 0;
  p->par_n = 1;
  p->par_d = 1;
  p->dar_n = 0;
  p->dar_d = 0;
  p->interlaced = false;
  p->track_count = 0;
  p->at_eos = false;
  p->replay_preroll = false;
  p->replay_preroll_since_us = 0;
  p->suppress_timing_emit = false;
  p->seekable = true;
  p->buffering_percent = 100;
  p->pending_rate_seek = false;
  p->rotate_degrees = 0;
  p->color_matrix[0] = '\0';
  p->color_range[0] = '\0';
  p->hdr_format[0] = '\0';
  p->media_uri[0] = '\0';
  gstp_frame_clear(p);
}

static void gstp_clear_asset_temp(GstpPlayer *p) {
  if (p->asset_temp_path[0] != '\0') {
    g_unlink(p->asset_temp_path);
    p->asset_temp_path[0] = '\0';
  }
  if (p->asset_bytes) {
    g_free(p->asset_bytes);
    p->asset_bytes = NULL;
    p->asset_len = 0;
    p->asset_offset = 0;
  }
}

static int32_t gstp_pipeline_set_state_sync(GstpPlayer *p, GstState state);

void gstp_pipeline_destroy(GstpPlayer *p) {
  gstp_bus_detach(p);
  if (p->appsink) {
    gst_app_sink_set_callbacks(GST_APP_SINK(p->appsink), NULL, NULL, NULL);
  }
#if defined(__ANDROID__)
  /* Keep ANativeWindow across reload; only unbind from the old pipeline. */
  gstp_android_unbind_overlay(p);
#endif
  if (p->pipeline) {
    (void)gstp_pipeline_set_state_sync(p, GST_STATE_NULL);
    gst_object_unref(p->pipeline);
    p->pipeline = NULL;
  }
  p->appsink = NULL;
  p->appsrc = NULL;
  p->orient_element = NULL;
  p->overlay_element = NULL;
  if (p->stream_collection) {
    gst_object_unref(p->stream_collection);
    p->stream_collection = NULL;
  }
  p->buffering_percent = 100;
  p->pending_rate_seek = false;
  gstp_clear_asset_temp(p);
}

static bool gstp_pipeline_usable_after_failure(GstpPlayer *p) {
  if (!p->pipeline) {
    return false;
  }
  GstState cur = GST_STATE_NULL;
  gst_element_get_state(p->pipeline, &cur, NULL, 0);
  if (cur == GST_STATE_PAUSED || cur == GST_STATE_PLAYING) {
    return true;
  }
  /* Autoplug can leave GstState at READY while duration/UI already advanced. */
  if (p->duration_ms > 0) {
    return true;
  }
  if (p->player_state == GSTP_STATE_BUFFERING ||
      p->player_state == GSTP_STATE_PLAYING ||
      p->player_state == GSTP_STATE_PAUSED ||
      p->player_state == GSTP_STATE_READY) {
    return true;
  }
  return false;
}

static int32_t gstp_pipeline_set_state_sync(GstpPlayer *p, GstState state) {
  if (!p->pipeline) {
    return GSTP_ERR_NOT_READY;
  }
  GstStateChangeReturn ret = gst_element_set_state(p->pipeline, state);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    return gstp_pipeline_usable_after_failure(p) ? GSTP_ERR_OK : GSTP_ERR_FAIL;
  }
  /* Avoid blocking runtime thread on state acks during rapid play/pause.
   * We rely on bus STATE_CHANGED events to converge UI/native state. */
  return GSTP_ERR_OK;
}

static GstElement *gstp_make_playbin(void) {
  GstElement *pipeline = gst_element_factory_make("playbin3", "gstp-playbin");
  if (!pipeline) {
    pipeline = gst_element_factory_make("playbin", "gstp-playbin");
  }
  return pipeline;
}

static gboolean gstp_uri_is_network(const char *uri) {
  return uri &&
         (g_str_has_prefix(uri, "http://") || g_str_has_prefix(uri, "https://") ||
          g_str_has_prefix(uri, "rtsp://") || g_str_has_prefix(uri, "rtmp://"));
}

static void gstp_configure_playbin(GstpPlayer *p, GstElement *pipeline,
                                   const char *uri) {
  if (!pipeline) {
    return;
  }
  GObjectClass *klass = G_OBJECT_GET_CLASS(pipeline);
  if (gstp_uri_is_network(uri) &&
      g_object_class_find_property(klass, "flags")) {
    gint flags = 0;
    g_object_get(pipeline, "flags", &flags, NULL);
    /* GST_PLAY_FLAG_DOWNLOAD | GST_PLAY_FLAG_BUFFER */
    flags |= (1 << 7) | (1 << 8);
    g_object_set(pipeline, "flags", flags, NULL);
  }
  if (gstp_uri_is_network(uri) &&
      g_object_class_find_property(klass, "download")) {
    g_object_set(pipeline, "download", TRUE, NULL);
  }
}

static void gstp_apply_segment_event_to_duration(GstpPlayer *p,
                                                 GstEvent *event) {
  if (!p || !event || GST_EVENT_TYPE(event) != GST_EVENT_SEGMENT) {
    return;
  }
  const GstSegment *seg = NULL;
  gst_event_parse_segment(event, &seg);
  if (!seg || seg->format != GST_FORMAT_TIME) {
    return;
  }
  if (!GST_CLOCK_TIME_IS_VALID(seg->stop) || seg->stop <= seg->start) {
    return;
  }
  const gint64 max = (gint64)(7LL * 24 * 3600 * GST_SECOND);
  if (seg->stop > max) {
    return;
  }
  const int64_t ms = (int64_t)(seg->stop / GST_MSECOND);
  if (ms <= 0) {
    return;
  }
  gstp_media_set_duration_ms(p, ms);
}

static GstPadProbeReturn gstp_demux_segment_duration_probe(GstPad *pad,
                                                           GstPadProbeInfo *info,
                                                           gpointer user_data);

static void gstp_attach_segment_probe_to_pad(GstpPlayer *p, GstPad *pad) {
  if (!p || !pad || g_object_get_data(G_OBJECT(pad), "gstp-seg-dur")) {
    return;
  }
  g_object_set_data(G_OBJECT(pad), "gstp-seg-dur", GINT_TO_POINTER(1));

  guint sticky_idx = 0;
  GstEvent *sticky = NULL;
  while ((sticky = gst_pad_get_sticky_event(pad, GST_EVENT_SEGMENT,
                                            sticky_idx)) != NULL) {
    gstp_apply_segment_event_to_duration(p, sticky);
    sticky_idx++;
  }

  gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM,
                    gstp_demux_segment_duration_probe, p, NULL);
}

static GstPadProbeReturn gstp_demux_segment_duration_probe(GstPad *pad,
                                                           GstPadProbeInfo *info,
                                                           gpointer user_data) {
  (void)pad;
  GstpPlayer *p = user_data;
  if (!p || !(info->type & GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM)) {
    return GST_PAD_PROBE_OK;
  }
  GstEvent *event = GST_PAD_PROBE_INFO_EVENT(info);
  gstp_apply_segment_event_to_duration(p, event);
  return GST_PAD_PROBE_OK;
}

static gboolean gstp_foreach_demux_pad(GstElement *element, GstPad *pad,
                                       gpointer user_data) {
  (void)element;
  gstp_attach_segment_probe_to_pad((GstpPlayer *)user_data, pad);
  return TRUE;
}

static void gstp_on_demux_pad_added(GstElement *element, GstPad *pad,
                                    gpointer user_data) {
  (void)element;
  gstp_attach_segment_probe_to_pad((GstpPlayer *)user_data, pad);
}

static void gstp_attach_demux_duration_probe(GstpPlayer *p, GstElement *element) {
  GstElementFactory *factory = gst_element_get_factory(element);
  if (!factory) {
    return;
  }
  const gchar *fname =
      gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
  if (strcmp(fname, "qtdemux") != 0 && strcmp(fname, "movdemux") != 0 &&
      strcmp(fname, "avidemux") != 0) {
    return;
  }
  if (g_object_get_data(G_OBJECT(element), "gstp-demux-probe")) {
    gst_element_foreach_pad(element, gstp_foreach_demux_pad, p);
    return;
  }
  g_object_set_data(G_OBJECT(element), "gstp-demux-probe", GINT_TO_POINTER(1));
  g_signal_connect(element, "pad-added", G_CALLBACK(gstp_on_demux_pad_added), p);
  gst_element_foreach_pad(element, gstp_foreach_demux_pad, p);
}

void gstp_ensure_demux_duration_probes(GstpPlayer *p) {
  if (!p || !p->pipeline || !GST_IS_BIN(p->pipeline)) {
    return;
  }
  GstIterator *it = gst_bin_iterate_recurse(GST_BIN(p->pipeline));
  if (!it) {
    return;
  }
  GValue item = G_VALUE_INIT;
  GstIteratorResult res;
  while ((res = gst_iterator_next(it, &item)) == GST_ITERATOR_OK) {
    GstElement *element = GST_ELEMENT(g_value_get_object(&item));
    if (element) {
      gstp_attach_demux_duration_probe(p, element);
    }
    g_value_reset(&item);
  }
  g_value_unset(&item);
  gst_iterator_free(it);
}

void gstp_configure_uri_child(GstpPlayer *p, GstElement *element) {
  if (!element || !p) {
    return;
  }
  gstp_configure_http_source(element, p->http_headers);

  GstElementFactory *factory = gst_element_get_factory(element);
  if (!factory) {
    return;
  }
  const gchar *fname =
      gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
  GObjectClass *klass = G_OBJECT_GET_CLASS(element);

  if (gstp_uri_is_network(p->media_uri) &&
      (strcmp(fname, "urisourcebin") == 0 || strcmp(fname, "uridecodebin") == 0 ||
       strcmp(fname, "decodebin3") == 0 || strcmp(fname, "decodebin") == 0)) {
    if (g_object_class_find_property(klass, "download")) {
      g_object_set(element, "download", TRUE, NULL);
    }
    if (g_object_class_find_property(klass, "use-buffering")) {
      g_object_set(element, "use-buffering", TRUE, NULL);
    }
    if (strcmp(fname, "urisourcebin") == 0 &&
        g_object_class_find_property(klass, "parse-streams")) {
      g_object_set(element, "parse-streams", TRUE, NULL);
    }
  }
}

static void gstp_clear_http_headers(GstpPlayer *p) {
  if (!p) {
    return;
  }
  gstp_http_headers_free(p->http_headers);
  p->http_headers = NULL;
}

static void gstp_set_http_headers_json(GstpPlayer *p, const char *json) {
  gstp_clear_http_headers(p);
  if (!json || !*json) {
    return;
  }
  p->http_headers = gstp_http_headers_from_json(json);
}

static void gstp_on_source_setup(GstElement *playbin, GstElement *source,
                                 gpointer user_data) {
  (void)playbin;
  GstpPlayer *p = (GstpPlayer *)user_data;
  gstp_configure_uri_child(p, source);
}

static void gstp_on_element_setup(GstElement *bin, GstElement *element,
                                  gpointer user_data) {
  (void)bin;
  GstpPlayer *p = (GstpPlayer *)user_data;
  gstp_configure_uri_child(p, element);
  gstp_attach_demux_duration_probe(p, element);
}

static void gstp_attach_http_source_handlers(GstElement *pipeline,
                                             GstpPlayer *p) {
  if (!pipeline) {
    return;
  }
  g_signal_connect(pipeline, "source-setup", G_CALLBACK(gstp_on_source_setup),
                   p);
  /* playbin3 / urisourcebin may create souphttpsrc as a nested child. */
  g_signal_connect(pipeline, "element-setup", G_CALLBACK(gstp_on_element_setup),
                   p);
}

static void gstp_attach_video_sink(GstpPlayer *p, GstElement *pipeline) {
  p->orient_element = NULL;
#if defined(__ANDROID__)
  GstElement *vsink = gstp_android_make_video_sink(p);
#else
  GstElement *vsink = gstp_desktop_make_video_sink(p);
#endif
  if (vsink) {
    g_object_set(pipeline, "video-sink", vsink, NULL);
  }
}

/* Pitch-preserving rate changes via scaletempo; fall back to default sink. */
static void gstp_attach_audio_sink(GstElement *pipeline) {
  GstElement *scaletempo =
      gst_element_factory_make("scaletempo", "gstp-scaletempo");
  GstElement *convert =
      gst_element_factory_make("audioconvert", "gstp-aconvert");
  GstElement *resample =
      gst_element_factory_make("audioresample", "gstp-aresample");
  GstElement *sink =
      gst_element_factory_make("autoaudiosink", "gstp-asink");
  if (!scaletempo || !convert || !resample || !sink) {
    if (scaletempo) {
      gst_object_unref(scaletempo);
    }
    if (convert) {
      gst_object_unref(convert);
    }
    if (resample) {
      gst_object_unref(resample);
    }
    if (sink) {
      gst_object_unref(sink);
    }
    return;
  }

  GstElement *bin = gst_bin_new("gstp-audio-sink");
  gst_bin_add_many(GST_BIN(bin), scaletempo, convert, resample, sink, NULL);
  if (!gst_element_link_many(scaletempo, convert, resample, sink, NULL)) {
    gst_object_unref(bin);
    return;
  }
  GstPad *pad = gst_element_get_static_pad(scaletempo, "sink");
  GstPad *ghost = gst_ghost_pad_new("sink", pad);
  gst_object_unref(pad);
  gst_element_add_pad(bin, ghost);
  g_object_set(pipeline, "audio-sink", bin, NULL);
}

#if defined(__ANDROID__)
typedef struct {
  GstpPlayerId id;
} GstpDeferredPlay;

static gboolean gstp_deferred_play_cb(gpointer data) {
  GstpDeferredPlay *op = data;
  GstpPlayer *p = gstp_player_lookup(op->id);
  if (p && p->pipeline && (p->pending_auto_play || p->desired_playing)) {
    p->pending_auto_play = false;
    (void)gstp_pipeline_play(p);
  }
  g_free(op);
  return G_SOURCE_REMOVE;
}
#endif

/* Local/asset never emit GST_MESSAGE_BUFFERING. Network must stay at 0 until
 * BUFFERING / PLAYING — a fake 100% races with qtdemux/avidemux download fill
 * and makes the loading percent jump backwards. */
static void gstp_finish_load_buffering(GstpPlayer *p) {
  if (p->is_uri) {
    return;
  }
  p->buffering_percent = 100;
  gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
}

int32_t gstp_pipeline_load_uri(GstpPlayer *p, const char *uri, bool auto_play,
                               const char *http_headers_json) {
  if (!uri || !*uri) {
    return GSTP_ERR_FAIL;
  }
  gstp_pipeline_destroy(p);
  gstp_reset_media_fields(p);
  gstp_set_http_headers_json(p, http_headers_json);
  /* Drop stale UI state so early apply_overlay does not play before PAUSED. */
  gstp_player_set_state(p, GSTP_STATE_IDLE);
  g_strlcpy(p->media_uri, uri, sizeof(p->media_uri));
  p->is_uri = gstp_uri_is_network(uri);
  p->suppress_timing_emit = true;
  p->desired_playing = auto_play;
  p->pending_auto_play = auto_play;

  GstElement *pipeline = gstp_make_playbin();
  if (!pipeline) {
    return GSTP_ERR_FAIL;
  }

  g_object_set(pipeline, "uri", uri, NULL);
  gstp_configure_playbin(p, pipeline, uri);
  gstp_attach_http_source_handlers(pipeline, p);
  gstp_attach_video_sink(p, pipeline);
  gstp_attach_audio_sink(pipeline);

  p->pipeline = pipeline;
  g_object_set(pipeline, "volume", p->volume, NULL);
  g_object_set(pipeline, "mute", p->muted, NULL);

  gstp_bus_attach(p);

  /* Optimistic buffering before blocking PAUSED preroll (network open UI). */
  p->buffering_percent = 0;
  gstp_player_set_state(p, GSTP_STATE_BUFFERING);
  gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");

#if defined(__ANDROID__)
  if (p->android_window != 0) {
    gstp_android_apply_overlay(p);
  }
#endif

  int32_t rc = gstp_pipeline_set_state_sync(p, GST_STATE_PAUSED);
#if defined(__ANDROID__)
  if (rc != GSTP_ERR_OK) {
    /* get_state blocks the GST thread so bus watches may not have run yet.
     * Drain pending sources, then re-check; still return OK if the pipeline
     * exists so Dart does not tear down a usable session. */
    GstpRuntime *rt = gstp_runtime();
    if (rt && rt->ctx) {
      while (g_main_context_iteration(rt->ctx, FALSE)) {
      }
    }
    if (gstp_pipeline_usable_after_failure(p) || p->pipeline != NULL) {
      rc = GSTP_ERR_OK;
    }
  }
  if (rc != GSTP_ERR_OK) {
    return rc;
  }

  /* Clear optimistic 0% so UI spinner hides when GStreamer never emits
   * BUFFERING (local/asset). Network waits for GST_MESSAGE_BUFFERING. */
  gstp_finish_load_buffering(p);

  gstp_player_set_state(p, GSTP_STATE_READY);
  /* Caps may already be negotiated after preroll; emit size so Dart layout
   * does not stay on the 16:9 fallback until the next CAPS event. */
  gstp_try_update_video_size_from_sink(p);

  /* Do not return play()'s result as load failure: buffering/autoplug can
   * make set_state(PLAYING) report FAILURE while the pipeline is usable. */
  if (auto_play) {
    p->desired_playing = true;
    p->pending_auto_play = true;
    if (p->android_window != 0) {
      if (!p->android_overlay_bound) {
        gstp_android_apply_overlay(p);
      }
      GstpDeferredPlay *op = g_new(GstpDeferredPlay, 1);
      op->id = p->id;
      gstp_runtime_invoke_async(gstp_deferred_play_cb, op);
    }
  }
  return GSTP_ERR_OK;
#else
  if (rc != GSTP_ERR_OK) {
    return rc;
  }

  gstp_finish_load_buffering(p);

  gstp_player_set_state(p, GSTP_STATE_READY);
  gstp_media_update_timing(p);

  if (auto_play) {
    return gstp_pipeline_play(p);
  }
  return GSTP_ERR_OK;
#endif
}

int32_t gstp_pipeline_load_asset(GstpPlayer *p, const uint8_t *bytes,
                                 uint32_t len, bool auto_play) {
  if (!bytes || len == 0) {
    return GSTP_ERR_FAIL;
  }

  /* Write bytes to a temp file and play via playbin (same path as URI).
   * GLib requires XXXXXX at the end of the template (no suffix after it).
   * Use only GLib I/O after g_file_open_tmp: on Windows the FD belongs to
   * glib's CRT and must not be passed to MSVC _write/_close. */
  gchar *tmp_path = NULL;
  gint fd = g_file_open_tmp("gstp-asset-XXXXXX", &tmp_path, NULL);
  if (fd < 0 || !tmp_path) {
    g_free(tmp_path);
    return GSTP_ERR_FAIL;
  }
  (void)g_close(fd, NULL);
  if (!g_file_set_contents(tmp_path, (const gchar *)bytes, (gssize)len,
                           NULL)) {
    g_unlink(tmp_path);
    g_free(tmp_path);
    return GSTP_ERR_FAIL;
  }

  gchar *file_uri = g_filename_to_uri(tmp_path, NULL, NULL);
  if (!file_uri) {
    g_unlink(tmp_path);
    g_free(tmp_path);
    return GSTP_ERR_FAIL;
  }

  int32_t rc = gstp_pipeline_load_uri(p, file_uri, auto_play, NULL);
  g_free(file_uri);
  if (rc != GSTP_ERR_OK) {
    /* If the pipeline was created and may still be reading the file, keep the
     * temp path for destroy — unlinking now causes "Internal data stream
     * error". */
    if (p->pipeline != NULL) {
      strncpy(p->asset_temp_path, tmp_path, sizeof(p->asset_temp_path) - 1);
      p->asset_temp_path[sizeof(p->asset_temp_path) - 1] = '\0';
      g_free(tmp_path);
    } else {
      g_unlink(tmp_path);
      g_free(tmp_path);
    }
    return rc;
  }

  p->is_uri = false;
  strncpy(p->asset_temp_path, tmp_path, sizeof(p->asset_temp_path) - 1);
  p->asset_temp_path[sizeof(p->asset_temp_path) - 1] = '\0';
  g_free(tmp_path);
  return GSTP_ERR_OK;
}

/*
 * Unified flush-seek for user scrub and near-end native play restart.
 * qtdemux / avidemux may require READY fallback after EOS (see comments below).
 */

static void gstp_clear_replay_preroll(GstpPlayer *p) {
  if (!p) {
    return;
  }
  p->replay_preroll = false;
  p->replay_preroll_since_us = 0;
}

static gboolean gstp_seek_to_ns_flags(GstElement *pipeline, gdouble rate,
                                      gint64 pos_ns, GstSeekFlags mode_flags) {
  const GstSeekFlags flags =
      (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | mode_flags);
  if (gst_element_seek(
          pipeline, rate, GST_FORMAT_TIME, flags, GST_SEEK_TYPE_SET, pos_ns,
          GST_SEEK_TYPE_NONE, GST_CLOCK_TIME_NONE)) {
    return (gboolean)1;
  }
  return gst_element_seek_simple(pipeline, GST_FORMAT_TIME, flags, pos_ns);
}

static gboolean gstp_wait_seek_completed(GstElement *pipeline) {
  if (!pipeline) {
    return (gboolean)0;
  }
  GstState cur = GST_STATE_NULL;
  GstState pending = GST_STATE_VOID_PENDING;
  const GstStateChangeReturn ret =
      gst_element_get_state(pipeline, &cur, &pending, 10 * GST_SECOND);
  return (gboolean)(ret != GST_STATE_CHANGE_FAILURE);
}

static gboolean gstp_set_pipeline_state_and_wait(GstElement *pipeline,
                                                 GstState state) {
  if (!pipeline) {
    return (gboolean)0;
  }
  if (gst_element_set_state(pipeline, state) == GST_STATE_CHANGE_FAILURE) {
    return (gboolean)0;
  }
  GstState cur = GST_STATE_NULL;
  GstState pending = GST_STATE_VOID_PENDING;
  const GstStateChangeReturn ret =
      gst_element_get_state(pipeline, &cur, &pending, GST_CLOCK_TIME_NONE);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    return (gboolean)0;
  }
  return (gboolean)(cur == state && pending == GST_STATE_VOID_PENDING);
}

static gboolean gstp_seek_landed_near(GstElement *pipeline, gint64 target_ns,
                                      gint64 tolerance_ns) {
  gint64 cur = GST_CLOCK_TIME_NONE;
  if (!gst_element_query_position(pipeline, GST_FORMAT_TIME, &cur) ||
      !GST_CLOCK_TIME_IS_VALID(cur)) {
    return (gboolean)0;
  }
  const gint64 delta = cur > target_ns ? cur - target_ns : target_ns - cur;
  return (gboolean)(delta <= tolerance_ns);
}

static gboolean gstp_flush_seek_verified(GstpPlayer *p, gint64 pos_ns,
                                         gdouble rate, GstSeekFlags mode_flags,
                                         gint64 tolerance_ns) {
  if (!p->pipeline) {
    return (gboolean)0;
  }
  if (!gstp_seek_to_ns_flags(p->pipeline, rate, pos_ns, mode_flags)) {
    return (gboolean)0;
  }
  if (!gstp_wait_seek_completed(p->pipeline)) {
    return (gboolean)0;
  }
  return gstp_seek_landed_near(p->pipeline, pos_ns, tolerance_ns);
}

static gboolean gstp_flush_seek(GstpPlayer *p, gint64 pos_ns, gdouble rate,
                                GstSeekFlags mode_flags) {
  if (!p->pipeline) {
    return (gboolean)0;
  }
  if (!gstp_seek_to_ns_flags(p->pipeline, rate, pos_ns, mode_flags)) {
    return (gboolean)0;
  }
  return gstp_wait_seek_completed(p->pipeline);
}

static void gstp_begin_scrub_hold(GstpPlayer *p, int64_t target_ms) {
  if (target_ms < 0) {
    target_ms = 0;
  }
  p->scrub_hold_target_ms = target_ms;
  p->scrub_hold_until_us = g_get_monotonic_time() + 5 * G_USEC_PER_SEC;
  p->position_ms = target_ms;
  p->last_frame_pts_ms = -1;
  p->at_eos = false;
  gstp_media_sync_wall_clock(p);
}

static gboolean gstp_flush_seek_with_ready_fallback(GstpPlayer *p, gint64 pos_ns,
                                                    gdouble rate,
                                                    GstSeekFlags mode_flags,
                                                    gint64 tolerance_ns) {
  if (gstp_flush_seek(p, pos_ns, rate, mode_flags)) {
    return (gboolean)1;
  }
  /* qtdemux / avidemux keep demuxer EOS until the pipeline drops to READY. */
  if (!gstp_set_pipeline_state_and_wait(p->pipeline, GST_STATE_READY)) {
    return (gboolean)0;
  }
  if (!gstp_set_pipeline_state_and_wait(p->pipeline, GST_STATE_PAUSED)) {
    return (gboolean)0;
  }
  if (gstp_flush_seek(p, pos_ns, rate, mode_flags)) {
    return (gboolean)1;
  }
  if (tolerance_ns > 0) {
    return gstp_flush_seek_verified(p, pos_ns, rate, mode_flags, tolerance_ns);
  }
  return (gboolean)0;
}

static void gstp_emit_rewind_position(GstpPlayer *p) {
  p->position_ms = 0;
  p->last_frame_pts_ms = -1;
  p->at_eos = false;
  p->play_position_origin_ms = 0;
  p->play_wall_origin_us = g_get_monotonic_time();
  if (!p->suppress_timing_emit) {
    gstp_player_emit(p, GSTP_EVENT_POSITION_CHANGED, "");
  }
}

static int32_t gstp_media_rewind_ready_reload(GstpPlayer *p) {
  if (!p->pipeline) {
    return GSTP_ERR_NOT_READY;
  }
  const gdouble rate = p->speed > 0.0 ? p->speed : 1.0;

  if (!gstp_set_pipeline_state_and_wait(p->pipeline, GST_STATE_READY)) {
    return GSTP_ERR_FAIL;
  }
  p->at_eos = false;

  if (p->media_uri[0] != '\0') {
    g_object_set(p->pipeline, "uri", p->media_uri, NULL);
  }

  if (!gstp_set_pipeline_state_and_wait(p->pipeline, GST_STATE_PAUSED)) {
    return GSTP_ERR_FAIL;
  }

  if (!gstp_flush_seek_verified(p, 0, rate, GST_SEEK_FLAG_KEY_UNIT,
                                (gint64)GST_SECOND)) {
    return GSTP_ERR_FAIL;
  }

  gstp_emit_rewind_position(p);
  return GSTP_ERR_OK;
}

void gstp_replay_begin_resume(GstpPlayer *p) {
  if (!p->pipeline) {
    gstp_clear_replay_preroll(p);
    return;
  }

  p->desired_playing = true;
  (void)gst_element_set_state(p->pipeline, GST_STATE_PLAYING);

  if (!p->is_uri) {
    GstState cur = GST_STATE_NULL;
    (void)gst_element_get_state(p->pipeline, &cur, NULL, 5 * GST_SECOND);
    p->buffering_percent = 100;
    gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
    if (cur == GST_STATE_PLAYING) {
      gstp_clear_replay_preroll(p);
      gstp_media_sync_wall_clock(p);
      gstp_player_set_state(p, GSTP_STATE_PLAYING);
    }
  }
}

int32_t gstp_media_rewind(GstpPlayer *p) {
  if (!p->pipeline) {
    return GSTP_ERR_NOT_READY;
  }

  gstp_clear_replay_preroll(p);
  p->replay_preroll = true;
  p->replay_preroll_since_us = g_get_monotonic_time();
  p->buffering_percent = 0;
  gstp_player_set_state(p, GSTP_STATE_BUFFERING);
  gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");

  const gdouble rate = p->speed > 0.0 ? p->speed : 1.0;

  GstState cur = GST_STATE_NULL;
  (void)gst_element_get_state(p->pipeline, &cur, NULL, 0);
  if (cur != GST_STATE_PAUSED) {
    if (!gstp_set_pipeline_state_and_wait(p->pipeline, GST_STATE_PAUSED)) {
      gstp_clear_replay_preroll(p);
      return GSTP_ERR_FAIL;
    }
  }

  if (!gstp_flush_seek_with_ready_fallback(p, 0, rate, GST_SEEK_FLAG_KEY_UNIT,
                                           (gint64)GST_SECOND)) {
    if (gstp_media_rewind_ready_reload(p) != GSTP_ERR_OK) {
      gstp_clear_replay_preroll(p);
      return GSTP_ERR_FAIL;
    }
  } else {
    gstp_emit_rewind_position(p);
  }

  if (p->is_uri) {
    p->buffering_percent = 0;
    gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
  } else {
    p->buffering_percent = 100;
    gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
  }
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_seek_at(GstpPlayer *p, int64_t position_ms, bool accurate) {
  if (!p->pipeline) {
    return GSTP_ERR_NOT_READY;
  }
  (void)accurate;

  const gdouble rate = p->speed > 0 ? p->speed : 1.0;
  gint64 pos_ns = (gint64)position_ms * GST_MSECOND;
  if (pos_ns < 0) {
    pos_ns = 0;
  }

  GstState pre_seek = GST_STATE_NULL;
  (void)gst_element_get_state(p->pipeline, &pre_seek, NULL, 0);
  const bool was_playing = pre_seek == GST_STATE_PLAYING;
  const bool resume_playing = p->desired_playing || was_playing;

  /* qtdemux/avidemux (MOV/AVI) are more reliable when paused for the seek. */
  if (was_playing) {
    (void)gst_element_set_state(p->pipeline, GST_STATE_PAUSED);
    (void)gst_element_get_state(p->pipeline, NULL, NULL, 2 * GST_SECOND);
  }

  /* Prefer ACCURATE; fall back to KEY_UNIT. Do not require a post-seek position
   * query to land within a tight window — MOV/AVI often report stale timing. */
  gboolean ok = gstp_flush_seek(p, pos_ns, rate, GST_SEEK_FLAG_ACCURATE);
  if (!ok) {
    ok = gstp_flush_seek_with_ready_fallback(p, pos_ns, rate,
                                             GST_SEEK_FLAG_ACCURATE,
                                             (gint64)GST_SECOND);
  }
  if (!ok) {
    ok = gstp_flush_seek(p, pos_ns, rate, GST_SEEK_FLAG_KEY_UNIT);
    if (!ok) {
      ok = gstp_flush_seek_with_ready_fallback(p, pos_ns, rate,
                                               GST_SEEK_FLAG_KEY_UNIT,
                                               (gint64)GST_SECOND);
    }
  }
  if (!ok) {
    if (was_playing && p->desired_playing) {
      (void)gst_element_set_state(p->pipeline, GST_STATE_PLAYING);
    }
    return GSTP_ERR_FAIL;
  }

  gstp_begin_scrub_hold(p, position_ms);
  p->buffering_percent = 100;
  gstp_pipeline_update_seekable(p);
  if (!p->suppress_timing_emit) {
    gstp_player_emit(p, GSTP_EVENT_POSITION_CHANGED, "");
  }
  gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");

  if (resume_playing) {
    p->desired_playing = true;
    (void)gst_element_set_state(p->pipeline, GST_STATE_PLAYING);
    gstp_media_sync_wall_clock(p);
    gstp_player_set_state(p, GSTP_STATE_PLAYING);
  } else if (p->player_state == GSTP_STATE_BUFFERING ||
             p->player_state == GSTP_STATE_COMPLETED) {
    gstp_player_set_state(p, GSTP_STATE_PAUSED);
  }
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_play(GstpPlayer *p) {
  if (!p->pipeline) {
    return GSTP_ERR_NOT_READY;
  }
  /* Manual replay after EOS must restart from the beginning (looping already
   * seeks on EOS; play() alone would resume near the end). */
  const bool near_end =
      p->duration_ms > 0 && p->position_ms >= p->duration_ms - 50;
  const bool restart = p->at_eos || near_end ||
                       p->player_state == GSTP_STATE_COMPLETED;

  if (restart) {
    p->speed = 1.0;
    const int32_t rewind_rc = gstp_media_rewind(p);
    if (rewind_rc != GSTP_ERR_OK) {
      p->replay_preroll = false;
      p->replay_preroll_since_us = 0;
      return rewind_rc;
    }
    p->desired_playing = true;
    p->at_eos = false;
#if defined(__ANDROID__)
    if (p->android_window != 0 && !p->android_overlay_bound) {
      gstp_android_apply_overlay(p);
    }
    if (p->android_window == 0) {
      p->pending_auto_play = true;
      return GSTP_ERR_OK;
    }
#endif
    if (p->speed != 1.0 && p->speed > 0) {
      (void)gstp_pipeline_apply_rate(p);
    }
    gstp_replay_begin_resume(p);
    return GSTP_ERR_OK;
  }

  p->desired_playing = true;
  p->at_eos = false;
#if defined(__ANDROID__)
  if (p->android_window != 0 && !p->android_overlay_bound) {
    gstp_android_apply_overlay(p);
  }
  /* No ANativeWindow → glimagesink blocks the whole playbin (including audio). */
  if (p->android_window == 0) {
    p->pending_auto_play = true;
    return GSTP_ERR_OK;
  }
#endif
  if (p->speed != 1.0 && p->speed > 0) {
    (void)gstp_pipeline_apply_rate(p);
  }
  int32_t rc = gstp_pipeline_set_state_sync(p, GST_STATE_PLAYING);
  if (rc == GSTP_ERR_OK) {
    gstp_media_sync_wall_clock(p);
    gstp_player_set_state(p, GSTP_STATE_PLAYING);
  }
  return rc;
}

int32_t gstp_pipeline_pause(GstpPlayer *p) {
  gstp_media_update_timing(p);
  p->desired_playing = false;
  p->pending_auto_play = false;
  int32_t rc = gstp_pipeline_set_state_sync(p, GST_STATE_PAUSED);
  if (rc == GSTP_ERR_OK) {
    gstp_player_set_state(p, GSTP_STATE_PAUSED);
  }
  return rc;
}

int32_t gstp_pipeline_stop(GstpPlayer *p) {
  p->desired_playing = false;
  p->pending_auto_play = false;
  int32_t rc = gstp_pipeline_set_state_sync(p, GST_STATE_NULL);
  if (rc == GSTP_ERR_OK) {
    p->position_ms = 0;
    gstp_player_set_state(p, GSTP_STATE_STOPPED);
  }
  return rc;
}

int32_t gstp_pipeline_set_volume(GstpPlayer *p, double volume) {
  p->volume = volume < 0 ? 0 : (volume > 1 ? 1 : volume);
  if (p->pipeline) {
    g_object_set(p->pipeline, "volume", p->volume, NULL);
  }
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_set_mute(GstpPlayer *p, bool mute) {
  p->muted = mute;
  if (p->pipeline) {
    g_object_set(p->pipeline, "mute", mute, NULL);
  }
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_apply_rate(GstpPlayer *p) {
  if (!p->pipeline) {
    return GSTP_ERR_NOT_READY;
  }
  double speed = p->speed > 0 ? p->speed : 1.0;

  /* Flushing rate seek with an explicit start position. Do not use
   * SEEK_TYPE_NONE+FLUSH (playbin3 can return TRUE while landing at EOS) or
   * INSTANT_RATE_CHANGE (can leave videoconvert/appsink with wrong colors). */
  gint64 pos = GST_CLOCK_TIME_NONE;
  if (!gst_element_query_position(p->pipeline, GST_FORMAT_TIME, &pos) ||
      !GST_CLOCK_TIME_IS_VALID(pos)) {
    pos = (gint64)p->position_ms * GST_MSECOND;
  }
  gboolean ok = gst_element_seek(
      p->pipeline, speed, GST_FORMAT_TIME,
      (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT),
      GST_SEEK_TYPE_SET, pos, GST_SEEK_TYPE_NONE, GST_CLOCK_TIME_NONE);
  if (!ok) {
    return GSTP_ERR_FAIL;
  }

  gint64 after = GST_CLOCK_TIME_NONE;
  if (gst_element_query_position(p->pipeline, GST_FORMAT_TIME, &after) &&
      GST_CLOCK_TIME_IS_VALID(after)) {
    p->position_ms = (int64_t)(after / GST_MSECOND);
  } else {
    p->position_ms = (int64_t)(pos / GST_MSECOND);
  }
  p->at_eos = false;
  gstp_player_emit(p, GSTP_EVENT_POSITION_CHANGED, "");
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_set_speed(GstpPlayer *p, double speed) {
  if (speed <= 0) {
    speed = 1.0;
  }
  p->speed = speed;
  if (!p->pipeline) {
    p->pending_rate_seek = false;
    return GSTP_ERR_OK;
  }
  /* Avoid fighting the buffering pause/resume loop with a mid-rebuffer seek. */
  if (p->buffering_percent < 100) {
    p->pending_rate_seek = true;
    return GSTP_ERR_OK;
  }
  p->pending_rate_seek = false;
  return gstp_pipeline_apply_rate(p);
}

void gstp_pipeline_refresh_tracks(GstpPlayer *p) {
  p->track_count = 0;
  if (!p->pipeline) {
    return;
  }

  /* playbin3: prefer GstStreamCollection (no n-audio / current-audio). */
  if (p->stream_collection) {
    guint n = gst_stream_collection_get_size(p->stream_collection);
    for (guint i = 0; i < n && p->track_count < GSTP_MAX_TRACKS; i++) {
      GstStream *stream =
          gst_stream_collection_get_stream(p->stream_collection, i);
      if (!stream) {
        continue;
      }
      GstStreamType stype = gst_stream_get_stream_type(stream);
      int32_t track_type = -1;
      const char *prefix = NULL;
      if (stype & GST_STREAM_TYPE_AUDIO) {
        track_type = GSTP_TRACK_AUDIO;
        prefix = "Audio";
      } else if (stype & GST_STREAM_TYPE_VIDEO) {
        track_type = GSTP_TRACK_VIDEO;
        prefix = "Video";
      } else if (stype & GST_STREAM_TYPE_TEXT) {
        track_type = GSTP_TRACK_SUBTITLE;
        prefix = "Subtitle";
      } else {
        continue;
      }

      GstpTrackInfo *t = &p->tracks[p->track_count];
      t->id = (int32_t)p->track_count;
      t->type = track_type;
      t->selected = false;
      t->language[0] = '\0';
      t->stream_id[0] = '\0';
      snprintf(t->label, sizeof(t->label), "%s %d", prefix, t->id);
      {
        const gchar *sid = gst_stream_get_stream_id(stream);
        if (sid) {
          strncpy(t->stream_id, sid, sizeof(t->stream_id) - 1);
          t->stream_id[sizeof(t->stream_id) - 1] = '\0';
        }
      }

      GstCaps *caps = gst_stream_get_caps(stream);
      if (caps && !gst_caps_is_empty(caps)) {
        const GstStructure *s = gst_caps_get_structure(caps, 0);
        const gchar *lang = gst_structure_get_string(s, "language");
        if (!lang) {
          lang = gst_structure_get_string(s, "lang");
        }
        if (lang) {
          strncpy(t->language, lang, sizeof(t->language) - 1);
          t->language[sizeof(t->language) - 1] = '\0';
        }
      }
      if (caps) {
        gst_caps_unref(caps);
      }
      GstTagList *tags = gst_stream_get_tags(stream);
      if (tags) {
        gchar *lang = NULL;
        if (gst_tag_list_get_string(tags, GST_TAG_LANGUAGE_CODE, &lang) &&
            lang) {
          strncpy(t->language, lang, sizeof(t->language) - 1);
          t->language[sizeof(t->language) - 1] = '\0';
          g_free(lang);
        }
        gst_tag_list_unref(tags);
      }
      p->track_count++;
    }
    return;
  }

  /* playbin2 fallback: only query when the property exists. */
  GObjectClass *klass = G_OBJECT_GET_CLASS(p->pipeline);
  if (!g_object_class_find_property(klass, "n-audio")) {
    return;
  }

  gint n_audio = 0, n_video = 0, n_text = 0;
  g_object_get(p->pipeline, "n-audio", &n_audio, "n-video", &n_video, "n-text",
               &n_text, NULL);
  gint cur_audio = -1, cur_video = -1, cur_text = -1;
  g_object_get(p->pipeline, "current-audio", &cur_audio, "current-video",
               &cur_video, "current-text", &cur_text, NULL);

  for (gint i = 0; i < n_audio && p->track_count < GSTP_MAX_TRACKS; i++) {
    GstpTrackInfo *t = &p->tracks[p->track_count++];
    t->id = i;
    t->type = GSTP_TRACK_AUDIO;
    snprintf(t->label, sizeof(t->label), "Audio %d", i);
    t->language[0] = '\0';
    t->stream_id[0] = '\0';
    t->selected = (i == cur_audio);
  }
  for (gint i = 0; i < n_video && p->track_count < GSTP_MAX_TRACKS; i++) {
    GstpTrackInfo *t = &p->tracks[p->track_count++];
    t->id = i;
    t->type = GSTP_TRACK_VIDEO;
    snprintf(t->label, sizeof(t->label), "Video %d", i);
    t->language[0] = '\0';
    t->stream_id[0] = '\0';
    t->selected = (i == cur_video);
  }
  for (gint i = 0; i < n_text && p->track_count < GSTP_MAX_TRACKS; i++) {
    GstpTrackInfo *t = &p->tracks[p->track_count++];
    t->id = i;
    t->type = GSTP_TRACK_SUBTITLE;
    snprintf(t->label, sizeof(t->label), "Subtitle %d", i);
    t->language[0] = '\0';
    t->stream_id[0] = '\0';
    t->selected = (i == cur_text);
  }
}

void gstp_pipeline_apply_streams_selected(GstpPlayer *p, GstMessage *msg) {
  if (!p || !msg) {
    return;
  }
  for (int i = 0; i < p->track_count; i++) {
    p->tracks[i].selected = false;
  }
  guint n = gst_message_streams_selected_get_size(msg);
  for (guint i = 0; i < n; i++) {
    GstStream *stream = gst_message_streams_selected_get_stream(msg, i);
    if (!stream) {
      continue;
    }
    const gchar *sid = gst_stream_get_stream_id(stream);
    if (!sid) {
      continue;
    }
    for (int t = 0; t < p->track_count; t++) {
      if (p->tracks[t].stream_id[0] != '\0' &&
          strcmp(p->tracks[t].stream_id, sid) == 0) {
        p->tracks[t].selected = true;
        break;
      }
    }
  }
}

void gstp_pipeline_update_seekable(GstpPlayer *p) {
  if (!p || !p->pipeline) {
    return;
  }
  GstQuery *query = gst_query_new_seeking(GST_FORMAT_TIME);
  if (!query) {
    return;
  }
  if (gst_element_query(p->pipeline, query)) {
    gboolean seekable = FALSE;
    gst_query_parse_seeking(query, NULL, &seekable, NULL, NULL);
    /* AVI/MOV over HTTP often report non-seekable until fully buffered, even
     * when byte-range seeks work once duration is known. */
    if (!seekable && p->is_uri && p->duration_ms > 0) {
      seekable = TRUE;
    }
    p->seekable = seekable ? true : false;
  }
  gst_query_unref(query);
}

static int32_t gstp_stream_type_to_track(GstStreamType stype) {
  if (stype & GST_STREAM_TYPE_AUDIO) {
    return GSTP_TRACK_AUDIO;
  }
  if (stype & GST_STREAM_TYPE_VIDEO) {
    return GSTP_TRACK_VIDEO;
  }
  if (stype & GST_STREAM_TYPE_TEXT) {
    return GSTP_TRACK_SUBTITLE;
  }
  return -1;
}

int32_t gstp_pipeline_select_track(GstpPlayer *p, int32_t track_id,
                                   int32_t track_type, bool enable) {
  if (!p->pipeline) {
    return GSTP_ERR_FAIL;
  }
  if (!enable) {
    return GSTP_ERR_OK;
  }

  /* playbin3: select by stream-id from the cached collection. */
  if (p->stream_collection) {
    if (track_id < 0 || track_id >= p->track_count) {
      return GSTP_ERR_FAIL;
    }
    guint n = gst_stream_collection_get_size(p->stream_collection);
    GList *ids = NULL;
    gboolean have_audio = FALSE, have_video = FALSE, have_text = FALSE;
    gint mapped = -1;
    for (guint i = 0; i < n; i++) {
      GstStream *stream =
          gst_stream_collection_get_stream(p->stream_collection, i);
      if (!stream) {
        continue;
      }
      int32_t tt = gstp_stream_type_to_track(gst_stream_get_stream_type(stream));
      if (tt < 0) {
        continue;
      }
      mapped++;
      const gchar *sid = gst_stream_get_stream_id(stream);
      if (!sid) {
        continue;
      }
      if (tt == track_type) {
        if (mapped == track_id) {
          ids = g_list_append(ids, g_strdup(sid));
          if (tt == GSTP_TRACK_AUDIO) {
            have_audio = TRUE;
          } else if (tt == GSTP_TRACK_VIDEO) {
            have_video = TRUE;
          } else {
            have_text = TRUE;
          }
        }
        continue;
      }
      if (tt == GSTP_TRACK_AUDIO && !have_audio) {
        ids = g_list_append(ids, g_strdup(sid));
        have_audio = TRUE;
      } else if (tt == GSTP_TRACK_VIDEO && !have_video) {
        ids = g_list_append(ids, g_strdup(sid));
        have_video = TRUE;
      } else if (tt == GSTP_TRACK_SUBTITLE && !have_text) {
        ids = g_list_append(ids, g_strdup(sid));
        have_text = TRUE;
      }
    }
    if (!ids) {
      return GSTP_ERR_FAIL;
    }
    gboolean ok =
        gst_element_send_event(p->pipeline, gst_event_new_select_streams(ids));
    g_list_free_full(ids, g_free);
    if (!ok) {
      return GSTP_ERR_FAIL;
    }
    for (int i = 0; i < p->track_count; i++) {
      if (p->tracks[i].type == track_type) {
        p->tracks[i].selected = (p->tracks[i].id == track_id);
      }
    }
    gstp_player_emit(p, GSTP_EVENT_TRACKS_CHANGED, "");
    return GSTP_ERR_OK;
  }

  GObjectClass *klass = G_OBJECT_GET_CLASS(p->pipeline);
  if (!g_object_class_find_property(klass, "current-audio")) {
    return GSTP_ERR_FAIL;
  }
  switch (track_type) {
  case GSTP_TRACK_AUDIO:
    g_object_set(p->pipeline, "current-audio", track_id, NULL);
    break;
  case GSTP_TRACK_VIDEO:
    g_object_set(p->pipeline, "current-video", track_id, NULL);
    break;
  case GSTP_TRACK_SUBTITLE:
    g_object_set(p->pipeline, "current-text", track_id, NULL);
    break;
  default:
    return GSTP_ERR_FAIL;
  }
  gstp_pipeline_refresh_tracks(p);
  gstp_player_emit(p, GSTP_EVENT_TRACKS_CHANGED, "");
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_set_rotation(GstpPlayer *p, int32_t degrees) {
  if (degrees != 0 && degrees != 90 && degrees != 180 && degrees != 270) {
    return GSTP_ERR_FAIL;
  }
  const int32_t prev = p->rotate_degrees;
  p->rotate_degrees = degrees;
  gstp_apply_orient_element(p->orient_element, degrees);

  /* Eagerly swap layout metadata for 90/270 so Dart letterboxes before the
   * next post-orient caps/frame (videoflip / glvideoflip swap axes). */
  const bool prev_swap = (prev == 90 || prev == 270);
  const bool next_swap = (degrees == 90 || degrees == 270);
  if (prev_swap != next_swap && p->width > 0 && p->height > 0) {
    int32_t tmp = p->width;
    p->width = p->height;
    p->height = tmp;
    if (p->dar_n > 0 && p->dar_d > 0) {
      tmp = p->dar_n;
      p->dar_n = p->dar_d;
      p->dar_d = tmp;
    } else {
      p->dar_n = p->width;
      p->dar_d = p->height;
    }
    gstp_player_emit(p, GSTP_EVENT_VIDEO_SIZE, "");
    gstp_player_emit(p, GSTP_EVENT_METADATA_CHANGED, "");
  }
  return GSTP_ERR_OK;
}

int32_t gstp_pipeline_set_aspect(GstpPlayer *p, int32_t mode) {
  if (mode < 0 || mode > 2) {
    return GSTP_ERR_FAIL;
  }
  /* Stored for API compatibility. Layout (fit/fill/stretch) is owned by Dart
   * FittedBox; Android glimagesink keeps force-aspect-ratio=false. */
  p->aspect_mode = mode;
  return GSTP_ERR_OK;
}
