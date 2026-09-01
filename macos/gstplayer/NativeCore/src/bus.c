#include "gstp_internal.h"

#include <stdio.h>
#include <string.h>

static int32_t map_gst_state(GstpPlayer *p, GstState state) {
  switch (state) {
  case GST_STATE_NULL:
    return GSTP_STATE_STOPPED;
  case GST_STATE_READY:
    /* Intermediate READY during play/buffer must not clobber playing/buffering. */
    if (p->player_state == GSTP_STATE_PLAYING ||
        p->player_state == GSTP_STATE_BUFFERING ||
        p->player_state == GSTP_STATE_PAUSED) {
      return p->player_state;
    }
    if (p->player_state == GSTP_STATE_COMPLETED && p->desired_playing) {
      return GSTP_STATE_PLAYING;
    }
    return GSTP_STATE_READY;
  case GST_STATE_PAUSED:
    /* playbin pauses itself while download-buffering; keep BUFFERING visible. */
    if (p->is_uri && p->buffering_percent < 100 && p->desired_playing) {
      return GSTP_STATE_BUFFERING;
    }
    if (p->is_uri && p->player_state == GSTP_STATE_BUFFERING) {
      return GSTP_STATE_BUFFERING;
    }
    return GSTP_STATE_PAUSED;
  case GST_STATE_PLAYING:
    if (p->is_uri && p->buffering_percent < 100 && p->desired_playing) {
      return GSTP_STATE_BUFFERING;
    }
    return GSTP_STATE_PLAYING;
  default:
    return GSTP_STATE_IDLE;
  }
}

static gboolean gstp_query_position_on_element(GstElement *element,
                                               gint64 *pos) {
  if (!element) {
    return (gboolean)0;
  }
  gint64 value = GST_CLOCK_TIME_NONE;
  if (gst_element_query_position(element, GST_FORMAT_TIME, &value) &&
      GST_CLOCK_TIME_IS_VALID(value)) {
    *pos = value;
    return (gboolean)1;
  }
  return (gboolean)0;
}

static gboolean gstp_query_duration_on_element(GstElement *element,
                                               gint64 *dur) {
  if (!element) {
    return (gboolean)0;
  }
  gint64 value = GST_CLOCK_TIME_NONE;
  if (gst_element_query_duration(element, GST_FORMAT_TIME, &value) &&
      GST_CLOCK_TIME_IS_VALID(value)) {
    *dur = value;
    return (gboolean)1;
  }
  return (gboolean)0;
}

static GstElement *gstp_find_child_by_factory(GstpPlayer *p,
                                              const char *factory_name) {
  if (!p->pipeline || !GST_IS_BIN(p->pipeline) || !factory_name) {
    return NULL;
  }
  GstIterator *it = gst_bin_iterate_recurse(GST_BIN(p->pipeline));
  if (!it) {
    return NULL;
  }
  GstElement *found = NULL;
  GValue item = G_VALUE_INIT;
  GstIteratorResult res;
  while ((res = gst_iterator_next(it, &item)) == GST_ITERATOR_OK) {
    GstElement *element = GST_ELEMENT(g_value_get_object(&item));
    GstElementFactory *factory =
        element ? gst_element_get_factory(element) : NULL;
    if (factory) {
      const gchar *fname =
          gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
      if (strcmp(fname, factory_name) == 0) {
        found = element;
        gst_object_ref(found);
        g_value_reset(&item);
        break;
      }
    }
    g_value_reset(&item);
  }
  g_value_unset(&item);
  gst_iterator_free(it);
  return found;
}

static GstElement *gstp_get_playsink(GstpPlayer *p) {
  GstElement *playsink = gstp_find_child_by_factory(p, "playsink");
  if (playsink) {
    return playsink;
  }
  if (!p->pipeline) {
    return NULL;
  }
  GObjectClass *klass = G_OBJECT_GET_CLASS(p->pipeline);
  if (!g_object_class_find_property(klass, "sink")) {
    return NULL;
  }
  GstElement *sink = NULL;
  g_object_get(p->pipeline, "sink", &sink, NULL);
  return sink;
}

gboolean gstp_query_position_on_playsink(GstpPlayer *p, gint64 *pos) {
  GstElement *sink = gstp_get_playsink(p);
  gboolean ok = gstp_query_position_on_element(sink, pos);
  if (sink) {
    gst_object_unref(sink);
  }
  return ok;
}

