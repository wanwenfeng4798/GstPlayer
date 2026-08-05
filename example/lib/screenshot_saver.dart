import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Saves screenshot PNG bytes: gallery via [Gal] on supported platforms,
/// or the app documents directory on Linux.
Future<void> saveScreenshotPng(
  BuildContext context,
  Uint8List pngBytes,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    if (Platform.isLinux) {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/gstplayer_screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(pngBytes, flush: true);
      messenger?.showSnackBar(
        SnackBar(content: Text('已保存到文档目录: $path')),
      );
      return;
    }

    // Android / iOS / macOS / Windows — system gallery via gal.
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('需要相册权限才能保存截图')),
        );
        return;
      }
    }

    await Gal.putImageBytes(pngBytes, name: 'gstplayer_screenshot');
    messenger?.showSnackBar(
      const SnackBar(content: Text('已保存到相册')),
    );
  } on GalException catch (e) {
    debugPrint('saveScreenshotPng GalException: ${e.type}');
    messenger?.showSnackBar(
      SnackBar(content: Text('保存失败: ${e.type}')),
    );
  } catch (e) {
    debugPrint('saveScreenshotPng: $e');
    messenger?.showSnackBar(
      SnackBar(content: Text('保存失败: $e')),
    );
  }
}
