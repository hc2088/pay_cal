import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _ruleNavy = Color(0xFF18324B);
const Color _ruleTeal = Color(0xFF1D9A8A);
const Color _ruleLine = Color(0xFFE7EDF3);

Future<void> showRulePreviewDialog(
  BuildContext context, {
  required String title,
  required String assetPath,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _RulePreviewDialog(title: title, assetPath: assetPath),
  );
}

class _RulePreviewDialog extends StatefulWidget {
  const _RulePreviewDialog({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  State<_RulePreviewDialog> createState() => _RulePreviewDialogState();
}

class _RulePreviewDialogState extends State<_RulePreviewDialog> {
  late final Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = rootBundle.loadString(widget.assetPath);
  }

  Future<void> _openLink(String? href) async {
    final Uri? uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开参考链接')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开参考链接')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final ThemeData theme = Theme.of(context);
    final MarkdownStyleSheet
    style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      h1: const TextStyle(
        color: _ruleNavy,
        fontSize: 21,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
      h2: const TextStyle(
        color: _ruleNavy,
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w800,
      ),
      h3: const TextStyle(
        color: _ruleNavy,
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      p: const TextStyle(color: Color(0xFF4A5D70), fontSize: 13, height: 1.6),
      listBullet: const TextStyle(color: _ruleTeal, fontSize: 13),
      tableHead: const TextStyle(
        color: _ruleNavy,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      tableBody: const TextStyle(color: Color(0xFF4A5D70), fontSize: 12),
      tableBorder: TableBorder.all(
        color: _ruleLine,
        borderRadius: BorderRadius.circular(8),
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFEAF7F4),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: _ruleTeal, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      a: const TextStyle(
        color: _ruleTeal,
        decoration: TextDecoration.underline,
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _ruleLine)),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenSize.height * 0.84,
        ),
        child: SizedBox(
          width: screenSize.width,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.rule_rounded, color: _ruleTeal, size: 21),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: _ruleNavy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF718195),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _ruleLine),
              Expanded(
                child: FutureBuilder<String>(
                  future: _document,
                  builder:
                      (BuildContext context, AsyncSnapshot<String> snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('规则说明暂时无法加载。'),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final List<String> lines = snapshot.data!.split('\n');
                        if (lines.isNotEmpty && lines.first.startsWith('# ')) {
                          lines.removeAt(0);
                          if (lines.isNotEmpty && lines.first.trim().isEmpty) {
                            lines.removeAt(0);
                          }
                        }
                        return Markdown(
                          data: lines.join('\n'),
                          selectable: true,
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                          styleSheet: style,
                          onTapLink: (String text, String? href, String title) {
                            unawaited(_openLink(href));
                          },
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