static gboolean gstp_query_duration_on_playsink(GstpPlayer *p, gint64 *dur) {
  GstElement *sink = gstp_get_playsink(p);
  gboolean ok = gstp_query_duration_on_element(sink, dur);
  if (sink) {
    gst_object_unref(sink);
  }
  return ok;
}

static gboolean gstp_duration_ns_sane(gint64 dur) {
  if (!GST_CLOCK_TIME_IS_VALID(dur) || dur <= 0) {
    return (gboolean)0;
  }
  const gint64 max = (gint64)(7LL * 24 * 3600 * GST_SECOND);
  return dur <= max ? (gboolean)1 : (gboolean)0;
}

static gboolean gstp_position_ms_sane(const GstpPlayer *p, int64_t ms) {
  if (ms < 0) {
    return (gboolean)0;
  }
  const int64_t max_abs = (int64_t)(7LL * 24 * 3600 * 1000);
  if (ms > max_abs) {
    return (gboolean)0;
  }
  /* Before duration is known, playbin may report bogus preroll timestamps
   * (notably network MOV). Allow monotonic playback advance; reject spikes. */
  if (p->duration_ms <= 0 && ms > 60000) {
    if (p->position_ms <= 0 || ms > p->position_ms + 15000) {
      return (gboolean)0;
    }
  }
  if (p->duration_ms > 0) {
    const int64_t slack = p->duration_ms / 20 + 500;
    if (ms > p->duration_ms + slack) {
      return (gboolean)0;
    }
  }
  return (gboolean)1;
}

static int64_t gstp_clamp_position_ms(GstpPlayer *p, int64_t ms) {
  if (!gstp_position_ms_sane(p, ms)) {
    if (p->duration_ms > 0) {
      return ms < 0 ? 0 : p->duration_ms;
    }
    return ms < 0 ? 0 : 0;
  }
  if (p->duration_ms > 0 && ms > p->duration_ms) {
    return p->duration_ms;
  }
  return ms < 0 ? 0 : ms;
}

void gstp_media_set_position_ms(GstpPlayer *p, int64_t position_ms) {
  if (!p) {
    return;
  }
  const int64_t ms = gstp_clamp_position_ms(p, position_ms);
  if (p->scrub_hold_until_us > 0 &&
      g_get_monotonic_time() < p->scrub_hold_until_us) {
    const int64_t delta = ms > p->scrub_hold_target_ms
                              ? ms - p->scrub_hold_target_ms
                              : p->scrub_hold_target_ms - ms;
    if (delta > 3000) {
      return;
    }
    p->scrub_hold_until_us = 0;
  }
  if (ms == p->position_ms) {
    return;
  }
  p->position_ms = ms;
  gstp_media_sync_wall_clock(p);
  if (p->suppress_timing_emit) {
    return;
  }
  gstp_player_emit(p, GSTP_EVENT_POSITION_CHANGED, "");
}

void gstp_media_set_duration_ms(GstpPlayer *p, int64_t duration_ms) {
  if (!p || duration_ms <= 0 || duration_ms == p->duration_ms) {
    return;
  }
  p->duration_ms = duration_ms;
  if (p->is_uri && p->pipeline) {
    gstp_pipeline_update_seekable(p);
  }
  gstp_player_emit(p, GSTP_EVENT_DURATION_CHANGED, "");
}

static gboolean gstp_pick_stream_duration(GstpPlayer *p, gint64 *dur) {
  gint64 candidate = GST_CLOCK_TIME_NONE;
  if (gstp_query_duration_on_element(p->pipeline, &candidate) &&
      gstp_duration_ns_sane(candidate)) {
    *dur = candidate;
    return (gboolean)1;
  }
  if (gstp_query_duration_on_playsink(p, &candidate) &&
      gstp_duration_ns_sane(candidate)) {
    *dur = candidate;
    return (gboolean)1;
  }
  if (p->tag_duration_ms > 0) {
    *dur = p->tag_duration_ms * GST_MSECOND;
    return (gboolean)1;
  }
  return (gboolean)0;
}

static gboolean gstp_query_stream_duration(GstpPlayer *p, gint64 *dur) {
  return gstp_pick_stream_duration(p, dur);
}

