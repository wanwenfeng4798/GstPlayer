#include "gstp_player.h"

#if defined(__ANDROID__)

#include <android/log.h>
#include <android/native_window_jni.h>
#include <jni.h>
#include <stdint.h>

#define LOG_TAG "GstpNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static JavaVM *g_vm = NULL;

static void gstp_android_bind_surface(JNIEnv *env, jlong player_id,
                                      jobject surface, jint width,
                                      jint height) {
  if (surface == NULL || player_id == 0) {
    return;
  }
  ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
  if (!window) {
    LOGE("ANativeWindow_fromSurface failed");
    return;
  }
  int w = width;
  int h = height;
  if (w <= 0) {
    w = ANativeWindow_getWidth(window);
  }
  if (h <= 0) {
    h = ANativeWindow_getHeight(window);
  }
  gstp_player_notify_android_surface(player_id, (int64_t)(intptr_t)window, w,
                                     h);
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
  (void)reserved;
  /* Capture JavaVM only. Defer gstp_init until after GStreamer.init(Context)
   * so MediaCodec discovery has an application ClassLoader (see
   * GStreamerInitProvider). */
  g_vm = vm;
  LOGI("JNI_OnLoad: JavaVM captured");
  return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL
Java_com_gstplayer_NativeRuntimeWarmup_nativeWarmupNativeRuntime(
    JNIEnv *env, jclass clazz) {
  (void)env;
  (void)clazz;
  gstp_init();
  LOGI("NativeRuntimeWarmup: gstp_init done");
}

JNIEXPORT void JNICALL
Java_com_gstplayer_AndroidSurfaceBridge_nativeOnSurfaceCreated(
    JNIEnv *env, jclass clazz, jlong player_id, jobject surface) {
  (void)clazz;
  gstp_android_bind_surface(env, player_id, surface, 0, 0);
}

JNIEXPORT void JNICALL
Java_com_gstplayer_AndroidSurfaceBridge_nativeOnSurfaceChanged(
    JNIEnv *env, jclass clazz, jlong player_id, jobject surface, jint width,
    jint height) {
  (void)clazz;
  gstp_android_bind_surface(env, player_id, surface, width, height);
}

JNIEXPORT void JNICALL
Java_com_gstplayer_AndroidSurfaceBridge_nativeOnSurfaceDestroyed(
    JNIEnv *env, jclass clazz, jlong player_id) {
  (void)env;
  (void)clazz;
  gstp_player_clear_android_surface(player_id);
}

#endif /* __ANDROID__ */
