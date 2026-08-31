import 'package:material_ui/material_ui.dart';

import '../constant/constant.dart';
import '../l10n/gst_player_strings.dart';
import '../theme/video_controls_theme.dart';
import '../utils/time_util.dart';
import 'bili_overlay_controls.dart';
import 'chrome_popup_button.dart';
import 'playback_controls_model.dart';
import 'player_chrome_settings.dart';
import 'player_settings_popup.dart';
import 'progress_bar_with_preview.dart';
import 'scrub_controller.dart';
import 'scrub_preview_controller.dart';
import 'scrub_preview_track.dart';
import 'volume_popup_button.dart';

/// Icon set for shared Bilibili-style bottom chrome / 共享底栏图标集.
class BiliControlIcons {
  /// Material icon set / Material 图标.
  static const material = BiliControlIcons(
    play: Icons.play_arrow,
    pause: Icons.pause,
    volumeOn: Icons.volume_up,
    volumeOff: Icons.volume_off,
    settings: Icons.settings,
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
    required this.settings,
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
    settings: Icons.settings,
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
  final IconData settings;
  final IconData danmakuOn;
  final IconData danmakuOff;
  final IconData externalSubtitleOn;
  final IconData externalSubtitleOff;
  final IconData fullscreen;
  final IconData fullscreenExit;
}

/// Shared Bilibili-style bottom chrome: transport row + optional danmaku row.
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
    required this.strings,
    required this.settings,
    this.scrubPreview,
    this.overlayControls,
    this.showFullscreenButton = true,
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
  final GstPlayerStrings strings;
  final PlayerChromeSettings settings;
  final bool showFullscreenButton;
  final bool? landscapeLocked;
  final VoidCallback? onFullscreenToggle;