static gboolean gstp_query_position_from_clock(GstpPlayer *p, gint64 *pos) {
  if (!p->pipeline) {
    return (gboolean)0;
  }
  GstState state = GST_STATE_NULL;
  gst_element_get_state(p->pipeline, &state, NULL, 0);
  if (state != GST_STATE_PLAYING) {
    return (gboolean)0;
  }
  GstClock *clock = gst_element_get_clock(p->pipeline);
  if (!clock) {
    return (gboolean)0;
  }
  GstClockTime base = gst_element_get_base_time(p->pipeline);
  GstClockTime now = gst_clock_get_time(clock);
  gst_object_unref(clock);
  if (!GST_CLOCK_TIME_IS_VALID(now) || !GST_CLOCK_TIME_IS_VALID(base) ||
      now < base) {
    return (gboolean)0;
  }
  *pos = now - base;
  return (gboolean)1;
}

static gboolean gstp_query_position_from_wall_clock(GstpPlayer *p, gint64 *pos) {
  if (!p->pipeline || !p->desired_playing) {
    return (gboolean)0;
  }
  /* Do not extrapolate ahead of the first decoded frame at stream start. */
  if (p->last_frame_pts_ms < 0 && p->position_ms <= 0) {
    return (gboolean)0;
  }
  GstState state = GST_STATE_NULL;
  gst_element_get_state(p->pipeline, &state, NULL, 0);
  if (state != GST_STATE_PLAYING) {
    return (gboolean)0;
  }
  int64_t elapsed_ms = (g_get_monotonic_time() - p->play_wall_origin_us) / 1000;
  double rate = p->speed > 0.0 ? p->speed : 1.0;
  int64_t ms =
      p->play_position_origin_ms + (int64_t)(elapsed_ms * rate + 0.5);
  if (ms < 0) {
    ms = 0;
  }
  *pos = ms * GST_MSECOND;
  return (gboolean)1;
}

static int64_t gstp_pick_display_position_ms(GstpPlayer *p) {
  const gint64 now = g_get_monotonic_time();
  if (p->scrub_hold_until_us > 0 && now < p->scrub_hold_until_us) {
    return p->scrub_hold_target_ms;
  }

  const bool have_pts = p->last_frame_pts_ms >= 0 &&
                        gstp_position_ms_sane(p, p->last_frame_pts_ms);
  if (have_pts) {
    return p->last_frame_pts_ms;
  }

  gint64 pos = GST_CLOCK_TIME_NONE;
  if (gstp_query_position_on_playsink(p, &pos)) {
    const int64_t ms = (int64_t)(pos / GST_MSECOND);
    if (gstp_position_ms_sane(p, ms)) {
      return ms;
    }
  }
  pos = GST_CLOCK_TIME_NONE;
  if (gstp_query_position_on_element(p->pipeline, &pos)) {
    const int64_t ms = (int64_t)(pos / GST_MSECOND);
    if (gstp_position_ms_sane(p, ms)) {
      return ms;
    }
  }
#if !defined(__ANDROID__)
  pos = GST_CLOCK_TIME_NONE;
  if (p->appsink && gstp_query_position_on_element(p->appsink, &pos)) {
    const int64_t ms = (int64_t)(pos / GST_MSECOND);
    if (gstp_position_ms_sane(p, ms)) {
      return ms;
    }
  }
#endif
  gint64 wall_ns = GST_CLOCK_TIME_NONE;
  if (gstp_query_position_from_wall_clock(p, &wall_ns) &&
      GST_CLOCK_TIME_IS_VALID(wall_ns)) {
    const int64_t ms = (int64_t)(wall_ns / GST_MSECOND);
    if (gstp_position_ms_sane(p, ms)) {
      return ms;
    }
  }
  pos = GST_CLOCK_TIME_NONE;
  if (gstp_query_position_from_clock(p, &pos)) {
    const int64_t ms = (int64_t)(pos / GST_MSECOND);
    if (gstp_position_ms_sane(p, ms)) {
      return ms;
    }
  }
  return (int64_t)-1;
}

static gboolean gstp_query_stream_position(GstpPlayer *p, gint64 *pos) {
  const int64_t ms = gstp_pick_display_position_ms(p);
  if (ms < 0) {
    return (gboolean)0;
  }
  *pos = ms * GST_MSECOND;
  return (gboolean)1;
}

void gstp_media_sync_wall_clock(GstpPlayer *p) {
  if (!p) {
    return;
  }
  p->play_wall_origin_us = g_get_monotonic_time();
  p->play_position_origin_ms = p->position_ms;
}

