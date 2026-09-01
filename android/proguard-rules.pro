# Consumer ProGuard / R8 rules for apps that minify with this plugin.

-keep class org.freedesktop.gstreamer.** { *; }

-keep class com.gstplayer.GStreamerInitProvider { *; }
-keep class com.gstplayer.NativeRuntimeWarmup { *; }
-keep class com.gstplayer.GstPlayerPlugin { *; }
-keep class com.gstplayer.AndroidSurfaceBridge { *; }
-keep class com.gstplayer.GstVideoTexture { *; }
