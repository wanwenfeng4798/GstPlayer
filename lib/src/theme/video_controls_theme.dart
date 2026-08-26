import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// 内置视频控件栏视觉样式 / Visual styling for the built-in video control bar.
///
/// 在 `ThemeData.extensions` 中注册以自定义；未注册时 [VideoControls] 回退至
/// [VideoControlsTheme.material] / [VideoControlsTheme.cupertino] 预设。
/// Register in `ThemeData.extensions` to customize; [VideoControls] falls back to
/// [VideoControlsTheme.material] / [VideoControlsTheme.cupertino] presets when absent.
class VideoControlsTheme extends ThemeExtension<VideoControlsTheme> {
  /// 创建控件主题 / Creates a controls theme.
  const VideoControlsTheme({
    required this.iconColor,
    required this.activeIconColor,
    required this.activeTrackColor,
    required this.inactiveTrackColor,
    required this.bufferedTrackColor,
    required this.thumbColor,
    required this.textColor,
    required this.backgroundColor,
    required this.primaryIconSize,
    required this.secondaryIconSize,
    required this.centerButtonSize,
    required this.barPadding,
    required this.borderRadius,
    required this.bufferingScrimColor,
    required this.bufferingIndicatorColor,
    required this.bufferingTextColor,
    required this.fitScreenIcon,
    required this.fillScreenIcon,
    required this.stretchScreenIcon,
    this.bufferingTextStyle,
  });

  /// Material 预设 / Material preset.
  factory VideoControlsTheme.material() => const VideoControlsTheme(
    iconColor: Color(0xFFFFFFFF),
    activeIconColor: Color(0xFFFB7299),
    activeTrackColor: Color(0xFFFB7299),
    inactiveTrackColor: Color.fromARGB(118, 255, 255, 255),
    bufferedTrackColor: Color.fromARGB(149, 255, 255, 255),
    thumbColor: Color(0xFFFB7299),
    textColor: Color(0xFFFFFFFF),
    backgroundColor: Color(0x99000000),
    primaryIconSize: 24,
    secondaryIconSize: 20,
    centerButtonSize: 48,
    barPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    borderRadius: 0,
    bufferingScrimColor: Colors.transparent,
    bufferingIndicatorColor: Color(0xFFFFFFFF),
    bufferingTextColor: Color(0xFFFFFFFF),
    fitScreenIcon: Icons.fit_screen,
    fillScreenIcon: Icons.crop_free,
    stretchScreenIcon: Icons.aspect_ratio,
  );

  /// Cupertino 预设（B 站粉轨）/ Cupertino preset with Bilibili pink track.
  factory VideoControlsTheme.cupertino() => const VideoControlsTheme(
    iconColor: Color(0xFFFFFFFF),
    activeIconColor: Color(0xFFFB7299),
    activeTrackColor: Color(0xFFFB7299),
    inactiveTrackColor: Color(0x3DFFFFFF),
    bufferedTrackColor: Color(0x66FFFFFF),
    thumbColor: Color(0xFFFB7299),
    textColor: Color(0xFFEBEBF5),
    backgroundColor: Color(0x99000000),
    primaryIconSize: 24,
    secondaryIconSize: 20,
    centerButtonSize: 48,
    barPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    borderRadius: 0,
    bufferingScrimColor: Colors.transparent,
    bufferingIndicatorColor: Color(0xFFEBEBF5),
    bufferingTextColor: Color(0xFFEBEBF5),
    fitScreenIcon: Icons.fit_screen,
    fillScreenIcon: Icons.crop_free,
    stretchScreenIcon: Icons.aspect_ratio,
  );

  /// Bilibili 预设（粉强调 `#FB7299`）/ Bilibili preset (pink accent).
  factory VideoControlsTheme.bilibili() => const VideoControlsTheme(
    iconColor: Color(0xFFFFFFFF),
    activeIconColor: Color(0xFFFB7299),
    activeTrackColor: Color(0xFFFB7299),
    inactiveTrackColor: Color(0x4DFFFFFF),
    bufferedTrackColor: Color(0x80FFFFFF),
    thumbColor: Color(0xFFFB7299),
    textColor: Color(0xFFFFFFFF),
    backgroundColor: Color(0xB3000000),
    primaryIconSize: 26,
    secondaryIconSize: 20,
    centerButtonSize: 48,
    barPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    borderRadius: 0,
    bufferingScrimColor: Colors.transparent,
    bufferingIndicatorColor: Color(0xFFFB7299),
    bufferingTextColor: Color(0xFFFFFFFF),
    fitScreenIcon: Icons.fit_screen,
    fillScreenIcon: Icons.crop_free,
    stretchScreenIcon: Icons.aspect_ratio,
  );

