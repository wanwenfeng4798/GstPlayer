import 'package:material_ui/material_ui.dart';

import '../theme/video_controls_theme.dart';

/// Whether the popup sits above or below the chrome control /
/// 弹层在控件上方还是下方.
enum ChromePopupSide {
  /// Above the control (bottom chrome) / 控件上方（底栏）.
  above,

  /// Below the control (top bar) / 控件下方（顶栏）.
  below,
}

/// Overlay popup anchored to a chrome control, without third-party menus /
/// 锚定在控件上的 Overlay 弹层，不依赖第三方菜单包.
class ChromePopupButton extends StatefulWidget {
  /// Creates a chrome popup / 创建控件弹层按钮.
  const ChromePopupButton({
    super.key,
    required this.theme,
    required this.menuBuilder,
    required this.buttonBuilder,
    this.side = ChromePopupSide.above,
    this.decorate = true,
  });

  final VideoControlsTheme theme;
  final Widget Function(BuildContext context, VoidCallback hideMenu)
  menuBuilder;
  final Widget Function(BuildContext context, VoidCallback showMenu)
  buttonBuilder;

  /// Popup placement relative to the control / 相对控件的弹出方向.
  final ChromePopupSide side;

  /// Wrap [menuBuilder] in the chrome background / 是否包一层底栏背景.
  final bool decorate;

  @override
  State<ChromePopupButton> createState() => _ChromePopupButtonState();
}

class _ChromePopupButtonState extends State<ChromePopupButton> {
  OverlayEntry? _entry;
  bool _open = false;

  @override
  void dispose() {
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _removeOverlay({bool notify = true}) {
    _entry?.remove();
    _entry = null;
    if (_open) {
      _open = false;
      if (notify && mounted) setState(() {});
    }
  }

  Rect _buttonRectInOverlay(OverlayState overlay) {
    final box = context.findRenderObject() as RenderBox;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return origin & box.size;
  }

  void _show() {
    if (_open) {
      _removeOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    final buttonRect = _buttonRectInOverlay(overlay);
    _entry = OverlayEntry(
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _removeOverlay,
                  ),
                ),
                CustomSingleChildLayout(
                  delegate: _ChromePopupLayoutDelegate(
                    buttonRect: buttonRect,
                    side: widget.side,
                    overlaySize: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: widget.decorate
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.theme.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                widget.theme.borderRadius == 0
                                    ? 8
                                    : widget.theme.borderRadius,
                              ),
                            ),
                            child: widget.menuBuilder(context, _removeOverlay),
                          )
                        : widget.menuBuilder(context, _removeOverlay),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    overlay.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.buttonBuilder(context, _show);
  }
}

class _ChromePopupLayoutDelegate extends SingleChildLayoutDelegate {
  _ChromePopupLayoutDelegate({
    required this.buttonRect,
    required this.side,
    required this.overlaySize,
  });

  final Rect buttonRect;
  final ChromePopupSide side;
  final Size overlaySize;

  static const _gap = 8.0;
  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = (overlaySize.width - _margin * 2).clamp(0.0, double.infinity);
    final maxH = (overlaySize.height - _margin * 2).clamp(0.0, double.infinity);
    return BoxConstraints(maxWidth: maxW, maxHeight: maxH);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = buttonRect.center.dx - childSize.width / 2;
    var y = side == ChromePopupSide.above
        ? buttonRect.top - _gap - childSize.height
        : buttonRect.bottom + _gap;
    x = _clamp(x, _margin, overlaySize.width - childSize.width - _margin);
    y = _clamp(y, _margin, overlaySize.height - childSize.height - _margin);
    return Offset(x, y);
  }

  static double _clamp(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max);
  }

  @override
  bool shouldRelayout(covariant _ChromePopupLayoutDelegate oldDelegate) {
    return buttonRect != oldDelegate.buttonRect ||
        side != oldDelegate.side ||
        overlaySize != oldDelegate.overlaySize;
  }
}
