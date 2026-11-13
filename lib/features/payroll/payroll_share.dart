import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/gallery_save_service.dart';
import 'payroll_widgets.dart';

bool _capturing = false;

Future<File> stagePayrollExport(List<int> bytes, String extension) async {
  final directory = Directory('${Directory.systemTemp.path}/payroll_exports');
  await directory.create(recursive: true);
  final cutoff = DateTime.now().subtract(const Duration(days: 1));
  // A share completion can mean that the receiving app was selected, not that
  // it has finished reading. Only clean up older exports on a later action.
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is! File) continue;
    try {
      if ((await entry.stat()).modified.isBefore(cutoff)) await entry.delete();
    } on FileSystemException {
      // Cache cleanup must not prevent a new export.
    }
  }
  final file = File(
    '${directory.path}/payroll_${DateTime.now().microsecondsSinceEpoch}.$extension',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<void> previewPayrollImage(BuildContext context, Widget content) async {
  if (_capturing) return;
  _capturing = true;
  try {
    const exportWidth = 380.0;
    final export = InheritedTheme.captureAll(
      context,
      MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: exportWidth,
              child: Padding(padding: const EdgeInsets.all(20), child: content),
            ),
          ),
        ),
      ),
    );
    var pixelRatio = 2.0;
    Uint8List? bytes;
    for (var attempt = 0; attempt < 3; attempt++) {
      bytes = await ScreenshotController().captureFromLongWidget(
        export,
        context: context,
        pixelRatio: pixelRatio,
        delay: const Duration(milliseconds: 100),
        constraints: const BoxConstraints.tightFor(width: exportWidth),
      );
      // Some renderers clamp oversized long images while clipping their paint.
      // Detect the PNG width reduction and recapture below that texture limit.
      final actualWidth = ByteData.sublistView(bytes).getUint32(16);
      if (actualWidth >= (exportWidth * pixelRatio).floor()) break;
      if (attempt == 2 || actualWidth == 0) {
        throw StateError('导出图片超过设备绘制范围');
      }
      pixelRatio = actualWidth / exportWidth * .98;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => _ImagePreview(bytes: bytes!)),
    );
  } catch (_) {
    if (context.mounted) showMessage(context, '图片生成失败，请重试。');
  } finally {
    _capturing = false;
  }
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({required this.bytes});
  final Uint8List bytes;
  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  bool busy = false;
  Future<void> _export(BuildContext context, bool gallery) async {
    if (busy) return;
    setState(() => busy = true);
    File? file;
    try {
      file = await stagePayrollExport(widget.bytes, 'png');
      if (gallery) {
        if (!context.mounted) return;
        await saveImageToGallery(context, file.path);
      } else {
        if (!context.mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (_) {
      if (context.mounted) showMessage(context, '保存或分享失败，可重试或选择另一种方式。');
    } finally {
      if (gallery && file != null) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Export cache cleanup must not leave the save/share buttons disabled.
        }
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('分享预览')),
    body: InteractiveViewer(
      minScale: .4,
      maxScale: 4,
      child: SingleChildScrollView(
        child: Image.memory(
          widget.bytes,
          width: MediaQuery.sizeOf(context).width,
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : () => _export(context, true),
              icon: const Icon(Icons.download_outlined),
              label: const Text('保存相册'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : () => _export(context, false),
              icon: const Icon(Icons.ios_share),
              label: const Text('系统分享'),
            ),
          ],
        ),
      ),
    ),
  );
}
