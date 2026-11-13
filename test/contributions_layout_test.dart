import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_cal/data/city_catalog.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/features/payroll/payroll_widgets.dart';
import 'helpers/contributions_app.dart';
import 'helpers/field_visibility.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'all expanded contribution labels fit at ${scale * 100}% text',
      (tester) async {
        tester.view.physicalSize = scale == 1
            ? const Size(390, 844)
            : const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final catalog = (await tester.runAsync(CityCatalog.load))!;
        final draft = PayrollDraft(
          id: 'layout',
          city: catalog.beijing,
          year: 2026,
        );
        // Use the actual outline input theme; MaterialApp's default underline
        // decoration would hide the floating-label clipping regression.
        PayrollDraft? saved;
        await openContributions(
          tester,
          draft,
          textScale: scale,
          onSaved: (value) => saved = value,
        );
        expectFieldLabelVisible(tester, find.byType(AppBar), '五险一金设置');

        Future<void> reveal(Finder finder) async {
          await tester.scrollUntilVisible(
            finder,
            220,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
          await Scrollable.ensureVisible(
            tester.element(finder),
            alignment: .15,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
        }

        Future<void> checkField(Finder finder, String label) async {
          await reveal(finder);
          expectFieldLabelVisible(tester, finder, label);
        }

        for (final label in ['社保参考基数', '公积金参考基数']) {
          await checkField(
            find.byWidgetPredicate((w) => w is AmountField && w.label == label),
            label,
          );
        }
        for (final item in draft.city.items) {
          final title = find.text(item.label);
          await reveal(title);
          await tester.tap(title);
          await tester.pumpAndSettle();
          for (final entry in {
            'employeeRate': '个人比例',
            'employerRate': '单位比例',
            'actualBase': '本项实际基数',
          }.entries) {
            await checkField(
              find.byKey(ValueKey('contribution-${item.kind}-${entry.key}')),
              entry.value,
            );
          }
          final advanced = find.text('高级：基数边界、固定费用与舍入');
          await reveal(advanced);
          await tester.tap(advanced);
          await tester.pumpAndSettle();
          for (final entry in {
            'minBase': '自定义基数下限',
            'maxBase': '自定义基数上限',
            'employeeFixed': '个人固定费用',
            'employerFixed': '单位固定费用',
          }.entries) {
            await checkField(
              find.byKey(ValueKey('contribution-${item.kind}-${entry.key}')),
              entry.value,
            );
          }
          final rounding = find.byWidgetPredicate(
            (w) => w is LabeledField && w.label == '每方每项缴费舍入',
          );
          await checkField(rounding, '每方每项缴费舍入');
          final dropdown = find.descendant(
            of: rounding,
            matching: find.byType(DropdownButtonFormField<int>),
          );
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          await tester.tap(find.text('四舍五入到元').last);
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('${item.kind}-rounding-100')),
            findsOneWidget,
          );
          await reveal(title);
          await tester.tap(title);
          await tester.pumpAndSettle();
        }
        for (final label in ['已确认月税前扣除额', '单位应税福利 / 月']) {
          await checkField(
            find.byWidgetPredicate((w) => w is AmountField && w.label == label),
            label,
          );
        }
        await tester.tap(find.text('保存设置'));
        await tester.pumpAndSettle();
        expect(saved, isNotNull);
        expect(
          saved!.effectiveItems.every((item) => item.roundingUnit == 100),
          isTrue,
        );
      },
    );
  }

  testWidgets('focused and invalid values keep labels visible with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final catalog = (await tester.runAsync(CityCatalog.load))!;
    await openContributions(
      tester,
      PayrollDraft(id: 'focus', city: catalog.beijing, year: 2026),
    );
    await tester.scrollUntilVisible(
      find.text('养老保险'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('养老保险'));
    await tester.pumpAndSettle();
    final field = find.byKey(
      const ValueKey('contribution-pension-employeeRate'),
    );
    final input = find.descendant(of: field, matching: find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    for (final value in ['', '8.5', '-1']) {
      await tester.enterText(input, value);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(field), alignment: .15);
      await tester.pumpAndSettle();
      expectFieldLabelVisible(tester, field, '个人比例');
      expect(tester.takeException(), null);
    }
    expect(find.text('请输入有效的非负比例'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(input).label, contains('个人比例'));
    semantics.dispose();
  });
}