  /// 空闲控件图标颜色 / Color of idle control icons.
  final Color iconColor;

  /// 激活态高亮（如循环已开）/ Color for active toggles (e.g. looping on).
  final Color activeIconColor;

  /// 已播放进度条段 / Played portion of the seek bar.
  final Color activeTrackColor;

  /// 未播放进度条段 / Unplayed portion of the seek bar.
  final Color inactiveTrackColor;

  /// 已缓冲 ahead 段 / Buffered-ahead portion of the seek bar.
  final Color bufferedTrackColor;

  /// 滑块颜色 / Seek bar thumb color.
  final Color thumbColor;

  /// 时间戳颜色 / Position/duration label color.
  final Color textColor;

  /// 控件栏 / scrim 背景色 / Control bar / scrim background color.
  final Color backgroundColor;

  /// 中央播放/暂停图标尺寸 / Central play/pause icon size.
  final double primaryIconSize;

  /// 次要图标尺寸（静音、循环、倍速）/ Secondary icon size.
  final double secondaryIconSize;

  /// 中央播放/暂停按钮容器尺寸 / Central play/pause button container size.
  final double centerButtonSize;

  /// 底栏内边距 / Bottom bar padding.
  final EdgeInsets barPadding;

  /// 底栏圆角 / Control bar corner radius.
  final double borderRadius;

  /// 缓冲遮罩色；默认透明（非全屏遮挡）/ Buffering scrim; default transparent.
  final Color bufferingScrimColor;

  /// 缓冲指示器颜色 / Buffering spinner color.
  final Color bufferingIndicatorColor;

  /// 缓冲进度文字颜色 / Buffering percent label color.
  final Color bufferingTextColor;

  /// 缓冲进度文字样式；为 null 时用 [bufferingTextColor] + 默认字号 / Optional buffering label style.
  final TextStyle? bufferingTextStyle;

  /// 铺满模式适应图标 / Icon for fit mode.
  final IconData fitScreenIcon;

  /// 铺满模式铺满图标 / Icon for fill mode.
  final IconData fillScreenIcon;

  /// 铺满模式拉伸图标 / Icon for stretch mode.
  final IconData stretchScreenIcon;

  @override
  VideoControlsTheme copyWith({
    Color? iconColor,
    Color? activeIconColor,
    Color? activeTrackColor,
    Color? inactiveTrackColor,
    Color? bufferedTrackColor,
    Color? thumbColor,
    Color? textColor,
    Color? backgroundColor,
    double? primaryIconSize,
    double? secondaryIconSize,
    double? centerButtonSize,
    EdgeInsets? barPadding,
    double? borderRadius,
    Color? bufferingScrimColor,
    Color? bufferingIndicatorColor,
    Color? bufferingTextColor,
    TextStyle? bufferingTextStyle,
    IconData? fitScreenIcon,
    IconData? fillScreenIcon,
    IconData? stretchScreenIcon,
  }) {
    return VideoControlsTheme(
      iconColor: iconColor ?? this.iconColor,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      activeTrackColor: activeTrackColor ?? this.activeTrackColor,
      inactiveTrackColor: inactiveTrackColor ?? this.inactiveTrackColor,
      bufferedTrackColor: bufferedTrackColor ?? this.bufferedTrackColor,
      thumbColor: thumbColor ?? this.thumbColor,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      primaryIconSize: primaryIconSize ?? this.primaryIconSize,
      secondaryIconSize: secondaryIconSize ?? this.secondaryIconSize,
      centerButtonSize: centerButtonSize ?? this.centerButtonSize,
      barPadding: barPadding ?? this.barPadding,
      borderRadius: borderRadius ?? this.borderRadius,
      bufferingScrimColor: bufferingScrimColor ?? this.bufferingScrimColor,
      bufferingIndicatorColor:
          bufferingIndicatorColor ?? this.bufferingIndicatorColor,
      bufferingTextColor: bufferingTextColor ?? this.bufferingTextColor,
      bufferingTextStyle: bufferingTextStyle ?? this.bufferingTextStyle,
      fitScreenIcon: fitScreenIcon ?? this.fitScreenIcon,
      fillScreenIcon: fillScreenIcon ?? this.fillScreenIcon,
      stretchScreenIcon: stretchScreenIcon ?? this.stretchScreenIcon,
    );
  }

