import 'package:flutter/material.dart';

import '../domain/player_events.dart';
import '../enum/video_rotation.dart';
import '../theme/video_controls_theme.dart';
import '../utils/platform_util.dart';
import 'controls_overlay_slots.dart';
import 'fullscreen_config.dart';
import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';
import 'themed_segmented_control.dart';
import 'video_controls_menu_button.dart';

/// AppBar 式沉浸控件顶栏 / AppBar-style top bar for immersive video controls.
class VideoControlsTopBar extends StatelessWidget {
  /// 创建顶栏 / Creates the top bar.
  const VideoControlsTopBar({
    super.key,
    required this.immersive,
    required this.model,
    required this.theme,
    required this.slots,
    required this.orientationLabels,
    required this.showOrientationMenu,
  });

  /// 沉浸控件状态 / Immersive controls state.
  final ImmersiveControlsState immersive;

  /// 播放控件 model / Playback controls model.
  final PlaybackControlsModel model;

  /// 控件主题 / Controls theme.
  final VideoControlsTheme theme;

  /// 顶栏插槽 / Top bar slots.
  final VideoControlsOverlaySlots slots;

  /// 旋转面板文案 / Video rotation panel labels.
  final VideoRotationLabels orientationLabels;

  /// 是否在顶栏显示方向设置按钮 / Whether to show orientation button in the top bar.
  final bool showOrientationMenu;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([immersive, model]),
      builder: (context, _) {
        final immersiveActive = immersive.immersiveActive;
        final hasCustomSlots =
            slots.leading != null ||
            slots.title != null ||
            slots.actions.isNotEmpty;

        if (!immersiveActive && !hasCustomSlots) {
          return const SizedBox.shrink();
        }

        final showOrientationButton =
            showOrientationMenu &&
            model.supportsOrientation &&
            (isMobilePlatform
                ? immersive.landscapeLocked
                : immersiveActive || hasCustomSlots);

        final actions = <Widget>[
          ...slots.actions,
          if (showOrientationButton)
            VideoControlsMenuButton(
              theme: theme,
              icon: Icons.screen_rotation,
              menuBuilder: (context, hideMenu) {
                return ListenableBuilder(
                  listenable: model,
                  builder: (context, _) {
                    final rotation = model.videoRotation;
                    return SizedBox(
                      width: 280,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ThemedSegmentedControl<VideoRotation>(
                          label: orientationLabels.rotateAngle,
                          theme: theme,
                          showSelectedIcon: false,
                          segments: [
                            for (final option in const [
                              VideoRotation.deg0,
                              VideoRotation.deg90,
                              VideoRotation.deg180,
                              VideoRotation.deg270,
                            ])
                              ButtonSegment<VideoRotation>(
                                value: option,
                                label: Text(
                                  orientationLabels.rotateLabel(option.degrees),
                                ),
                              ),
                          ],
                          selected: {rotation},
                          onSelectionChanged: (value) async {
                            await model.setVideoRotation(value.first);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          if (slots.showAspectRatioMenu && immersiveActive)
            Builder(
              builder: (context) {
                final mode = immersive.aspectRatioMode;
                final icon = switch (mode) {
                  AspectRatioMode.fit => theme.fitScreenIcon,
                  AspectRatioMode.fill => theme.fillScreenIcon,
                  AspectRatioMode.stretch => theme.stretchScreenIcon,
                };
                return VideoControlsMenuButton(
                  theme: theme,
                  icon: icon,
                  menuBuilder: (context, hideMenu) {
                    return ListenableBuilder(
                      listenable: immersive,
                      builder: (context, _) {
                        final current = immersive.aspectRatioMode;
                        final labels = immersive.fullscreen.aspectRatioLabels;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final mode in AspectRatioMode.values)
                              InkWell(
                                onTap: () {
                                  immersive.aspectRatioMode = mode;
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
                                        child: mode == current
                                            ? Icon(
                                                Icons.check,
                                                size: 16,
                                                color: theme.textColor,
                                              )
                                            : null,
                                      ),
                                      Text(
                                        labels.label(mode),
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
                );
              },
            ),
        ];

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
              child: Row(
                children: [
                  // leading 占 25% / leading takes 25%
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: slots.leading ?? const SizedBox.shrink(),
                    ),
                  ),
                  // title 占 50% / title takes 50%
                  Expanded(
                    flex: 2,
                    child: slots.title ?? const SizedBox.shrink(),
                  ),
                  // actions 占 25% / actions takes 25%
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: actions.isNotEmpty
                          ? Padding(
                              padding: slots.actionsPadding,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: slots.actionsSpacing,
                                children: actions,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
