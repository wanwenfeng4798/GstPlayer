package com.gstplayer;

import android.content.Context;
import android.webkit.WebSettings;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

import java.util.HashMap;
import java.util.Map;

/** Registers GStreamer video textures via Flutter {@link TextureRegistry.SurfaceProducer}. */
public class GstPlayerPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    public static final String TEXTURE_CHANNEL_NAME = "gstplayer/texture";

    @Nullable
    private static volatile GstPlayerPlugin instance;

    private MethodChannel textureChannel;
    private TextureRegistry textureRegistry;
    private Context appContext;
    private final Map<Long, GstVideoTexture> videoTextures = new HashMap<>();

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        instance = this;
        appContext = binding.getApplicationContext();

        textureRegistry = binding.getTextureRegistry();
        textureChannel = new MethodChannel(
            binding.getBinaryMessenger(),
            TEXTURE_CHANNEL_NAME
        );
        textureChannel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("getDefaultUserAgent".equals(call.method)) {
            if (appContext == null) {
                result.error("not_ready", "Application context unavailable", null);
                return;
            }
            result.success(WebSettings.getDefaultUserAgent(appContext));
            return;
        }
        long playerId = playerIdFromCall(call);
        if (playerId == 0L) {
            result.error("invalid_args", "playerId required", null);
            return;
        }
        switch (call.method) {
            case "createTexture":
                synchronized (videoTextures) {
                    GstVideoTexture existing = videoTextures.get(playerId);
                    if (existing != null) {
                        result.success(existing.textureId());
                        return;
                    }
                    GstVideoTexture texture =
                        new GstVideoTexture(playerId, textureRegistry, appContext);
                    videoTextures.put(playerId, texture);
                    result.success(texture.textureId());
                }
                break;
            case "disposeTexture":
                synchronized (videoTextures) {
                    GstVideoTexture texture = videoTextures.remove(playerId);
                    if (texture != null) {
                        texture.dispose();
                    }
                }
                result.success(null);
                break;
            case "syncTextureSize": {
                Object rawW = call.argument("width");
                Object rawH = call.argument("height");
                if (!(rawW instanceof Number) || !(rawH instanceof Number)) {
                    result.error("invalid_args", "width and height required", null);
                    return;
                }
                int width = ((Number) rawW).intValue();
                int height = ((Number) rawH).intValue();
                synchronized (videoTextures) {
                    GstVideoTexture texture = videoTextures.get(playerId);
                    if (texture != null) {
                        texture.syncSize(width, height);
                    }
                }
                result.success(null);
                break;
            }
            default:
                result.notImplemented();
                break;
        }
    }

    /** StandardMessageCodec may deliver small ints as {@link Integer}, not {@link Long}. */
    private static long playerIdFromCall(@NonNull MethodCall call) {
        Object raw = call.argument("playerId");
        if (raw instanceof Number) {
            return ((Number) raw).longValue();
        }
        return 0L;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (textureChannel != null) {
            textureChannel.setMethodCallHandler(null);
            textureChannel = null;
        }
        synchronized (videoTextures) {
            for (GstVideoTexture texture : videoTextures.values()) {
                texture.dispose();
            }
            videoTextures.clear();
        }
        textureRegistry = null;
        appContext = null;
        instance = null;
    }
}
