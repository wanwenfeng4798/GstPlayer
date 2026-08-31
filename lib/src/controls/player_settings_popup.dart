import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../domain/player_events.dart';
import '../l10n/gst_player_strings.dart';
import '../theme/video_controls_theme.dart';
import 'chrome_popup_button.dart';
import 'playback_controls_model.dart';
import 'player_chrome_settings.dart';

/// Gear button that opens the two-page playback settings overlay /
/// 齿轮按钮，打开两级播放设置弹层.
class PlayerSettingsButton extends StatelessWidget {
  /// Creates a settings button / 创建设置按钮.
  const PlayerSettingsButton({
    super.key,
    required this.model,
    required this.settings,
    required this.theme,
    required this.strings,
    required this.icon,
    required this.onInteract,
    this.showCaptureButton = true,
    this.onScreenshot,
  });

  final PlaybackControlsModel model;
  final PlayerChromeSettings settings;
  final VideoControlsTheme theme;
  final GstPlayerStrings strings;
  final IconData icon;
  final VoidCallback onInteract;
  final bool showCaptureButton;
  final Future<void> Function(Uint8List pngBytes)? onScreenshot;

  @override
  Widget build(BuildContext context) {
    return ChromePopupButton(
      theme: theme,
      decorate: false,
      menuBuilder: (context, hideMenu) {
        return _PlayerSettingsPanel(
          model: model,
          settings: settings,
          theme: theme,
          strings: strings,
          onInteract: onInteract,
          showCaptureButton: showCaptureButton,
          onScreenshot: onScreenshot,
        );
      },
      buttonBuilder: (context, showMenu) {
        return IconButton(
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
          ),
          color: theme.iconColor,
          tooltip: strings.settings,
          icon: Icon(icon, size: theme.secondaryIconSize),
          onPressed: () {
            onInteract();
            showMenu();
          },
        );
      },
    );
  }
}

class _PlayerSettingsPanel extends StatefulWidget {
  const _PlayerSettingsPanel({
    required this.model,
    required this.settings,
    required this.theme,
    required this.strings,
    required this.onInteract,
    this.showCaptureButton = true,
    this.onScreenshot,
  });

  final PlaybackControlsModel model;
  final PlayerChromeSettings settings;
  final VideoControlsTheme theme;
  final GstPlayerStrings strings;
  final VoidCallback onInteract;
  final bool showCaptureButton;
  final Future<void> Function(Uint8List pngBytes)? onScreenshot;

