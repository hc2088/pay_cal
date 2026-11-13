import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

const _settingsChannel = MethodChannel('pay_cal/app_settings');

/// Called only after the user chooses to save a generated image.
Future<bool> saveImageToGallery(
  BuildContext context,
  String path, {
  String? album,
  String successMessage = '已保存到相册',
}) async {
  if (!context.mounted) return false;
  try {
    // Gal 2.3.3 writes legacy paths on Android 10, but its default access check
    // skips storage permission on that OS. toAlbum=true checks it correctly,
    // even without a named album. Android 11+ still requires no permission.
    // iOS keeps add-only access unless a named album actually needs reading.
    final toAlbum =
        album != null || defaultTargetPlatform == TargetPlatform.android;
    final allowed =
        await Gal.hasAccess(toAlbum: toAlbum) ||
        await Gal.requestAccess(toAlbum: toAlbum);
    if (!context.mounted) return false;
    if (!allowed) {
      await _explainGalleryPermission(context);
      return false;
    }
    await Gal.putImage(path, album: album);
    if (context.mounted) _message(context, successMessage);
    return true;
  } on GalException catch (error) {
    if (!context.mounted) return false;
    switch (error.type) {
      case GalExceptionType.accessDenied:
        await _explainGalleryPermission(context);
      case GalExceptionType.notEnoughSpace:
        _message(context, '设备存储空间不足，请清理空间后重新保存。');
      case GalExceptionType.notSupportedFormat:
        _message(context, '图片格式不受支持，请返回后重新生成图片。');
      case GalExceptionType.unexpected:
        _message(context, '保存到相册失败，请重试或使用系统分享。');
    }
  } catch (_) {
    if (context.mounted) {
      _message(context, '保存到相册失败，请重试或使用系统分享。');
    }
  }
  return false;
}

Future<void> _explainGalleryPermission(BuildContext context) async {
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('未获得相册保存权限'),
      content: Text(
        ios
            ? '请在系统设置中允许添加照片，返回后再次点击“保存相册”。'
            : '请在系统设置中允许保存照片所需的存储权限，返回后再次点击“保存相册”。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('去设置'),
        ),
      ],
    ),
  );
  if (openSettings != true || !context.mounted) return;
  var opened = false;
  try {
    opened = await _settingsChannel.invokeMethod<bool>('open') ?? false;
  } on PlatformException {
    // Some vendor ROMs may not expose an application settings activity.
  } on MissingPluginException {
    // Keep the manual route available on unsupported platforms.
  }
  if (!opened && context.mounted) {
    _message(
      context,
      ios
          ? '无法打开设置，请手动进入系统设置 → App → 薪酬测算 → 照片，允许添加照片。'
          : '无法打开设置，请手动进入系统设置 → 应用 → 薪酬测算 → 权限，允许保存照片。',
    );
  }
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
