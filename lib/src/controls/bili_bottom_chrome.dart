import 'package:chat_context_menu/chat_context_menu.dart';
import 'package:flutter/material.dart';

import '../constant/constant.dart';
import '../domain/player_events.dart';
import '../theme/video_controls_theme.dart';
import '../utils/time_util.dart';
import 'playback_controls_model.dart';
import 'progress_bar_with_preview.dart';
import 'scrub_controller.dart';
import 'scrub_preview_controller.dart';
import 'scrub_preview_track.dart';
import 'volume_popup_button.dart';
import 'bili_overlay_controls.dart';

/// Icon set for shared Bilibili-style bottom chrome / 共享底栏图标集.
class BiliControlIcons {
  /// Material icon set / Material 图标.
  static const material = BiliControlIcons(
    play: Icons.play_arrow,
    pause: Icons.pause,
    volumeOn: Icons.volume_up,
    volumeOff: Icons.volume_off,
    loop: Icons.loop,
    capture: Icons.photo_camera_outlined,
    subtitle: Icons.closed_caption,
    danmakuOn: Icons.subtitles,
    danmakuOff: Icons.subtitles_outlined,
    externalSubtitleOn: Icons.closed_caption,
    externalSubtitleOff: Icons.closed_caption_off_outlined,
    fullscreen: Icons.fullscreen,
    fullscreenExit: Icons.fullscreen_exit,
  );

  /// Creates an icon set / 创建图标集.
  const BiliControlIcons({
    required this.play,
    required this.pause,
    required this.volumeOn,
    required this.volumeOff,
    required this.loop,
    required this.capture,
    required this.subtitle,
    required this.danmakuOn,
    required this.danmakuOff,
    required this.externalSubtitleOn,
    required this.externalSubtitleOff,
    required this.fullscreen,
    required this.fullscreenExit,
  });

  /// Cupertino-leaning icon set / 偏 Cupertino 图标.
  static const cupertino = BiliControlIcons(
    play: Icons.play_arrow,
    pause: Icons.pause,
    volumeOn: Icons.volume_up,
    volumeOff: Icons.volume_off,
    loop: Icons.repeat,
    capture: Icons.camera_alt_outlined,
    subtitle: Icons.closed_caption,
    danmakuOn: Icons.subtitles,
    danmakuOff: Icons.subtitles_outlined,
    externalSubtitleOn: Icons.closed_caption,
    externalSubtitleOff: Icons.closed_caption_off_outlined,
    fullscreen: Icons.open_in_full,
    fullscreenExit: Icons.close_fullscreen,
  );

  final IconData play;
  final IconData pause;
  final IconData volumeOn;
  final IconData volumeOff;
  final IconData loop;
  final IconData capture;
  final IconData subtitle;
  final IconData danmakuOn;
  final IconData danmakuOff;
  final IconData externalSubtitleOn;
  final IconData externalSubtitleOff;
  final IconData fullscreen;
  final IconData fullscreenExit;
}