void gstp_media_note_frame_pts(GstpPlayer *p, GstClockTime pts) {
  if (!p || !GST_CLOCK_TIME_IS_VALID(pts)) {
    return;
  }
  const int64_t ms = (int64_t)(pts / GST_MSECOND);
  if (p->scrub_hold_until_us > 0 &&
      g_get_monotonic_time() < p->scrub_hold_until_us) {
    const int64_t delta = ms > p->scrub_hold_target_ms
                              ? ms - p->scrub_hold_target_ms
                              : p->scrub_hold_target_ms - ms;
    if (delta > 3000) {
      return;
    }
    p->scrub_hold_until_us = 0;
  } else if (p->position_ms > 1000 && ms + 1000 < p->position_ms) {
    return;
  }
  p->last_frame_pts_ms = ms;
  /* Do not touch position_ms here — that prevents position_tick from emitting.
   * Coalesce a safe emit onto the gstp-gst main context instead. */
  gstp_schedule_position_emit(p);
}

static gboolean gstp_position_emit_idle_cb(gpointer user_data) {
  GstpPlayer *p = user_data;
  p->position_emit_idle_id = 0;
  if (!p->suppress_timing_emit) {
    gstp_media_update_timing(p);
  }
  return G_SOURCE_REMOVE;
}

void gstp_schedule_position_emit(GstpPlayer *p) {
  if (!p || p->suppress_timing_emit) {
    return;
  }
  if (p->position_emit_idle_id != 0) {
    return;
  }
  GstpRuntime *rt = gstp_runtime();
  if (!rt->initialized || rt->ctx == NULL) {
    return;
  }
  GSource *source = g_idle_source_new();
  g_source_set_callback(source, gstp_position_emit_idle_cb, p, NULL);
  p->position_emit_idle_id = g_source_attach(source, rt->ctx);
  g_source_unref(source);
}

void gstp_media_update_timing(GstpPlayer *p) {
  if (!p || !p->pipeline) {
    return;
  }

  if (p->duration_ms <= 0) {
    gstp_ensure_demux_duration_probes(p);
  }

  gint64 pos = GST_CLOCK_TIME_NONE;
  if (gstp_query_stream_position(p, &pos) && GST_CLOCK_TIME_IS_VALID(pos)) {
    gstp_media_set_position_ms(p, (int64_t)(pos / GST_MSECOND));
  }

  gint64 dur = GST_CLOCK_TIME_NONE;
  if (gstp_query_stream_duration(p, &dur) && GST_CLOCK_TIME_IS_VALID(dur)) {
    gstp_media_set_duration_ms(p, (int64_t)(dur / GST_MSECOND));
  }
}

static gboolean gstp_position_tick(gpointer user_data) {
  GstpPlayer *p = user_data;
  if (!p->suppress_timing_emit) {
    gstp_media_update_timing(p);
  }
  return G_SOURCE_CONTINUE;
}

