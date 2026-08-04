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
import 'volume_popup_button.dart';

/// Icon set for shared Bilibili-style bottom chrome / 共享底栏图标集.
class BiliControlIcons {
  /// Creates an icon set / 创建图标集.
  const BiliControlIcons({
    required this.play,
    required this.pause,
    required this.volumeOn,
    required this.volumeOff,
    required this.loop,
    required this.capture,
    required this.subtitle,
    required this.fullscreen,
    required this.fullscreenExit,
  });

  /// Material icon set / Material 图标.
  static const material = BiliControlIcons(
    play: Icons.play_arrow,
    pause: Icons.pause,
    volumeOn: Icons.volume_up,
    volumeOff: Icons.volume_off,
    loop: Icons.loop,
    capture: Icons.photo_camera_outlined,
    subtitle: Icons.closed_caption,
    fullscreen: Icons.fullscreen,
    fullscreenExit: Icons.fullscreen_exit,
  );

  /// Cupertino-leaning icon set / 偏 Cupertino 图标.
  static const cupertino = BiliControlIcons(
    play: Icons.play_arrow,
    pause: Icons.pause,
    volumeOn: Icons.volume_up,
    volumeOff: Icons.volume_off,
    loop: Icons.repeat,
    capture: Icons.camera_alt_outlined,
    subtitle: Icons.closed_caption,
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
    required this.onCapture,
    this.showFullscreenButton = false,
    this.landscapeLocked,
    this.onFullscreenToggle,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;
  final ScrubController scrub;
  final ScrubPreviewController preview;
  final BiliControlIcons icons;
  final VoidCallback onCapture;
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
                          Flexible(
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
                          const Spacer(),
                          if (!compact) ...[
                            VolumePopupButton(
                              model: model,
                              theme: theme,
                              onInteract: onInteract,
                              volumeOnIcon: icons.volumeOn,
                              volumeOffIcon: icons.volumeOff,
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
