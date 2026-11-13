import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pay_cal/features/payroll/payroll_share.dart';

/// Uses real native plugins. On iOS, respond to the system Photos prompt.
/// Run with GALLERY_EXPECT_DENIED=true after denying access in device settings
/// to verify that the same preview remains usable after a refusal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const denied = bool.fromEnvironment('GALLERY_EXPECT_DENIED');
  testWidgets('preview saves through the native gallery permission flow', (
    tester,
  ) async {
    Future<void> waitFor(Finder finder) async {
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(finder, findsOneWidget);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('相册保存验证')),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => previewPayrollImage(
                context,
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('薪酬测算 · 相册保存验证'),
                    SizedBox(height: 20),
                    Text('测试图片，不包含个人薪资数据'),
                    SizedBox(height: 80),
                    Icon(Icons.check_circle, color: Colors.blue, size: 60),
                  ],
                ),
              ),
              child: const Text('生成预览'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成预览'));
    await waitFor(find.text('分享预览'));
    await tester.pumpAndSettle();
    expect(find.text('分享预览'), findsOneWidget);

    await tester.tap(find.text('保存相册'));
    if (denied) {
      await waitFor(find.text('未获得相册保存权限'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('已保存到相册'), findsNothing);
      // Denial must release the preview's busy state so it can be retried.
      await tester.tap(find.text('保存相册'));
      await waitFor(find.text('未获得相册保存权限'));
      await tester.tap(find.text('取消'));
    } else {
      await waitFor(find.text('已保存到相册'));
      expect(find.text('未获得相册保存权限'), findsNothing);
    }
    await tester.pumpAndSettle();
    final save = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '保存相册'),
    );
    expect(save.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