  @override
  VideoControlsTheme lerp(ThemeExtension<VideoControlsTheme>? other, double t) {
    if (other is! VideoControlsTheme) {
      return this;
    }

    return VideoControlsTheme(
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      activeIconColor: Color.lerp(activeIconColor, other.activeIconColor, t)!,
      activeTrackColor: Color.lerp(activeTrackColor, other.activeTrackColor, t)!,
      inactiveTrackColor: Color.lerp(
        inactiveTrackColor,
        other.inactiveTrackColor,
        t,
      )!,
      bufferedTrackColor: Color.lerp(
        bufferedTrackColor,
        other.bufferedTrackColor,
        t,
      )!,
      thumbColor: Color.lerp(thumbColor, other.thumbColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      primaryIconSize: lerpDouble(primaryIconSize, other.primaryIconSize, t)!,
      secondaryIconSize: lerpDouble(
        secondaryIconSize,
        other.secondaryIconSize,
        t,
      )!,
      centerButtonSize: lerpDouble(centerButtonSize, other.centerButtonSize, t)!,
      barPadding: EdgeInsets.lerp(barPadding, other.barPadding, t)!,
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t)!,
      bufferingScrimColor: Color.lerp(
        bufferingScrimColor,
        other.bufferingScrimColor,
        t,
      )!,
      bufferingIndicatorColor: Color.lerp(
        bufferingIndicatorColor,
        other.bufferingIndicatorColor,
        t,
      )!,
      bufferingTextColor: Color.lerp(
        bufferingTextColor,
        other.bufferingTextColor,
        t,
      )!,
      bufferingTextStyle: TextStyle.lerp(
        bufferingTextStyle,
        other.bufferingTextStyle,
        t,
      ),
      fitScreenIcon: t < 0.5 ? fitScreenIcon : other.fitScreenIcon,
      fillScreenIcon: t < 0.5 ? fillScreenIcon : other.fillScreenIcon,
      stretchScreenIcon: t < 0.5 ? stretchScreenIcon : other.stretchScreenIcon,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VideoControlsTheme &&
        other.iconColor == iconColor &&
        other.activeIconColor == activeIconColor &&
        other.activeTrackColor == activeTrackColor &&
        other.inactiveTrackColor == inactiveTrackColor &&
        other.bufferedTrackColor == bufferedTrackColor &&
        other.thumbColor == thumbColor &&
        other.textColor == textColor &&
        other.backgroundColor == backgroundColor &&
        other.primaryIconSize == primaryIconSize &&
        other.secondaryIconSize == secondaryIconSize &&
        other.centerButtonSize == centerButtonSize &&
        other.barPadding == barPadding &&
        other.borderRadius == borderRadius &&
        other.bufferingScrimColor == bufferingScrimColor &&
        other.bufferingIndicatorColor == bufferingIndicatorColor &&
        other.bufferingTextColor == bufferingTextColor &&
        other.bufferingTextStyle == bufferingTextStyle &&
        other.fitScreenIcon == fitScreenIcon &&
        other.fillScreenIcon == fillScreenIcon &&
        other.stretchScreenIcon == stretchScreenIcon;
  }

  @override
  int get hashCode => Object.hashAll([
    iconColor,
    activeIconColor,
    activeTrackColor,
    inactiveTrackColor,
    bufferedTrackColor,
    thumbColor,
    textColor,
    backgroundColor,
    primaryIconSize,
    secondaryIconSize,
    centerButtonSize,
    barPadding,
    borderRadius,
    bufferingScrimColor,
    bufferingIndicatorColor,
    bufferingTextColor,
    bufferingTextStyle,
    fitScreenIcon,
    fillScreenIcon,
    stretchScreenIcon,
  ]);
}
