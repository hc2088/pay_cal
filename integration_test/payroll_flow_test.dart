import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pay_cal/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pay_cal/application/payroll_controller.dart';
import 'package:pay_cal/data/city_catalog.dart';
import 'package:pay_cal/data/payroll_store.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/features/payroll/payroll_results_screen.dart';
import 'package:pay_cal/features/payroll/plans_screen.dart';
import 'package:pay_cal/features/payroll/monthly_details_screen.dart';
import 'package:pay_cal/features/payroll/payroll_result_widgets.dart';
import 'package:pay_cal/features/payroll/plan_comparison_table.dart';
import 'package:pay_cal/features/calculator/methodology_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('salary to saved plans and comparison on device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await PayrollStore.open(
      databasePath: 'payroll_ui_test_${newId()}.db',
    );
    final c = PayrollController(
      store: store,
      catalog: await CityCatalog.load(),
      prefs: await SharedPreferences.getInstance(),
    );
    await c.initialize();
    await tester.pumpWidget(
      SalaryCalculatorApp(controllerLoader: () async => c),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('v2-home');
    expect(find.text('北京 ▾'), findsOneWidget);
    // Match the supplied screenshots in this isolated test draft. Their sample
    // excludes the medical fixed fee; the city's production defaults stay intact.
    c.update(
      c.draft.copyWith(
        deduction: '5000',
        overrides: {
          'med': c.draft.city.items
              .firstWhere((item) => item.kind == 'med')
              .copyWith(employeeFixed: 0, overridden: true),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '税前月薪',
      ),
      '33000',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('v2-home-configured');
    await tester.tap(find.text('调整 ›'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('v2-contributions');
    await tester.tap(find.text('养老保险'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(
        find.byKey(const ValueKey('contribution-pension-employeeRate')),
      ),
      alignment: .3,
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('v2-contributions-expanded');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('estimate-confirmation')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('estimate-confirmation')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('calculate')));
    await tester.tap(find.byKey(const Key('calculate')));
    await tester.pumpAndSettle();
    expect(find.byType(PayrollResultsScreen), findsOneWidget);
    expect(find.text('税后年薪'), findsOneWidget);
    expect(c.results.single.sum('net'), 28644000);
    await binding.takeScreenshot('v2-results');
    Future<void> reveal(Finder finder, {double delta = 250}) async {
      await tester.scrollUntilVisible(
        finder,
        delta,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 100,
      );
      await Scrollable.ensureVisible(tester.element(finder), alignment: .15);
      await tester.pumpAndSettle();
    }

    await reveal(find.byKey(const Key('result-annual-total-income')));
    expect(find.text('年度总收入'), findsOneWidget);
    expect(find.text('¥421,080.00'), findsOneWidget);
    await binding.takeScreenshot('v2-annual-total-income');
    await reveal(find.byKey(const Key('more-months')));
    await binding.takeScreenshot('v2-results-summary');
    expect(find.byKey(const ValueKey('month-income-2')), findsNothing);
    await tester.tap(find.byKey(const Key('more-months')));
    await tester.pumpAndSettle();
    expect(find.byType(MonthlyDetailsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('month-total-1')), findsOneWidget);
    expect(find.text('¥36,327.75'), findsWidgets);
    await binding.takeScreenshot('v2-months');
    await reveal(find.byKey(const ValueKey('month-income-1')));
    await tester.tap(find.byKey(const ValueKey('month-income-1')));
    await tester.pumpAndSettle();
    expect(find.byType(MonthDetailSheet), findsOneWidget);
    expect(find.text('¥25,107.75'), findsOneWidget);
    await binding.takeScreenshot('v2-month-detail');
    await reveal(find.byKey(const Key('month-total-section')));
    await binding.takeScreenshot('v2-month-total');
    await reveal(find.byKey(const Key('month-housing-section')));
    await binding.takeScreenshot('v2-month-housing');
    await reveal(find.byKey(const Key('month-tax-section')));
    await binding.takeScreenshot('v2-month-tax');
    await reveal(find.byKey(const Key('month-tax-basis-section')));
    await binding.takeScreenshot('v2-month-tax-basis');
    await tester.tap(find.byTooltip('关闭明细'));
    await tester.pumpAndSettle();
    await reveal(find.byKey(const ValueKey('month-income-12')));
    await tester.tap(find.byKey(const ValueKey('month-income-12')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MonthDetailSheet>(find.byType(MonthDetailSheet))
          .month
          .month,
      12,
    );
    await tester.tap(find.byTooltip('关闭明细'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final key in ['social', 'housing', 'company']) {
      final card = find.byKey(ValueKey('result-$key-0'));
      await reveal(card);
      final tile = find
          .descendant(of: card, matching: find.byType(ListTile))
          .first;
      await tester.tap(tile);
      await tester.pumpAndSettle();
      if (key == 'housing') {
        await reveal(find.byType(HousingContributionDetails));
      }
      await binding.takeScreenshot('v2-result-$key');
    }
    await reveal(find.byKey(const Key('result-unit-total-cost')));
    expect(find.text('单位总成本'), findsOneWidget);
    expect(find.text('¥548,460.00 / 年'), findsOneWidget);
    expect(find.text('年度公司总支出'), findsNothing);
    await binding.takeScreenshot('v2-unit-total-cost');
    await reveal(find.byKey(const Key('result-parameters')));
    await binding.takeScreenshot('v2-result-parameters');
    await reveal(find.text('计算说明'));
    await tester.tap(find.text('计算说明'));
    await tester.pumpAndSettle();
    await reveal(find.text('年度税后工资'));
    await binding.takeScreenshot('v2-annual-net');
    await reveal(find.text('全年综合所得收入额'));
    await binding.takeScreenshot('v2-annual-tax-base');
    await reveal(find.byKey(const Key('annual-tax-help')));
    await binding.takeScreenshot('v2-annual-tax');
    expect(
      find.text('¥186,900.00 × 20% − ¥16,920.00 = ¥20,460.00'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('annual-tax-help')));
    await tester.pumpAndSettle();
    expect(find.byType(MethodologyScreen), findsOneWidget);
    expect(find.byKey(const Key('annual-tax-rate-table')), findsOneWidget);
    await binding.takeScreenshot('v2-tax-rates');
    await tester.tap(find.text('完整说明'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.text('说明文档暂时无法加载，请稍后重试。'), findsNothing);
    await binding.takeScreenshot('v2-methodology');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分享结果'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('分享预览'), findsOneWidget);
    await binding.takeScreenshot('v2-share-preview');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    await binding.takeScreenshot('v2-share-parameters');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final a = c.results.single;
    await c.saveResult(a, '方案 A · 北京');
    c.update(c.draft.copyWith(salary: '36000'));
    final b = c.calculate().single;
    await c.saveResult(b, '方案 B · 北京');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('方案').last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('v2-plans');
    for (final name in ['方案 A · 北京', '方案 B · 北京']) {
      final plan = c.plans.firstWhere((p) => p.name == name);
      final checkbox = find.byKey(ValueKey('select-plan-${plan.id}'));
      await reveal(checkbox, delta: name.startsWith('方案 A') ? 300 : -300);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('开始对比'));
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonScreen), findsOneWidget);
    expect(find.byKey(const Key('comparison-header')), findsOneWidget);
    expect(find.text('更多缴费与规则'), findsNothing);
    await binding.takeScreenshot('v2-comparison');
    await reveal(find.text('【月】单位成本'));
    await binding.takeScreenshot('v2-comparison-monthly');
    await reveal(find.text('【月】养老保险缴纳基数'));
    await binding.takeScreenshot('v2-comparison-rules');
    await tester.tap(find.byKey(const Key('comparison-month')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('12 月明细').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 月明细').last);
    await tester.pumpAndSettle();
    await reveal(find.text('【月】单位成本'), delta: -350);
    await binding.takeScreenshot('v2-comparison-december');
    final currentTable = tester.widget<PlanComparisonTable>(
      find.byKey(const Key('comparison-overview')),
    );
    expect(
      currentTable.rows.firstWhere((r) => r.label == '【月】个税').left,
      '3,115.00',
    );
    await tester.tap(find.byTooltip('交换 A / B'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PlanComparisonTable>(
            find.byKey(const Key('comparison-header')),
          )
          .first
          .name,
      '方案 B · 北京',
    );
    await tester.tap(find.byTooltip('交换 A / B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('只看差异'));
    await tester.pumpAndSettle();
    await reveal(find.text('【年】税前工资'), delta: -300);
    await binding.takeScreenshot('v2-comparison-differences');
    await tester.tap(find.text('只看差异'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分享比较'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('分享预览'), findsOneWidget);
    await binding.takeScreenshot('v2-comparison-share');
    final image = tester.widget<Image>(find.byType(Image));
    final bytes = (image.image as MemoryImage).bytes;
    final header = ByteData.sublistView(bytes);
    debugPrint(
      'Comparison image ${header.getUint32(16)} x ${header.getUint32(20)}; widget ${tester.getSize(find.byType(Image))}; viewport ${MediaQuery.sizeOf(tester.element(find.byType(Image)))}',
    );
    expect(tester.takeException(), null);
    await c.flush();
    await tester.pumpWidget(const SizedBox());
    await store.db.close();
  });
}
