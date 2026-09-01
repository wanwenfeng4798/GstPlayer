#include "gstp_internal.h"

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE

#define GSTP_DECL_PLUGIN(name) void gst_plugin_##name##_register(void)

GSTP_DECL_PLUGIN(coreelements);
GSTP_DECL_PLUGIN(app);
GSTP_DECL_PLUGIN(typefindfunctions);
GSTP_DECL_PLUGIN(playback);
GSTP_DECL_PLUGIN(autodetect);
GSTP_DECL_PLUGIN(pbtypes);
GSTP_DECL_PLUGIN(gio);
GSTP_DECL_PLUGIN(videoconvertscale);
GSTP_DECL_PLUGIN(videofilter);
GSTP_DECL_PLUGIN(videorate);
GSTP_DECL_PLUGIN(deinterlace);
GSTP_DECL_PLUGIN(videocrop);
GSTP_DECL_PLUGIN(audioconvert);
GSTP_DECL_PLUGIN(audioresample);
GSTP_DECL_PLUGIN(audiorate);
GSTP_DECL_PLUGIN(volume);
GSTP_DECL_PLUGIN(audiofx);
GSTP_DECL_PLUGIN(audioparsers);
GSTP_DECL_PLUGIN(videoparsersbad);
GSTP_DECL_PLUGIN(isomp4);
GSTP_DECL_PLUGIN(matroska);
GSTP_DECL_PLUGIN(id3demux);
GSTP_DECL_PLUGIN(subparse);
GSTP_DECL_PLUGIN(avi);
GSTP_DECL_PLUGIN(libav);
GSTP_DECL_PLUGIN(jpeg);
GSTP_DECL_PLUGIN(png);
GSTP_DECL_PLUGIN(osxaudio);
GSTP_DECL_PLUGIN(soup);
GSTP_DECL_PLUGIN(hls);
GSTP_DECL_PLUGIN(rtp);
GSTP_DECL_PLUGIN(rtpmanager);
GSTP_DECL_PLUGIN(rtsp);
GSTP_DECL_PLUGIN(udp);
GSTP_DECL_PLUGIN(tcp);
GSTP_DECL_PLUGIN(srtp);
GSTP_DECL_PLUGIN(dtls);
GSTP_DECL_PLUGIN(opengl);
GSTP_DECL_PLUGIN(applemedia);

void gstp_register_ios_static_plugins(void) {
  gst_plugin_coreelements_register();
  gst_plugin_app_register();
  gst_plugin_typefindfunctions_register();
  gst_plugin_playback_register();
  gst_plugin_autodetect_register();
  gst_plugin_pbtypes_register();
  gst_plugin_gio_register();
  gst_plugin_videoconvertscale_register();
  gst_plugin_videofilter_register();
  gst_plugin_videorate_register();
  gst_plugin_deinterlace_register();
  gst_plugin_videocrop_register();
  gst_plugin_audioconvert_register();
  gst_plugin_audioresample_register();
  gst_plugin_audiorate_register();
  gst_plugin_volume_register();
  gst_plugin_audiofx_register();
  gst_plugin_audioparsers_register();
  gst_plugin_videoparsersbad_register();
  gst_plugin_isomp4_register();
  gst_plugin_matroska_register();
  gst_plugin_id3demux_register();
  gst_plugin_subparse_register();
  gst_plugin_avi_register();
  gst_plugin_libav_register();
  gst_plugin_jpeg_register();
  gst_plugin_png_register();
  gst_plugin_osxaudio_register();
  gst_plugin_soup_register();
  gst_plugin_hls_register();
  gst_plugin_rtp_register();
  gst_plugin_rtpmanager_register();
  gst_plugin_rtsp_register();
  gst_plugin_udp_register();
  gst_plugin_tcp_register();
  gst_plugin_srtp_register();
  gst_plugin_dtls_register();
  gst_plugin_opengl_register();
  gst_plugin_applemedia_register();
}

#endif