/// Shared Bilibili-style bottom chrome: progress row + tool row.
class BiliBottomChrome extends StatelessWidget {
  /// Creates the shared bottom chrome / 创建共享底栏.
  const BiliBottomChrome({
    super.key,
    required this.model,
    required this.theme,
    required this.onInteract,
    required this.scrub,
    required this.preview,
    required this.icons,
    this.onCapture,
    this.scrubPreview,
    this.overlayControls,
    this.showCaptureButton = true,
    this.showFullscreenButton = false,
    this.landscapeLocked,
    this.onFullscreenToggle,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;
  final ScrubController scrub;
  final ScrubPreviewController preview;
  final ScrubPreviewTrack? scrubPreview;
  final BiliOverlayControlsConfig? overlayControls;
  final BiliControlIcons icons;
  final VoidCallback? onCapture;
  final bool showCaptureButton;
  final bool showFullscreenButton;
  final bool? landscapeLocked;
  final VoidCallback? onFullscreenToggle;

  @override
  Widget build(BuildContext context) {
    final subtitleTracks = model.tracks
        .where((t) => t.trackType == TrackType.subtitle)
        .toList();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              theme.backgroundColor,
              theme.backgroundColor.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Padding(
            padding: theme.barPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.activeTrackColor,
                    inactiveTrackColor: theme.inactiveTrackColor,
                    thumbColor: theme.thumbColor,
                    secondaryActiveTrackColor: theme.bufferedTrackColor,
                    trackHeight: 2.5,
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 8,
                    ),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                      elevation: 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: ProgressBarWithPreview(
                    model: model,
                    scrub: scrub,
                    preview: preview,
                    scrubPreview: scrubPreview,
                    theme: theme,
                    previewBarHeight: 72,
                    builder: (context, snap) => Slider(
                      value: snap.displayValue,
                      onChangeStart: snap.enabled
                          ? (_) => snap.onSeekStart?.call()
                          : null,
                      onChanged: snap.onSeekChanged,
                      onChangeEnd: snap.onSeekEnd,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 320;
                      final hasOverlay = overlayControls != null;
                      // Overlay row: danmaku/subtitle toggles. Volume stays visible
                      // with or without overlay; loop/speed stay classic-only.
                      final showTimeInBar =
                          !hasOverlay || constraints.maxWidth >= 400;
                      final showVolume = !compact;
                      final showSecondaryTools = !compact && !hasOverlay;
                      return Row(
                        children: [
                          IconButton(
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            color: theme.iconColor,
                            icon: Icon(
                              model.isPlaying ? icons.pause : icons.play,
                              size: theme.primaryIconSize,
                            ),
                            onPressed: () {
                              onInteract();
                              model.togglePlayPause();
                            },
                          ),
                          if (showTimeInBar)
                            Flexible(
                              flex: hasOverlay ? 0 : 1,
                              fit: hasOverlay ? FlexFit.loose : FlexFit.tight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${formatDuration(model.position)} / ${formatDuration(model.duration)}',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (hasOverlay) ...[
                            if (overlayControls!.showDanmakuInput) ...[
                              const SizedBox(width: 4),
                              Expanded(
                                child: _BiliDanmakuInput(
                                  hint: overlayControls!.danmakuHint,
                                  enabled: overlayControls!.danmakuEnabled,
                                  onInteract: onInteract,
                                  onSend: overlayControls!.onDanmakuSend!,
                                ),
                              ),
                            ],
                            if (overlayControls!.showDanmakuToggle)
                              IconButton(
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                                color: overlayControls!.danmakuEnabled
                                    ? theme.activeIconColor
                                    : theme.iconColor.withValues(alpha: 0.55),
                                tooltip: overlayControls!.danmakuEnabled
                                    ? '关闭弹幕'
                                    : '打开弹幕',
                                icon: Icon(
                                  overlayControls!.danmakuEnabled
                                      ? icons.danmakuOn
                                      : icons.danmakuOff,
                                  size: theme.secondaryIconSize,
                                ),
                                onPressed: () {
                                  onInteract();
                                  overlayControls!.onDanmakuEnabledChanged!(
                                    !overlayControls!.danmakuEnabled,
                                  );
                                },
                              ),
                            if (overlayControls!.showSubtitlesToggle)
                              IconButton(
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                                color: overlayControls!.subtitlesEnabled
                                    ? theme.activeIconColor
                                    : theme.iconColor.withValues(alpha: 0.55),
                                tooltip: overlayControls!.subtitlesEnabled
                                    ? '关闭字幕'
                                    : '打开字幕',
                                icon: Icon(
                                  overlayControls!.subtitlesEnabled
                                      ? icons.externalSubtitleOn
                                      : icons.externalSubtitleOff,
                                  size: theme.secondaryIconSize,
                                ),
                                onPressed: () {
                                  onInteract();
                                  overlayControls!.onSubtitlesEnabledChanged!(
                                    !overlayControls!.subtitlesEnabled,
                                  );
                                },
                              ),
                            if (showCaptureButton && onCapture != null)
                              IconButton(
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                                color: theme.iconColor,
                                icon: Icon(
                                  icons.capture,
                                  size: theme.secondaryIconSize,
                                ),
                                onPressed: onCapture,
                              ),
                          ] else
                            const Spacer(),
                          if (showVolume)
                            VolumePopupButton(
                              model: model,
                              theme: theme,
                              onInteract: onInteract,
                              volumeOnIcon: icons.volumeOn,
                              volumeOffIcon: icons.volumeOff,
                            ),
                          if (showSecondaryTools) ...[
                            if (showCaptureButton && onCapture != null)
                              IconButton(
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                color: theme.iconColor,
                                icon: Icon(
                                  icons.capture,
                                  size: theme.secondaryIconSize,
                                ),
                                onPressed: onCapture,
                              ),
                            IconButton(
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              color: model.looping
                                  ? theme.activeIconColor
                                  : theme.iconColor.withValues(alpha: 0.55),
                              icon: Icon(
                                icons.loop,
                                size: theme.secondaryIconSize,
                              ),
                              onPressed: () async {
                                onInteract();
                                await model.setLooping(!model.looping);
                              },
                            ),
                            if (model.supportsTracks &&
                                subtitleTracks.isNotEmpty)
                              ChatContextMenuWrapper(
                                topPadding: 0,
                                backgroundColor: theme.backgroundColor,
                                borderRadius: BorderRadius.circular(
                                  theme.borderRadius == 0
                                      ? 8
                                      : theme.borderRadius,
                                ),
                                padding: EdgeInsets.zero,
                                menuBuilder: (context, hideMenu) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final track in subtitleTracks)
                                        InkWell(
                                          onTap: () {
                                            onInteract();
                                            model.selectTrack(
                                              track,
                                              enable: !track.selected,
                                            );
                                            hideMenu();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  child: track.selected
                                                      ? Icon(
                                                          Icons.check,
                                                          size: 16,
                                                          color:
                                                              theme.textColor,
                                                        )
                                                      : null,
                                                ),
                                                Text(
                                                  track.label.isEmpty
                                                      ? 'Subtitle ${track.id}'
                                                      : track.label,
                                                  style: TextStyle(
                                                    color: theme.textColor,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                                widgetBuilder: (context, showMenu, _) {
                                  return IconButton(
                                    style: IconButton.styleFrom(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    color: theme.iconColor,
                                    icon: Icon(
                                      icons.subtitle,
                                      size: theme.secondaryIconSize,
                                    ),
                                    onPressed: showMenu,
                                  );
                                },
                              ),
                            ChatContextMenuWrapper(
                              topPadding: 0,
                              backgroundColor: theme.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                theme.borderRadius == 0
                                    ? 8
                                    : theme.borderRadius,
                              ),
                              padding: EdgeInsets.zero,
                              menuBuilder: (context, hideMenu) {
                                return ListenableBuilder(
                                  listenable: model,
                                  builder: (context, _) {
                                    final current = model.speed;
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final s in speeds)
                                          InkWell(
                                            onTap: () {
                                              onInteract();
                                              model.setSpeed(s);
                                              hideMenu();
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    child: s == current
                                                        ? Icon(
                                                            Icons.check,
                                                            size: 16,
                                                            color: theme
                                                                .textColor,
                                                          )
                                                        : null,
                                                  ),
                                                  Text(
                                                    '${s}x',
                                                    style: TextStyle(
                                                      color: theme.textColor,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                              widgetBuilder: (context, showMenu, _) {
                                return GestureDetector(
                                  onTap: showMenu,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '${model.speed}x',
                                      style: TextStyle(
                                        color: theme.iconColor,
                                        fontSize:
                                            theme.secondaryIconSize * 0.75,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (showFullscreenButton &&
                              landscapeLocked != null &&
                              onFullscreenToggle != null)
                            IconButton(
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              color: theme.iconColor,
                              icon: Icon(
                                landscapeLocked!
                                    ? icons.fullscreenExit
                                    : icons.fullscreen,
                                size: theme.secondaryIconSize,
                              ),
                              onPressed: () {
                                onInteract();
                                onFullscreenToggle!();
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BiliDanmakuInput extends StatefulWidget {
  const _BiliDanmakuInput({
    required this.hint,
    required this.enabled,
    required this.onInteract,
    required this.onSend,
  });

  final String hint;
  final bool enabled;
  final VoidCallback onInteract;
  final ValueChanged<String> onSend;

  @override
  State<_BiliDanmakuInput> createState() => _BiliDanmakuInputState();
}

class _BiliDanmakuInputState extends State<_BiliDanmakuInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onInteract();
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 12,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
      textInputAction: TextInputAction.send,
      onTap: widget.onInteract,
      onSubmitted: (_) => _submit(),
    );
  }
}
