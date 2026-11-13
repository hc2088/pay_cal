import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay_cal/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pay_cal/application/payroll_controller.dart';
import 'package:pay_cal/data/city_catalog.dart';
import 'package:pay_cal/data/payroll_store.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/domain/payroll_engine.dart';
import 'package:pay_cal/domain/payroll_breakdown.dart';
import 'package:pay_cal/domain/payroll_comparison.dart';
import 'package:pay_cal/features/payroll/payroll_app.dart';
import 'package:pay_cal/features/payroll/payroll_results_screen.dart';
import 'package:pay_cal/features/payroll/plans_screen.dart';
import 'package:pay_cal/features/payroll/contributions_screen.dart';
import 'package:pay_cal/features/payroll/monthly_details_screen.dart';
import 'package:pay_cal/features/payroll/payroll_result_widgets.dart';
import 'package:pay_cal/features/payroll/plan_comparison_table.dart';
import 'package:pay_cal/features/payroll/payroll_widgets.dart';
import 'package:pay_cal/features/payroll/annual_tax_details.dart';
import 'package:pay_cal/features/calculator/methodology_screen.dart';
import 'package:pay_cal/features/calculator/tax_rate_guide.dart';
import 'fixtures/payroll_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late PayrollController c;
  late PayrollStore store;
  setUp(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      store = await PayrollStore.open(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: inMemoryDatabasePath,
      );
      c = PayrollController(
        store: _WidgetStore(store.db),
        catalog: await CityCatalog.load(),
        prefs: await SharedPreferences.getInstance(),
      );
      await c.initialize();
    });
  });
  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      await store.db.close();
    });
  });
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [payrollControllerProvider.overrideWith((ref) => c)],
        child: SalaryCalculatorApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'default Beijing, search city, cancel edits and explicit calculation',
    (tester) async {
      await mount(tester, const PayrollWorkspace());
      expect(find.text('北京 ▾'), findsOneWidget);
      final salary = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '税前月薪',
      );
      await tester.enterText(salary, '33000');
      await tester.pump();
      await tester.tap(find.text('北京 ▾'));
      await tester.pumpAndSettle();
      final search = find.byType(TextField);
      await tester.enterText(search, 'shanghai');
      await tester.pumpAndSettle();
      await tester.tap(find.text('上海'));
      await tester.pumpAndSettle();
      expect(c.draft.city.id, 'sh');
      expect(c.draft.salary, '33000');
      await tester.tap(find.text('调整 ›'));
      await tester.pumpAndSettle();
      expect(find.text('五险一金设置'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(c.draft.overrides, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const Key('estimate-confirmation')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('estimate-confirmation')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('calculate')));
      await tester.tap(find.byKey(const Key('calculate')));
      await tester.pumpAndSettle();
      expect(find.text('税后年薪'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    '360 width and 200 percent text keep result and comparison usable',
    (tester) async {
      final r = PayrollEngine.calculate(fixture()).single;
      final a = PayrollPlan(
        id: 'a',
        name: '相同月薪方案 A',
        savedAt: DateTime(2026),
        result: r,
      );
      final b = PayrollPlan(
        id: 'b',
        name: '相同月薪方案 B',
        savedAt: DateTime(2026),
        result: r,
      );
      await mount(tester, ComparisonScreen(first: a, second: b), scale: 2);
      expect(tester.takeException(), null);
      await tester.tap(find.text('只看差异'));
      await tester.pumpAndSettle();
      expect(find.text('年度项目无差异'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('large text result monthly rows and settings remain usable', (
    tester,
  ) async {
    final r = PayrollEngine.calculate(
      fixture().copyWith(salary: '999999999.99'),
    ).single;
    await mount(tester, PayrollResultsScreen(results: [r]), scale: 2);
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 28; i++) {
      await tester.drag(scrollable, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    }
    await tester.pumpWidget(const SizedBox());
    await mount(tester, ContributionsScreen(initial: r.draft), scale: 2);
    for (var i = 0; i < 18; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    }
  });
  testWidgets('blank and copied drafts update pension and bonus selectors', (
    tester,
  ) async {
    c.draft = fixture().copyWith(
      bonusMonth: 8,
      pensionMode: PensionMode.once,
      pensionMonth: 3,
      pension: '12000',
    );
    await mount(tester, const PayrollWorkspace());
    await tester.scrollUntilVisible(
      find.text('奖金与扣除'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('奖金与扣除'));
    await tester.pumpAndSettle();
    c.newBlank();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('奖金与扣除'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('奖金与扣除'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('bonus-month-${c.draft.id}-12')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('个人养老金'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(ValueKey('pension-mode-${c.draft.id}-${PensionMode.none}')),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
  });
  testWidgets('small screen large font and keyboard avoid offstage overflow', (
    tester,
  ) async {
    await mount(tester, const PayrollWorkspace(), scale: 2);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    expect(find.byKey(const Key('calculate')), findsOneWidget);
  });
  testWidgets('real bootstrap scopes controller above pushed routes', (
    tester,
  ) async {
    c.draft = fixture();
    await tester.pumpWidget(
      SalaryCalculatorApp(controllerLoader: () async => c),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calculate')));
    await tester.pumpAndSettle();
    expect(find.byType(PayrollResultsScreen), findsOneWidget);
    expect(find.text('税后年薪'), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('result export renders from the same snapshot', (tester) async {
    final d = fixture();
    final r = PayrollEngine.calculate(
      d.copyWith(
        overrides: {'med': d.city.items[1].copyWith(employeeFixed: 300)},
      ),
    ).single;
    await mount(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ResultExport(result: r, title: '截图样例'),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(AnnualCashSummary),
        matching: find.text(displayMoney(r.sum('net'))),
      ),
      findsOneWidget,
    );
    expect(find.text('全年到账'), findsNothing);
    expect(find.text('税后年薪'), findsOneWidget);
    for (final label in ['公积金总额', '医疗保险个人入账']) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(MetricRow),
      );
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: row, matching: find.byType(Text)),
          )
          .toList();
      expect(texts.first.data, label);
      expect(texts.first.style?.color, payrollMuted);
      expect(texts.last.style?.color, payrollBlue);
    }
    expect(
      tester
          .widget<MetricRow>(find.byKey(const Key('export-medical-account')))
          .value,
      '¥7,920.00',
    );
    expect(find.byKey(const Key('export-parameters')), findsOneWidget);
    final annualIncome = find.byKey(const Key('export-annual-total-income'));
    expect(annualIncome, findsOneWidget);
    expect(
      find.descendant(of: annualIncome, matching: find.text('年度总收入')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: annualIncome, matching: find.text('¥421,051.20')),
      findsOneWidget,
    );
    final parts = tester
        .widgetList<MetricRow>(
          find.descendant(of: annualIncome, matching: find.byType(MetricRow)),
        )
        .toList();
    expect(parts.map((row) => row.label), [
      '税后工资（现金）',
      '公积金总额',
      '医疗保险个人入账',
      '个人养老保险',
    ]);
    expect(parts.map((row) => row.value), [
      '¥286,411.20',
      '¥95,040.00',
      '¥7,920.00',
      '¥31,680.00',
    ]);
    final sectionKeys = [
      'export-cash-summary',
      'export-annual-total-income',
      'export-tax-adjustments',
      'export-parameters',
      'export-unit-total-cost',
    ];
    final offsets = sectionKeys
        .map((key) => tester.getTopLeft(find.byKey(Key(key))).dy)
        .toList();
    expect(offsets, orderedEquals([...offsets]..sort()));
    expect(offsets.last, lessThan(tester.getTopLeft(find.text('12 个月明细')).dy));
    expect(find.text('总工资'), findsNothing);
    expect(find.text('月度总收入'), findsNWidgets(12));
    for (final widget in tester.widgetList<MonthlyTotalIncome>(
      find.byType(MonthlyTotalIncome),
    )) {
      final amounts = MonthlyCompensation(widget.data);
      expect(
        amounts.totalEstimate,
        amounts.net +
            amounts.housing +
            amounts.medicalAccountEstimate! +
            amounts.personalPensionInsurance,
      );
    }
    expect(find.byKey(const Key('export-unit-total-cost')), findsOneWidget);
    expect(find.text('单位总成本'), findsOneWidget);
    expect(find.text('¥548,460.00 / 年'), findsOneWidget);
    expect(find.text('年度公司总支出'), findsNothing);
    expect(find.text('全年公司社保'), findsNothing);
    expect(find.byType(MonthlyTotalIncome), findsNWidgets(12));
    expect(find.text('年终奖计算方式'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'cash and inclusive income keep their own breakdowns at $scale text',
      (tester) async {
        final r = PayrollEngine.calculate(
          fixture().copyWith(
            bonus: '36000',
            bonusEligible: true,
            pensionMode: PensionMode.monthly,
            pension: '1000',
          ),
        ).first;
        await mount(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    AnnualCashSummary(result: r),
                    SectionCard(child: AnnualTotalIncome(result: r)),
                  ],
                ),
              ),
            ),
          ),
          scale: scale,
        );
        tester.view.physicalSize = const Size(320, 640);
        await tester.pumpAndSettle();
        final cash = find.byType(AnnualCashSummary);
        final inclusive = find.byType(AnnualTotalIncome);
        for (final label in [
          '税后年薪',
          '税前年薪（含奖金）',
          '减：年度个税',
          '减：个人社保',
          '减：个人公积金',
        ]) {
          final text = find.descendant(of: cash, matching: find.text(label));
          expect(text, findsOneWidget);
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(
          find.descendant(of: cash, matching: find.text('公积金总额')),
          findsNothing,
        );
        final rows = tester
            .widgetList<MetricRow>(
              find.descendant(of: inclusive, matching: find.byType(MetricRow)),
            )
            .toList();
        expect(rows.map((row) => row.label), [
          '税后工资（现金）',
          '公积金总额',
          '医疗保险个人入账',
          '个人养老保险',
        ]);
        expect(rows.last.value, displayMoney(r.itemSum('pension', 'employee')));
        expect(rows.last.value, isNot(displayMoney(r.sum('pension'))));
        for (final row in rows) {
          await tester.ensureVisible(
            find.descendant(of: inclusive, matching: find.text(row.label)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        // Each related group fits within a phone viewport at normal text size.
        if (scale == 1) {
          expect(tester.getSize(cash).height, lessThan(600));
          expect(tester.getSize(inclusive).height, lessThan(600));
        }
        expect(find.text('专项附加扣除'), findsNothing);
        expect(find.text('个人养老金（自愿缴存）'), findsNothing);
      },
    );

    testWidgets(
      'result configuration matches the selected snapshot at $scale text',
      (tester) async {
        final results = PayrollEngine.calculate(
          fixture().copyWith(
            socialBase: '20000',
            housingBase: '18000',
            bonus: '36000',
            bonusEligible: true,
            pensionMode: PensionMode.monthly,
            pension: '1000',
          ),
        );
        await mount(
          tester,
          PayrollResultsScreen(results: results),
          scale: scale,
        );
        tester.view.physicalSize = const Size(320, 640);
        await tester.pumpAndSettle();
        final card = find.byKey(const Key('result-parameters'));
        for (final strategy in ['单独计税', '并入工资']) {
          if (strategy == '并入工资') {
            final choice = find.widgetWithText(ChoiceChip, '奖金并入工资');
            await tester.scrollUntilVisible(
              choice,
              -350,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 100,
            );
            await tester.pumpAndSettle();
            await tester.tap(choice);
            await tester.pumpAndSettle();
          }
          await tester.scrollUntilVisible(
            card,
            350,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
          await tester.pumpAndSettle();
          for (final value in [
            '基数 ¥20,000.00',
            '基数 ¥18,000.00\n个人 12% / 公司 12%',
            '¥5,000.00 / 月（专项附加扣除）',
            '¥1,000.00 / 月',
            strategy,
          ]) {
            final text = find.descendant(of: card, matching: find.text(value));
            expect(text, findsOneWidget);
            await tester.ensureVisible(text);
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
          }
        }
        expect(c.plans, isEmpty);
      },
    );
  }

  testWidgets(
    'six result modules show January only and open monthly bottom sheets',
    (tester) async {
      final r = PayrollEngine.calculate(fixture()).single;
      await mount(tester, PayrollResultsScreen(results: [r]));
      expect(find.text('税后年薪'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnnualCashSummary),
          matching: find.text('¥286,440.00'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('result-annual-total-income')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('年度总收入'), findsOneWidget);
      expect(find.text('¥421,080.00'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-months')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('month-income-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('month-income-2')), findsNothing);
      expect(find.byKey(const ValueKey('month-total-1')), findsOneWidget);
      expect(find.text('¥36,327.75'), findsOneWidget);
      for (final key in ['social', 'housing', 'company']) {
        final card = find.byKey(ValueKey('result-$key-0'));
        await tester.scrollUntilVisible(
          card,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final tile = find.descendant(
          of: card,
          matching: find.byType(ExpansionTile),
        );
        await Scrollable.ensureVisible(tester.element(tile), alignment: .2);
        await tester.pumpAndSettle();
        if (key == 'company') {
          expect(find.text('单位总成本'), findsOneWidget);
          expect(find.text('¥548,460.00 / 年'), findsOneWidget);
        }
        await tester.tap(
          find.descendant(of: tile, matching: find.byType(ListTile)).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
      }
      final company = find.byKey(const Key('result-unit-total-cost'));
      await tester.scrollUntilVisible(
        company,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: company, matching: find.text('¥548,460.00 / 年')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: company, matching: find.text('单位总成本')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('result-company-annual')), findsNothing);
      expect(find.text('年度公司总支出'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-months')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more-months')));
      await tester.pumpAndSettle();
      expect(find.byType(MonthlyDetailsScreen), findsOneWidget);
      final table = tester.widget<MonthIncomeTable>(
        find.byType(MonthIncomeTable),
      );
      expect(table.months, hasLength(12));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('month-income-3')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('month-income-3')));
      await tester.pumpAndSettle();
      expect(find.byType(MonthDetailSheet), findsOneWidget);
      expect(find.text('3 月详情'), findsOneWidget);
      expect(find.text('¥24,357.00'), findsOneWidget);
      expect(find.byKey(const Key('month-total-section')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('month-total-section')),
          matching: find.text('¥35,577.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '（税后工资 ¥24,357.00 + 公积金（公司＋个人）¥7,920.00 + 医保个人账户（估算）¥660.00 + 个人养老保险 ¥2,640.00）',
        ),
        findsWidgets,
      );
      final sheetScroll = find
          .descendant(
            of: find.byType(MonthDetailSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('month-tax-basis-section')),
        400,
        scrollable: sheetScroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('¥46,725.00'), findsOneWidget);
      expect(
        tester
            .widget<CumulativeTaxDetails>(find.byType(CumulativeTaxDetails))
            .month
            .previouslyPaid,
        93450,
      );
      expect(tester.takeException(), null);
      await tester.tap(find.byTooltip('关闭明细'));
      await tester.pumpAndSettle();
      expect(find.byType(MonthDetailSheet), findsNothing);
      expect(find.byType(MonthlyDetailsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'monthly list and every sheet section fit small screens and 200 percent text',
    (tester) async {
      final r = PayrollEngine.calculate(
        fixture().copyWith(salary: '999999999.99'),
      ).single;
      await mount(tester, MonthlyDetailsScreen(result: r), scale: 2);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('month-income-12')),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('month-income-12')));
      await tester.pumpAndSettle();
      for (final section in [
        'net',
        'total',
        'social',
        'housing',
        'tax',
        'tax-basis',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(Key('month-$section-section')),
          350,
          scrollable: find
              .descendant(
                of: find.byType(MonthDetailSheet),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 100,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
      }
      await tester.tap(find.byTooltip('关闭明细'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'annual result formulas and tax guide remain usable at $scale text',
      (tester) async {
        // Load the bundled document in real time before the route uses it.
        await tester.runAsync(() => rootBundle.loadString('doc/薪酬算法说明.md'));
        final r = PayrollEngine.calculate(fixture()).single;
        await mount(tester, PayrollResultsScreen(results: [r]), scale: scale);
        tester.view.physicalSize = const Size(320, 640);
        await tester.pumpAndSettle();
        Future<void> reveal(Finder target) async {
          await tester.scrollUntilVisible(
            target,
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
        }

        await reveal(find.text('计算说明'));
        await tester.tap(find.text('计算说明'));
        await tester.pumpAndSettle();
        expect(find.byType(AnnualTaxDetails), findsOneWidget);
        for (final entry in {
          'annual-net-formula':
              '¥396,000.00 − ¥20,460.00 − ¥41,580.00 − ¥47,520.00 = ¥286,440.00',
          'annual-tax-base-formula':
              '¥396,000.00 − ¥60,000.00 − ¥89,100.00 − ¥60,000.00 − ¥0.00 = ¥186,900.00',
          'annual-tax-formula': '¥186,900.00 × 20% − ¥16,920.00 = ¥20,460.00',
        }.entries) {
          final formula = find.byKey(Key(entry.key));
          await reveal(formula);
          expect(tester.widget<FormulaText>(formula).text, entry.value);
          expect(tester.takeException(), null);
        }
        final help = find.byKey(const Key('annual-tax-help'));
        await tester.ensureVisible(help);
        await tester.pumpAndSettle();
        await tester.tap(help);
        await tester.pumpAndSettle();
        expect(find.byType(MethodologyScreen), findsOneWidget);
        expect(find.byType(TaxRateGuide), findsOneWidget);
        expect(find.text('本方案年度计税基数 ¥186,900.00，适用第 3 档：20%。'), findsOneWidget);
        final table = tester.widget<Table>(
          find.byKey(const Key('annual-tax-rate-table')),
        );
        expect(table.children, hasLength(8));
        expect(find.text('16,920'), findsOneWidget);
        expect(tester.takeException(), null);
        await tester.tap(find.text('完整说明'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final loader = tester
            .widget<FutureBuilder<String>>(
              find.byType(FutureBuilder<String>, skipOffstage: false),
            )
            .future!;
        // Asset decoding can use an isolate; let it finish outside fake time.
        await tester.runAsync(() async {
          await loader;
        });
        await tester.pumpAndSettle();
        expect(find.text('说明文档暂时无法加载，请稍后重试。'), findsNothing);
        expect(find.byType(SelectableText), findsWidgets);
        expect(find.byType(TaxRateGuide), findsNothing);
        expect(tester.takeException(), null);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(AnnualTaxDetails), findsOneWidget);
        expect(tester.takeException(), null);
      },
    );
  }

  testWidgets(
    'plan cards expose saved settings and compare in aligned columns',
    (tester) async {
      final results = PayrollEngine.calculate(
        fixture().copyWith(
          socialBase: '20000',
          housingBase: '18000',
          bonus: '36000',
          bonusEligible: true,
          pensionMode: PensionMode.monthly,
          pension: '1000',
        ),
      );
      c.plans = [
        for (var i = 0; i < results.length; i++)
          PayrollPlan(
            id: 'plan-$i',
            name: '工资方案 $i',
            savedAt: DateTime(2026),
            result: results[i],
          ),
      ];
      await mount(tester, Scaffold(body: PlansScreen(onCopy: () {})));
      final firstCard = find.byKey(const ValueKey('plan-card-plan-0'));
      for (final label in ['社保', '公积金', '专项扣除', '个人养老金', '年终奖计算方式']) {
        expect(
          find.descendant(of: firstCard, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: firstCard, matching: find.text('基数 ¥20,000.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstCard,
          matching: find.text('基数 ¥18,000.00\n个人 12% / 公司 12%'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firstCard, matching: find.text('单独计税')),
        findsOneWidget,
      );
      for (var i = 0; i < 2; i++) {
        final select = find.byKey(ValueKey('select-plan-plan-$i'));
        await tester.scrollUntilVisible(
          select,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('开始对比'));
      await tester.pumpAndSettle();
      final overview = find.byKey(const Key('comparison-overview'));
      expect(find.text('更多缴费与规则'), findsNothing);
      expect(find.text('方案设置'), findsNothing);
      final mergedRows = tester.widget<PlanComparisonTable>(overview).rows;
      expect(mergedRows.map((r) => r.label).toSet().length, mergedRows.length);
      final firstMonthly = mergedRows.indexWhere(
        (r) => r.label.startsWith('【月】'),
      );
      expect(
        mergedRows.take(firstMonthly).every((r) => r.label.startsWith('【年】')),
        isTrue,
      );
      expect(
        mergedRows.skip(firstMonthly).every((r) => r.label.startsWith('【月】')),
        isTrue,
      );
      expect(mergedRows.any((r) => r.label == '【月】工伤保险（单位）'), isTrue);
      expect(mergedRows.any((r) => r.label == '【月】养老保险基数范围'), isTrue);
      final amounts = find.descendant(
        of: overview,
        matching: find.text('432,000.00'),
      );
      expect(amounts, findsNWidgets(2));
      final label = find.descendant(
        of: overview,
        matching: find.text('【年】税前收入\n（含奖金）'),
      );
      expect(
        tester.getCenter(label).dx,
        lessThan(tester.getCenter(amounts.first).dx),
      );
      expect(
        tester.getCenter(amounts.first).dx,
        lessThan(tester.getCenter(amounts.last).dx),
      );
      expect(
        tester.getCenter(amounts.first).dy,
        closeTo(tester.getCenter(amounts.last).dy, .1),
      );
      await tester.tap(find.byKey(const Key('comparison-month')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('12 月明细').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 月明细').last);
      await tester.pumpAndSettle();
      var table = tester.widget<PlanComparisonTable>(overview);
      expect(
        table.rows.firstWhere((r) => r.label == '【月】个税').left,
        comparisonOverview(
          PayrollComparison(c.plans[0], c.plans[1], 12),
          false,
        ).firstWhere((r) => r.label == '【月】个税').left,
      );
      await tester.tap(find.byTooltip('交换 A / B'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PlanComparisonTable>(
              find.byKey(const Key('comparison-header')),
            )
            .first
            .id,
        'plan-1',
      );
      await tester.tap(find.text('只看差异'));
      await tester.pumpAndSettle();
      table = tester.widget<PlanComparisonTable>(overview);
      expect(table.rows.any((r) => r.label == '【年】税前收入（含奖金）'), isFalse);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'comparison keeps header fixed and large text values scroll together',
    (tester) async {
      final r = PayrollEngine.calculate(
        fixture().copyWith(salary: '999999999.99'),
      ).single;
      final a = PayrollPlan(
        id: 'a',
        name: '很长的工资方案名称用于验证大字体显示',
        savedAt: DateTime(2026),
        result: r,
      );
      final b = PayrollPlan(
        id: 'b',
        name: '另一份工资方案名称用于验证大字体显示',
        savedAt: DateTime(2026),
        result: r,
      );
      await mount(tester, ComparisonScreen(first: a, second: b), scale: 2);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      final viewport = find.byKey(const Key('comparison-horizontal'));
      final header = find.byKey(const Key('comparison-header'));
      final before = tester.getTopLeft(header);
      final scroller = tester
          .widget<SingleChildScrollView>(viewport)
          .controller!;
      expect(scroller.position.maxScrollExtent, greaterThan(0));
      await tester.drag(viewport, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(scroller.offset, greaterThan(0));
      final after = tester.getTopLeft(header);
      expect(after.dy, before.dy);
      expect(after.dx, lessThan(before.dx));
      await tester.drag(viewport, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, before.dy);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('comparison export uses the same matrix and saved configuration', (
    tester,
  ) async {
    final d = fixture(), a = PayrollEngine.calculate(d).single;
    final b = PayrollEngine.calculate(
      d.copyWith(
        overrides: {'inj': d.city.items[3].copyWith(employerRate: 4000)},
      ),
    ).single;
    final comparison = PayrollComparison(
      PayrollPlan(id: 'a', name: 'A', savedAt: DateTime(2026), result: a),
      PayrollPlan(id: 'b', name: 'B', savedAt: DateTime(2026), result: b),
      1,
    );
    await mount(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ComparisonExport(
            comparison: comparison,
            onlyDifferences: false,
          ),
        ),
      ),
    );
    final table = tester.widget<PlanComparisonTable>(
      find.byType(PlanComparisonTable),
    );
    final expected = comparisonOverview(comparison, false);
    expect(
      table.rows.map((r) => (r.label, r.left, r.right)),
      expected.map((r) => (r.label, r.left, r.right)),
    );
    expect(
      table.rows.firstWhere((r) => r.label == '【月】单位成本').right,
      '45,771.00',
    );
    expect(table.rows.any((r) => r.label == '【年】年终奖计算方式'), isTrue);
    expect(table.rows.first.left, '548,460.00');
    expect(table.rows[2].left, '421,080.00');
    expect(table.rows.any((r) => r.label == '【月】住房公积金比例（个人 / 单位）'), isTrue);
    final differences = comparisonOverview(comparison, true);
    expect(differences.any((r) => r.label == '【月】工伤保险比例（个人 / 单位）'), isTrue);
    expect(differences.any((r) => r.label == '【年】个人税后收入'), isFalse);
    expect(differences.any((r) => r.label == '【月】个人税后收入'), isFalse);
    expect(
      comparisonOverview(
        PayrollComparison(comparison.a, comparison.a, 1),
        true,
      ).map((r) => r.label),
      ['年度项目无差异', '本月项目无差异'],
    );
    expect(tester.takeException(), null);
    // The long-image renderer has Theme/MediaQuery, but no Navigator or
    // Overlay. Exercise that environment rather than masking it in MaterialApp.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(380, 800)),
          child: Theme(
            data: ThemeData(),
            child: Material(
              child: SingleChildScrollView(
                child: ComparisonExport(
                  comparison: comparison,
                  onlyDifferences: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });

  testWidgets(
    'zero housing contributions display both parties without dividing by zero',
    (tester) async {
      final r = PayrollEngine.calculate(
        fixture(zeroContributions: true),
      ).single;
      await mount(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: HousingContributionDetails(month: MonthBreakdown(r, 1)),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('缴费比例 0% · 占总额 0%'), findsNWidgets(2));
      expect(tester.takeException(), null);
    },
  );
}

// Widget tests exercise rendering and interaction. Real SQLite writes are
// covered in payroll_store_test and on-device integration tests; running FFI
// transactions created inside the fake animation clock would deadlock.
class _WidgetStore extends PayrollStore {
  _WidgetStore(super.db);
  @override
  Future<void> saveDraft(PayrollDraft d, {PayrollDraft? previousScope}) async {}
}