  ButtonStyle get _iconStyle => IconButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    minimumSize: const Size(32, 32),
  );

  @override
  Widget build(BuildContext context) {
    final overlay = overlayControls;

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
                _buildTransportRow(context),
                if (overlay != null &&
                    (overlay.showDanmakuInput ||
                        overlay.showDanmakuToggle ||
                        overlay.showSubtitlesToggle))
                  _buildDanmakuRow(overlay),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 800.0;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: width < 480 ? 480 : width,
              child: Row(
                children: [
                  IconButton(
                    style: _iconStyle,
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
                  _TimeLabel(
                    model: model,
                    scrub: scrub,
                    theme: theme,
                    remaining: false,
                  ),
                  Expanded(
                    child: SliderTheme(
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        disabledActiveTrackColor: theme.activeTrackColor,
                        disabledInactiveTrackColor: theme.inactiveTrackColor,
                        disabledThumbColor: theme.thumbColor,
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
                          onChangeStart: snap.canSeek
                              ? (_) => snap.onSeekStart?.call()
                              : null,
                          onChanged: snap.canSeek ? snap.onSeekChanged : null,
                          onChangeEnd: snap.canSeek ? snap.onSeekEnd : null,
                        ),
                      ),
                    ),
                  ),
                  _TimeLabel(
                    model: model,
                    scrub: scrub,
                    theme: theme,
                    remaining: true,
                  ),
                  _SpeedMenuButton(
                    model: model,
                    theme: theme,
                    onInteract: onInteract,
                  ),
                  PlayerSettingsButton(
                    model: model,
                    settings: settings,
                    theme: theme,
                    strings: strings,
                    icon: icons.settings,
                    onInteract: onInteract,
                  ),
                  VolumePopupButton(
                    model: model,
                    theme: theme,
                    onInteract: onInteract,
                    volumeOnIcon: icons.volumeOn,
                    volumeOffIcon: icons.volumeOff,
                  ),
                  if (showFullscreenButton && onFullscreenToggle != null)
                    IconButton(
                      style: _iconStyle,
                      color: theme.iconColor,
                      icon: Icon(
                        (landscapeLocked ?? false)
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDanmakuRow(BiliOverlayControlsConfig overlay) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: Row(
        children: [
          if (overlay.showDanmakuToggle)
            IconButton(
              style: _iconStyle,
              color: overlay.danmakuEnabled
                  ? theme.activeIconColor
                  : theme.iconColor.withValues(alpha: 0.55),
              tooltip: overlay.danmakuEnabled
                  ? strings.closeDanmaku
                  : strings.openDanmaku,
              icon: Icon(
                overlay.danmakuEnabled ? icons.danmakuOn : icons.danmakuOff,
                size: theme.secondaryIconSize,
              ),
              onPressed: () {
                onInteract();
                overlay.onDanmakuEnabledChanged!(!overlay.danmakuEnabled);
              },
            ),
          if (overlay.showDanmakuInput) ...[
            const SizedBox(width: 4),
            Expanded(
              child: _BiliDanmakuInput(
                hint: overlay.danmakuHint.isEmpty
                    ? strings.danmakuHint
                    : overlay.danmakuHint,
                sendLabel: strings.send,
                enabled: overlay.danmakuEnabled,
                accentColor: theme.activeIconColor,
                onInteract: onInteract,
                onSend: overlay.onDanmakuSend!,
              ),
            ),
          ] else
            const Spacer(),
          if (overlay.showSubtitlesToggle)
            IconButton(
              style: _iconStyle,
              color: overlay.subtitlesEnabled
                  ? theme.activeIconColor
                  : theme.iconColor.withValues(alpha: 0.55),
              tooltip: overlay.subtitlesEnabled
                  ? strings.closeSubtitles
                  : strings.openSubtitles,
              icon: Icon(
                overlay.subtitlesEnabled
                    ? icons.externalSubtitleOn
                    : icons.externalSubtitleOff,
                size: theme.secondaryIconSize,
              ),
              onPressed: () {
                onInteract();
                overlay.onSubtitlesEnabledChanged!(!overlay.subtitlesEnabled);
              },
            ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.model,
    required this.scrub,
    required this.theme,
    required this.remaining,
  });

  final PlaybackControlsModel model;
  final ScrubController scrub;
  final VideoControlsTheme theme;
  final bool remaining;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([model, scrub]),
      builder: (context, _) {
        final durMs = model.duration.inMilliseconds;
        final posMs = model.position.inMilliseconds;
        final fraction = scrub.sliderValue(durMs.toDouble(), posMs.toDouble());
        final displayPos = durMs > 0
            ? Duration(
                milliseconds: (fraction * durMs).round().clamp(0, durMs),
              )
            : model.position;
        final text = remaining
            ? formatDuration(
                model.duration - displayPos < Duration.zero
                    ? Duration.zero
                    : model.duration - displayPos,
              )
            : formatDuration(displayPos);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}

class _SpeedMenuButton extends StatelessWidget {
  const _SpeedMenuButton({
    required this.model,
    required this.theme,
    required this.onInteract,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    return ChromePopupButton(
      theme: theme,
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
                      padding: const EdgeInsets.symmetric(
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
                                    color: theme.textColor,
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
      buttonBuilder: (context, showMenu) {
        return GestureDetector(
          onTap: showMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${model.speed}x',
              style: TextStyle(
                color: theme.iconColor,
                fontSize: theme.secondaryIconSize * 0.75,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BiliDanmakuInput extends StatefulWidget {
  const _BiliDanmakuInput({
    required this.hint,
    required this.sendLabel,
    required this.enabled,
    required this.accentColor,
    required this.onInteract,
    required this.onSend,
  });

  final String hint;
  final String sendLabel;
  final bool enabled;
  final Color accentColor;
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
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onInteract();
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: enabled,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white38,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: enabled ? 0.45 : 0.25),
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
              disabledBorder: OutlineInputBorder(
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
            onTap: enabled ? widget.onInteract : null,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: enabled ? _submit : null,
          style: TextButton.styleFrom(
            foregroundColor: widget.accentColor,
            disabledForegroundColor: widget.accentColor.withValues(alpha: 0.35),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
          child: Text(
            widget.sendLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