  @override
  State<_PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends State<_PlayerSettingsPanel> {
  bool _more = false;
  bool _screenshotBusy = false;

  Future<void> _captureScreenshot() async {
    final onScreenshot = widget.onScreenshot;
    if (_screenshotBusy || onScreenshot == null) return;
    setState(() => _screenshotBusy = true);
    widget.onInteract();
    try {
      final png = await widget.model.captureFramePng();
      if (!mounted) return;
      if (png == null || png.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.screenshotFailed)),
        );
        return;
      }
      await onScreenshot(png);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings.screenshotFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _screenshotBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: 280,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  widget.model,
                  widget.settings,
                ]),
                builder: (context, _) {
                  return _more ? _buildMorePage() : _buildMainPage();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainPage() {
    final s = widget.strings;
    final settings = widget.settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            s.settings,
            style: TextStyle(
              color: widget.theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _SwitchRow(
          theme: widget.theme,
          strings: s,
          label: s.mirror,
          value: settings.mirrored,
          onChanged: (v) {
            widget.onInteract();
            settings.mirrored = v;
          },
        ),
        _SwitchRow(
          theme: widget.theme,
          strings: s,
          label: s.loopSingle,
          value: widget.model.looping,
          onChanged: (v) {
            widget.onInteract();
            widget.model.setLooping(v);
          },
        ),
        _SwitchRow(
          theme: widget.theme,
          strings: s,
          label: s.autoPlay,
          value: settings.playNextOnEnd,
          onChanged: (v) {
            widget.onInteract();
            settings.playNextOnEnd = v;
          },
        ),
        if (widget.showCaptureButton && widget.onScreenshot != null)
          InkWell(
            onTap: _screenshotBusy ? null : _captureScreenshot,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.screenshot,
                      style: TextStyle(
                        color: widget.theme.textColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_screenshotBusy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.theme.iconColor,
                      ),
                    )
                  else
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 20,
                      color: widget.theme.iconColor.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
          ),
        InkWell(
          onTap: () {
            widget.onInteract();
            setState(() => _more = true);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.morePlaybackSettings,
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: widget.theme.iconColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMorePage() {
    final s = widget.strings;
    final theme = widget.theme;
    final settings = widget.settings;
    final audioTracks = widget.model.tracks
        .where((t) => t.trackType == TrackType.audio)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            widget.onInteract();
            setState(() => _more = false);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 20, color: theme.iconColor),
                const SizedBox(width: 4),
                Text(
                  s.back,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        _SectionLabel(theme: theme, text: s.playbackMethod),
        _ChoiceRow(
          theme: theme,
          label: s.pauseAtEnd,
          selected: !settings.playNextOnEnd,
          onTap: () {
            widget.onInteract();
            settings.playNextOnEnd = false;
          },
        ),
        _ChoiceRow(
          theme: theme,
          label: s.playNext,
          selected: settings.playNextOnEnd,
          onTap: () {
            widget.onInteract();
            settings.playNextOnEnd = true;
          },
        ),
        _SectionLabel(theme: theme, text: s.videoAspect),
        _ChoiceRow(
          theme: theme,
          label: s.ratio16_9,
          selected: settings.displayAspect == ForcedDisplayAspect.ratio16_9,
          onTap: () {
            widget.onInteract();
            settings.displayAspect = ForcedDisplayAspect.ratio16_9;
          },
        ),
        _ChoiceRow(
          theme: theme,
          label: s.ratio4_3,
          selected: settings.displayAspect == ForcedDisplayAspect.ratio4_3,
          onTap: () {
            widget.onInteract();
            settings.displayAspect = ForcedDisplayAspect.ratio4_3;
          },
        ),
        _SectionLabel(theme: theme, text: s.otherSettings),
        _SwitchRow(
          theme: theme,
          strings: s,
          label: s.hideBlackBars,
          value: settings.hideBlackBars,
          onChanged: (v) {
            widget.onInteract();
            settings.hideBlackBars = v;
          },
        ),
        _SwitchRow(
          theme: theme,
          strings: s,
          label: s.lightsOff,
          value: settings.lightsOff,
          onChanged: (v) {
            widget.onInteract();
            settings.lightsOff = v;
          },
        ),
        _SectionLabel(theme: theme, text: s.audioTrack),
        if (audioTracks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              s.noAudioTracks,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          )
        else
          for (final track in audioTracks)
            _ChoiceRow(
              theme: theme,
              label: track.label.isEmpty
                  ? s.audioTrackFallback(track.id)
                  : track.label,
              selected: track.selected,
              onTap: () {
                widget.onInteract();
                widget.model.selectTrack(track, enable: !track.selected);
              },
            ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.theme, required this.text});

  final VideoControlsTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          color: theme.textColor.withValues(alpha: 0.55),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.theme,
    required this.strings,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final VideoControlsTheme theme;
  final GstPlayerStrings strings;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.textColor, fontSize: 14),
            ),
          ),
          Text(
            value ? strings.onLabel : strings.offLabel,
            style: TextStyle(
              color: value
                  ? theme.activeIconColor
                  : theme.textColor.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final VideoControlsTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: selected
                  ? Icon(Icons.check, size: 16, color: theme.activeIconColor)
                  : null,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? theme.activeIconColor : theme.textColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
