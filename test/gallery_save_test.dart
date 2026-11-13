import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_cal/services/gallery_save_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const galChannel = MethodChannel('gal');
  const settingsChannel = MethodChannel('pay_cal/app_settings');
  late List<MethodCall> calls;
  late bool granted;
  late bool grantOnRequest;
  late bool settingsOpened;
  String? saveError;
  bool? saved;
  late int settingsCalls;

  setUp(() {
    calls = [];
    granted = false;
    grantOnRequest = false;
    settingsOpened = true;
    settingsCalls = 0;
    saveError = null;
    saved = null;
    messenger.setMockMethodCallHandler(galChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'hasAccess':
          return granted;
        case 'requestAccess':
          granted = granted || grantOnRequest;
          return granted;
        case 'putImage':
          if (saveError != null) throw PlatformException(code: saveError!);
          return null;
        default:
          throw MissingPluginException();
      }
    });
    messenger.setMockMethodCallHandler(settingsChannel, (call) async {
      expect(call.method, 'open');
      settingsCalls++;
      return settingsOpened;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(galChannel, null);
    messenger.setMockMethodCallHandler(settingsChannel, null);
  });

  Future<void> render(WidgetTester tester, {String? album}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await saveImageToGallery(
                  context,
                  '/test/payroll.png',
                  album: album,
                );
              },
              child: const Text('保存相册'),
            ),
          ),
        ),
      ),
    );
    // Mounting a page alone must not ask for permission.
    expect(calls, isEmpty);
    await tester.tap(find.text('保存相册'));
    await tester.pumpAndSettle();
  }

  void galleryTest(
    String description,
    WidgetTesterCallback body, {
    TargetPlatform platform = TargetPlatform.iOS,
  }) => testWidgets(
    description,
    body,
    variant: TargetPlatformVariant.only(platform),
  );

  galleryTest('first iOS save requests add-only access and writes once', (
    tester,
  ) async {
    grantOnRequest = true;
    await render(tester);
    expect(saved, true);
    expect(calls.first.method, 'hasAccess');
    expect(calls[1].method, 'requestAccess');
    expect(
      calls.where((c) => c.method != 'putImage').map((c) => c.arguments),
      everyElement({'toAlbum': false}),
    );
    expect(calls.where((c) => c.method == 'putImage'), hasLength(1));
    expect(find.text('已保存到相册'), findsOneWidget);
    expect(settingsCalls, 0);
  });

  galleryTest('authorized save and named-album permission match', (
    tester,
  ) async {
    granted = true;
    await render(tester, album: '薪酬测算');
    expect(saved, true);
    expect(calls.first.arguments, {'toAlbum': true});
    expect(calls.last.arguments, {
      'path': '/test/payroll.png',
      'album': '薪酬测算',
    });
    expect(find.byType(AlertDialog), findsNothing);
  });

  galleryTest(
    'Android checks legacy storage including API 29 before writing',
    (tester) async {
      await render(tester);
      expect(calls.map((c) => c.method), ['hasAccess', 'requestAccess']);
      expect(calls.map((c) => c.arguments), everyElement({'toAlbum': true}));
      expect(find.textContaining('存储权限'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(saved, false);
      expect(settingsCalls, 0);
    },
    platform: TargetPlatform.android,
  );

  galleryTest('denial can be cancelled without writing or opening settings', (
    tester,
  ) async {
    await render(tester);
    expect(find.text('未获得相册保存权限'), findsOneWidget);
    expect(find.textContaining('允许添加照片'), findsOneWidget);
    expect(calls.any((c) => c.method == 'putImage'), false);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(find.text('已保存到相册'), findsNothing);
    expect(settingsCalls, 0);
  });

  galleryTest('settings route allows a fresh permission check on retry', (
    tester,
  ) async {
    await render(tester);
    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();
    expect(settingsCalls, 1);
    expect(saved, false);
    expect(calls.any((c) => c.method == 'putImage'), false);
    // Simulate allowing access in Settings and returning to the same preview.
    granted = true;
    calls.clear();
    await tester.tap(find.text('保存相册'));
    await tester.pumpAndSettle();
    expect(calls.first.method, 'hasAccess');
    expect(saved, true);
    expect(find.text('已保存到相册'), findsOneWidget);
  });

  galleryTest('unavailable settings offers manual instructions', (
    tester,
  ) async {
    settingsOpened = false;
    await render(tester);
    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(find.textContaining('请手动进入系统设置'), findsOneWidget);
  });

  galleryTest('native access denial after check also offers settings', (
    tester,
  ) async {
    granted = true;
    saveError = 'ACCESS_DENIED';
    await render(tester);
    expect(find.text('未获得相册保存权限'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(find.text('已保存到相册'), findsNothing);
  });

  for (final error in {
    'NOT_ENOUGH_SPACE': '设备存储空间不足，请清理空间后重新保存。',
    'NOT_SUPPORTED_FORMAT': '图片格式不受支持，请返回后重新生成图片。',
    'UNEXPECTED': '保存到相册失败，请重试或使用系统分享。',
  }.entries) {
    galleryTest(
      '${error.key} reports the actual failure without permission UI',
      (tester) async {
        granted = true;
        saveError = error.key;
        await render(tester);
        expect(saved, false);
        expect(find.text(error.value), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('已保存到相册'), findsNothing);
        expect(settingsCalls, 0);
      },
    );
  }
}
