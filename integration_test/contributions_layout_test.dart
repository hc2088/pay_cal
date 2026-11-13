import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pay_cal/data/city_catalog.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/features/payroll/payroll_widgets.dart';
import '../test/helpers/contributions_app.dart';
import '../test/helpers/field_visibility.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [1.0, 2.0]) {
    testWidgets('expanded fields remain visible at ${scale * 100}% text', (
      tester,
    ) async {
      final catalog = await CityCatalog.load();
      await openContributions(
        tester,
        PayrollDraft(
          id: 'layout-check-$scale',
          city: catalog.beijing,
          year: 2026,
        ),
        textScale: scale,
      );
      expectFieldLabelVisible(tester, find.byType(AppBar), '五险一金设置');
      await binding.convertFlutterSurfaceToImage();
      await tester.scrollUntilVisible(
        find.text('养老保险'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('养老保险'));
      await tester.pumpAndSettle();

      Future<void> captureField(String field, String name) async {
        final finder = find.byKey(ValueKey('contribution-pension-$field'));
        await Scrollable.ensureVisible(tester.element(finder), alignment: .2);
        await tester.pumpAndSettle();
        final label = tester.widget<AmountField>(finder).label;
        expectFieldLabelVisible(tester, finder, label);
        expect(tester.takeException(), null);
        await binding.takeScreenshot(
          'contributions-$name-${scale == 1 ? 'fixed' : 'large-text'}',
        );
      }

      await captureField('employeeRate', 'rates');
      final advanced = find.text('高级：基数边界、固定费用与舍入').first;
      await Scrollable.ensureVisible(tester.element(advanced), alignment: .2);
      await tester.pumpAndSettle();
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      await captureField('minBase', 'bounds');
      await captureField('employeeFixed', 'fees');
      final rounding = find.byWidgetPredicate(
        (w) => w is LabeledField && w.label == '每方每项缴费舍入',
      );
      await Scrollable.ensureVisible(tester.element(rounding), alignment: .4);
      await tester.pumpAndSettle();
      expectFieldLabelVisible(tester, rounding, '每方每项缴费舍入');
      expect(tester.takeException(), null);
    });
  }
}