static gboolean gstp_bus_on_message(GstBus *bus, GstMessage *msg,
                                    gpointer user_data) {
  (void)bus;
  GstpPlayer *p = user_data;

  switch (GST_MESSAGE_TYPE(msg)) {
  case GST_MESSAGE_ERROR: {
    GError *err = NULL;
    gchar *dbg = NULL;
    gst_message_parse_error(msg, &err, &dbg);
    char buf[512];
    snprintf(buf, sizeof(buf), "%s", err ? err->message : "unknown error");
    if (err) {
      g_error_free(err);
    }
    g_free(dbg);
    /* Decodebin/MediaCodec autoplug often emits ERROR from child elements
     * while playbin recovers (e.g. HEVC probe → AVC). Only pipeline-level
     * errors are fatal to the Dart session. */
    if (!p->pipeline || GST_MESSAGE_SRC(msg) != GST_OBJECT(p->pipeline)) {
      strncpy(p->event_message, buf, sizeof(p->event_message) - 1);
      p->event_message[sizeof(p->event_message) - 1] = '\0';
      break;
    }
    gstp_player_set_state(p, GSTP_STATE_ERROR);
    gstp_player_emit(p, GSTP_EVENT_ERROR, buf);
    break;
  }
  case GST_MESSAGE_EOS:
    p->at_eos = true;
    gstp_media_update_timing(p);
    if (p->position_ms > 0 &&
        (p->duration_ms <= 0 || p->position_ms > p->duration_ms)) {
      gstp_media_set_duration_ms(p, p->position_ms);
    }
    /* App layer handles looping via open(); always emit EOS. */
    if (!p->looping) {
      p->desired_playing = false;
      p->pending_auto_play = false;
      p->replay_preroll = false;
      p->replay_preroll_since_us = 0;
      gstp_player_set_state(p, GSTP_STATE_COMPLETED);
    }
    gstp_player_emit(p, GSTP_EVENT_EOS, "");
    break;
  case GST_MESSAGE_STATE_CHANGED: {
    if (GST_MESSAGE_SRC(msg) != GST_OBJECT(p->pipeline)) {
      break;
    }
    GstState old_s, new_s, pending;
    gst_message_parse_state_changed(msg, &old_s, &new_s, &pending);
    (void)old_s;
    (void)pending;
    if (new_s == GST_STATE_PAUSED || new_s == GST_STATE_PLAYING) {
      gstp_pipeline_refresh_tracks(p);
      gstp_pipeline_update_seekable(p);
      if (new_s == GST_STATE_PLAYING) {
        p->suppress_timing_emit = false;
        if (p->replay_preroll &&
            (!p->is_uri || p->buffering_percent >= 100)) {
          p->replay_preroll = false;
          p->replay_preroll_since_us = 0;
          p->buffering_percent = 100;
          gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
        } else if (p->is_uri && p->buffering_percent < 100) {
          /* Playable without BUFFERING messages: complete the load bar. */
          p->buffering_percent = 100;
          gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
        }
        if (p->position_ms <= 0 && p->last_frame_pts_ms < 0) {
          p->position_ms = 0;
          p->play_position_origin_ms = 0;
          p->play_wall_origin_us = g_get_monotonic_time();
        } else {
          gstp_media_sync_wall_clock(p);
        }
      }
      if (!p->suppress_timing_emit) {
        gstp_media_update_timing(p);
      }
    }
    gstp_player_set_state(p, map_gst_state(p, new_s));
    break;
  }
  case GST_MESSAGE_BUFFERING: {
    gint percent = 0;
    gst_message_parse_buffering(msg, &percent);
    if (percent < 0) {
      percent = 0;
    } else if (percent > 100) {
      percent = 100;
    }
    /* Local/asset pipelines do not enable use-buffering; spurious 0–99%
     * messages after rewind would stick UI on loading forever. */
    if (!p->is_uri) {
      if (percent >= 100) {
        p->buffering_percent = 100;
        gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
      }
      break;
    }
    /* Initial download fill is non-monotonic for MOV/AVI (qtdemux/avidemux
     * consume the HTTP queue). Keep the high-water mark until 100%. */
    const bool regress = percent < 100 && p->buffering_percent < 100 &&
                         percent < p->buffering_percent;
    if (!regress) {
      p->buffering_percent = percent;
    }
    if (percent < 100) {
      /* Standard playbin network buffering: pause until cached, then resume. */
      if (p->desired_playing && p->pipeline) {
        gst_element_set_state(p->pipeline, GST_STATE_PAUSED);
      }
      gstp_player_set_state(p, GSTP_STATE_BUFFERING);
    } else if (p->desired_playing) {
      if (p->replay_preroll) {
        p->replay_preroll = false;
        p->replay_preroll_since_us = 0;
      }
      if (p->pending_rate_seek) {
        p->pending_rate_seek = false;
        (void)gstp_pipeline_apply_rate(p);
      }
#if defined(__ANDROID__)
      /* No window yet — keep pending; do not fake PLAYING without a surface. */
      if (p->android_window == 0) {
        p->pending_auto_play = true;
        gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
        break;
      }
#endif
      if (p->is_uri && p->pipeline) {
        /* Resume forced buffering pause only for URI/network streams. */
        gst_element_set_state(p->pipeline, GST_STATE_PLAYING);
      }
      gstp_player_set_state(p, GSTP_STATE_PLAYING);
    } else {
      if (p->pending_rate_seek) {
        p->pending_rate_seek = false;
        (void)gstp_pipeline_apply_rate(p);
      }
      gstp_player_set_state(p, GSTP_STATE_PAUSED);
    }
    if (percent >= 100) {
      gstp_media_update_timing(p);
    }
    if (!regress) {
      gstp_player_emit(p, GSTP_EVENT_BUFFERING, "");
    }
    break;
  }
  case GST_MESSAGE_DURATION_CHANGED:
    gstp_media_update_timing(p);
    break;
  case GST_MESSAGE_ASYNC_DONE:
    if (GST_MESSAGE_SRC(msg) == GST_OBJECT(p->pipeline)) {
      if (p->scrub_hold_until_us > 0 &&
          g_get_monotonic_time() < p->scrub_hold_until_us) {
        gint64 pos = GST_CLOCK_TIME_NONE;
        if (gstp_query_position_on_playsink(p, &pos) ||
            gst_element_query_position(p->pipeline, GST_FORMAT_TIME, &pos)) {
          if (GST_CLOCK_TIME_IS_VALID(pos)) {
            const int64_t ms = (int64_t)(pos / GST_MSECOND);
            p->scrub_hold_target_ms = ms;
            p->position_ms = ms;
            p->last_frame_pts_ms = -1;
            gstp_media_sync_wall_clock(p);
            if (!p->suppress_timing_emit) {
              gstp_player_emit(p, GSTP_EVENT_POSITION_CHANGED, "");
            }
          }
        }
      }
      gstp_media_update_timing(p);
      gstp_pipeline_update_seekable(p);
    }
    break;
  case GST_MESSAGE_TAG: {
    GstTagList *tags = NULL;
    gst_message_parse_tag(msg, &tags);
    if (tags) {
      guint64 duration = GST_CLOCK_TIME_NONE;
      if (gst_tag_list_get_uint64(tags, GST_TAG_DURATION, &duration) &&
          GST_CLOCK_TIME_IS_VALID(duration)) {
        int64_t ms = (int64_t)(duration / GST_MSECOND);
        if (ms > 0 && ms != p->tag_duration_ms) {
          p->tag_duration_ms = ms;
          gstp_media_set_duration_ms(p, ms);
        }
      }
      gst_tag_list_unref(tags);
    }
    break;
  }
  case GST_MESSAGE_STREAM_COLLECTION: {
    GstStreamCollection *collection = NULL;
    gst_message_parse_stream_collection(msg, &collection);
    if (collection) {
      if (p->stream_collection) {
        gst_object_unref(p->stream_collection);
      }
      p->stream_collection = collection;
    }
    gstp_pipeline_refresh_tracks(p);
    gstp_player_emit(p, GSTP_EVENT_TRACKS_CHANGED, "");
    break;
  }
  case GST_MESSAGE_STREAMS_SELECTED:
    gstp_pipeline_refresh_tracks(p);
    gstp_pipeline_apply_streams_selected(p, msg);
    gstp_player_emit(p, GSTP_EVENT_TRACKS_CHANGED, "");
    break;
  default:
    break;
  }
  return TRUE;
}

