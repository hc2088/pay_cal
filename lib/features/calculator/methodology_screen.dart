import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _navy = Color(0xFF18324B);
const Color _teal = Color(0xFF1D9A8A);
const Color _line = Color(0xFFE7EDF3);
const Color _page = Color(0xFFF3F6FA);

class MethodologyScreen extends StatefulWidget {
  const MethodologyScreen({super.key});

  @override
  State<MethodologyScreen> createState() => _MethodologyScreenState();
}

class _MethodologyScreenState extends State<MethodologyScreen> {
  late final Future<String> _guide = rootBundle.loadString('doc/薪酬算法说明.md');

  Future<void> _openLink(String? href) async {
    if (href == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(href);
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
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        foregroundColor: _navy,
        title: const Text(
          '算法说明',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double contentWidth = constraints.maxWidth > 900
                ? 820
                : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: FutureBuilder<String>(
                  future: _guide,
                  builder:
                      (BuildContext context, AsyncSnapshot<String> snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('说明文档暂时无法加载，请稍后重试。'),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final ThemeData theme = Theme.of(context);
                        final MarkdownStyleSheet style =
                            MarkdownStyleSheet.fromTheme(theme).copyWith(
                              h1: const TextStyle(
                                color: _navy,
                                fontSize: 27,
                                height: 1.28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              h2: const TextStyle(
                                color: _navy,
                                fontSize: 20,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                              h3: const TextStyle(
                                color: _navy,
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                              p: const TextStyle(
                                color: Color(0xFF4A5D70),
                                fontSize: 14,
                                height: 1.65,
                              ),
                              tableHead: const TextStyle(
                                color: _navy,
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                              tableBody: const TextStyle(
                                color: Color(0xFF4A5D70),
                                fontSize: 12,
                                height: 1.45,
                              ),
                              tableBorder: TableBorder.all(
                                color: _line,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              tableCellsPadding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 8,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: const Color(0xFFEAF7F4),
                                borderRadius: BorderRadius.circular(12),
                                border: const Border(
                                  left: BorderSide(color: _teal, width: 3),
                                ),
                              ),
                              blockquotePadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              code: const TextStyle(
                                color: _navy,
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                                backgroundColor: Color(0xFFEFF3F7),
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: const Color(0xFFF1F5F8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _line),
                              ),
                              horizontalRuleDecoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: _line)),
                              ),
                              a: const TextStyle(
                                color: _teal,
                                decoration: TextDecoration.underline,
                              ),
                            );

                        return Markdown(
                          data: snapshot.data!,
                          selectable: true,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                          styleSheet: style,
                          onTapLink: (String text, String? href, String title) {
                            unawaited(_openLink(href));
                          },
                        );
                      },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
