import 'package:material_ui/material_ui.dart';

import '../theme/video_controls_theme.dart';

/// Overlay popup anchored to a chrome control, without third-party menus /
/// 锚定在控件上的 Overlay 弹层，不依赖第三方菜单包.
class ChromePopupButton extends StatefulWidget {
  /// Creates a chrome popup / 创建控件弹层按钮.
  const ChromePopupButton({
    super.key,
    required this.theme,
    required this.menuBuilder,
    required this.buttonBuilder,
  });

  final VideoControlsTheme theme;
  final Widget Function(BuildContext context, VoidCallback hideMenu)
  menuBuilder;
  final Widget Function(BuildContext context, VoidCallback showMenu)
  buttonBuilder;

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

  void _show() {
    if (_open) {
      _removeOverlay();
      return;
    }
    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 56),
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.theme.backgroundColor,
                      borderRadius: BorderRadius.circular(
                        widget.theme.borderRadius == 0
                            ? 8
                            : widget.theme.borderRadius,
                      ),
                    ),
                    child: widget.menuBuilder(context, _removeOverlay),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.buttonBuilder(context, _show);
  }
}