void gstp_bus_attach(GstpPlayer *p) {
  if (!p->pipeline) {
    return;
  }
  gstp_bus_detach(p);
  GstpRuntime *rt = gstp_runtime();
  GstBus *bus = gst_element_get_bus(p->pipeline);
  GSource *bus_src = gst_bus_create_watch(bus);
  /* gst_bus_create_watch expects GstBusFunc-compatible callback. */
  g_source_set_callback(bus_src, (GSourceFunc)(void *)gstp_bus_on_message, p,
                        NULL);
  p->bus_watch_id = g_source_attach(bus_src, rt->ctx);
  g_source_unref(bus_src);
  gst_object_unref(bus);

  if (p->position_timer_id == 0) {
    GSource *timer = g_timeout_source_new(100);
    g_source_set_callback(timer, gstp_position_tick, p, NULL);
    p->position_timer_id = g_source_attach(timer, rt->ctx);
    g_source_unref(timer);
  }
}

static void gstp_source_remove_on_ctx(GMainContext *ctx, guint *id) {
  if (*id == 0) {
    return;
  }
  if (ctx) {
    GSource *src = g_main_context_find_source_by_id(ctx, *id);
    if (src) {
      g_source_destroy(src);
    }
  }
  *id = 0;
}

void gstp_bus_detach(GstpPlayer *p) {
  GstpRuntime *rt = gstp_runtime();
  gstp_source_remove_on_ctx(rt->ctx, &p->bus_watch_id);
  gstp_source_remove_on_ctx(rt->ctx, &p->position_timer_id);
  gstp_source_remove_on_ctx(rt->ctx, &p->position_emit_idle_id);
}
