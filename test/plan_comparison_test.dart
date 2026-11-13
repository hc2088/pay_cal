import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_cal/calculation/calculator_inputs.dart';
import 'package:pay_cal/domain/payroll_comparison.dart';
import 'package:pay_cal/domain/payroll_engine.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/domain/plan_snapshot_details.dart';
import 'fixtures/payroll_fixture.dart';

PayrollPlan plan(PayrollResult r, {String id = 'a'}) =>
    PayrollPlan(id: id, name: '方案 $id', savedAt: DateTime(2026), result: r);

void main() {
  test(
    'reference matrix contains all annual and monthly rows with their correct scopes',
    () {
      final d = fixture(), a = PayrollEngine.calculate(d).single;
      final b = PayrollEngine.calculate(
        d.copyWith(
          overrides: {'inj': d.city.items[3].copyWith(employerRate: 4000)},
        ),
      ).single;
      final c = PayrollComparison(plan(a), plan(b, id: 'b'), 1);
      expect(
        {for (final m in c.overviewAnnual) m.label: m.a},
        {
          '【年】单位成本': 54846000,
          '【年】个人税后收入': 28644000,
          '【年】个人税后收入（加公积金、个人医保、个人养老保险）': 42108000,
          '【年】税前工资': 39600000,
          '【年】个税': 2046000,
          '【年】应纳个税（汇算估算）': 2046000,
          '【年】公积金（公司＋个人）': 9504000,
          '【年】医保个人账户（估算）': 792000,
          '【年】养老保险（个人）': 3168000,
          '【年】社保（个人）': 4158000,
          '【年】个人养老金': 0,
          '【年】专项附加扣除': 6000000,
          '【年】养老金投入后可用现金': 28644000,
        },
      );
      expect(
        {for (final m in c.overviewMonthly) m.label: m.a},
        {
          '【月】单位成本': 4570500,
          '【月】个人税后收入': 2510775,
          '【月】个人税后收入（加公积金、个人医保、个人养老保险）': 3632775,
          '【月】税前工资': 3300000,
          '【月】个税': 46725,
          '【月】公积金（公司＋个人）': 792000,
          '【月】医保个人账户（估算）': 66000,
          '【月】社保（个人）': 346500,
          '【月】养老保险（个人）': 264000,
          '【月】医疗保险（个人）': 66000,
          '【月】失业保险（个人）': 16500,
          '【月】工伤保险（个人）': 0,
          '【月】生育保险（个人）': 0,
          '【月】住房公积金（个人）': 396000,
          '【月】养老保险（单位）': 528000,
          '【月】医疗保险（单位）': 323400,
          '【月】失业保险（单位）': 16500,
          '【月】工伤保险（单位）': 6600,
          '【月】生育保险（单位）': 0,
          '【月】住房公积金（单位）': 396000,
          '【月】五险一金合计（个人）': 742500,
          '【月】五险一金合计（单位）': 1270500,
          '【月】个人养老金': 0,
          '【月】养老金投入后可用现金': 2510775,
          '【月】专项附加扣除': 500000,
          '【月】个人缴费可税前扣除额': 742500,
          '【月】单位应税福利': 0,
        },
      );
      final differences = c.overviewMonthly
          .where((m) => m.isDifferent)
          .toList();
      expect(differences.map((m) => m.label), [
        '【月】单位成本',
        '【月】工伤保险（单位）',
        '【月】五险一金合计（单位）',
      ]);
      expect(differences.first.b, 4577100);
      expect(differences.every((m) => m.difference == 6600), isTrue);
      expect(
        PayrollComparison(plan(b), plan(a), 1).overviewMonthly.first.difference,
        -6600,
      );
      final annualDifferences = c.overviewAnnual
          .where((m) => m.isDifferent)
          .toList();
      expect(annualDifferences.single.label, '【年】单位成本');
      expect(annualDifferences.single.difference, 79200);
    },
  );

  test(
    'inclusive income and cost reconcile across months without mixing pension accounts',
    () {
      final d = fixture();
      for (final r in PayrollEngine.calculate(
        d.copyWith(
          bonus: '36000',
          bonusMonth: 3,
          bonusEligible: true,
          pensionMode: PensionMode.once,
          pensionMonth: 12,
          pension: '12000',
          overrides: {'med': d.city.items[1].copyWith(employeeFixed: 300)},
        ),
        monthlySalaries: [3300000, ...List.filled(11, 4000000)],
      )) {
        final annual = PayrollComparison(plan(r), plan(r), 1).overviewAnnual;
        var totalIncome = 0, totalCost = 0;
        for (var month = 1; month <= 12; month++) {
          final rows = PayrollComparison(
            plan(r),
            plan(r),
            month,
          ).overviewMonthly;
          totalCost += rows[0].a!;
          totalIncome += rows[2].a!;
          final medical = rows.firstWhere((m) => m.label == '【月】医保个人账户（估算）').a!;
          final insurance = rows.firstWhere((m) => m.label == '【月】养老保险（个人）').a!;
          final housing = rows.firstWhere((m) => m.label == '【月】公积金（公司＋个人）').a!;
          expect(medical, month == 1 ? 66000 : 80000);
          expect(insurance, month == 1 ? 264000 : 320000);
          expect(rows[2].a, rows[1].a! + housing + medical + insurance);
          expect(rows[0].a, r.months[month - 1]['employerCost']);
        }
        expect(totalCost, annual[0].a);
        expect(totalIncome, annual[2].a);
        final saved =
            jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
        (saved['months'][0]['items'][1] as Map).remove('employeeFixed');
        final historical = PayrollResult.fromJson(saved);
        final missing = PayrollComparison(plan(historical), plan(r), 1);
        expect(missing.overviewAnnual[2].a, null);
        expect(missing.overviewMonthly[2].a, null);
        expect(missing.overviewMonthly[2].difference, null);
      }
      final zero = PayrollEngine.calculate(
        fixture(
          zeroContributions: true,
        ).copyWith(salary: '4000', deduction: '0'),
      ).single;
      final c = PayrollComparison(plan(zero), plan(zero), 1);
      expect(c.overviewAnnual[2].a, 4800000);
      expect(c.overviewMonthly[2].a, 400000);
    },
  );

  test(
    'month selector uses the saved month including one-off pension payment',
    () {
      final r = PayrollEngine.calculate(
        fixture().copyWith(
          pensionMode: PensionMode.once,
          pensionMonth: 12,
          pension: '12000',
        ),
      ).single;
      final jan = PayrollComparison(plan(r), plan(r), 1),
          dec = PayrollComparison(plan(r), plan(r), 12);
      expect(jan.overviewMonthly.firstWhere((m) => m.label == '【月】个人养老金').a, 0);
      expect(
        dec.overviewMonthly.firstWhere((m) => m.label == '【月】个人养老金').a,
        1200000,
      );
      expect(dec.overviewMonthly[1].a, r.months.last['net']);
      expect(
        dec.overviewAnnual.map((m) => m.a),
        jan.overviewAnnual.map((m) => m.a),
      );
    },
  );

  test(
    'plan summary shows resolved contribution bases and independent housing rates',
    () {
      final d = fixture();
      final r = PayrollEngine.calculate(
        d.copyWith(
          socialBase: '50000',
          housingBase: '20000',
          deductible: '0',
          overrides: {
            for (final item in d.city.items)
              item.kind: item.copyWith(
                maxBase: 2500000,
                employeeRate: item.kind == 'hf' ? 50000 : item.employeeRate,
                employerRate: item.kind == 'hf' ? 120000 : item.employerRate,
              ),
          },
        ),
      ).single;
      final details = PlanSnapshotDetails(plan(r));
      expect(details.socialBases, '基数 ¥25,000.00');
      expect(details.housing, '基数 ¥20,000.00\n个人 5% / 公司 12%');
      expect(details.settings['专项扣除'], '¥5,000.00 / 月（专项附加扣除）');
      expect(details.pension, '不缴纳');
      expect(details.bonusMethod, '无年终奖');
    },
  );

  test(
    'saved bonus strategy, pension schedule and bonus month are shown explicitly',
    () {
      final results = PayrollEngine.calculate(
        fixture().copyWith(
          bonus: '36000',
          bonusMonth: 3,
          bonusEligible: true,
          pensionMode: PensionMode.once,
          pensionMonth: 9,
          pension: '12000',
        ),
      );
      final a = PlanSnapshotDetails(plan(results.first)),
          b = PlanSnapshotDetails(plan(results.last));
      expect(a.bonusMethod, '单独计税');
      expect(b.bonusMethod, '并入工资');
      expect(a.pension, '9 月一次缴纳 ¥12,000.00');
      expect(a.settings['年终奖'], '¥36,000.00 · 3 月');
      final c = PayrollComparison(a.plan, b.plan, 3);
      expect(
        c.overviewAnnual.firstWhere((m) => m.label == '【年】税前收入（含奖金）').a,
        43200000,
      );
      expect(
        c.overviewMonthly.firstWhere((m) => m.label == '【月】年终奖').a,
        3600000,
      );
      expect(
        c.overviewMonthly.firstWhere((m) => m.label == '【月】单位成本').a,
        8170500,
      );
    },
  );

  test(
    'period-specific bases and rates are summarized from all saved months',
    () {
      final d = fixture();
      List<Contribution> items(int base, int rate) => d.city.items
          .map(
            (i) => i.kind == 'hf'
                ? i.copyWith(actualBase: base, employeeRate: rate)
                : i.kind == 'pension'
                ? i.copyWith(actualBase: base)
                : i,
          )
          .toList();
      final city = CityReference(
        id: 'period',
        name: '分段城市',
        province: '',
        search: '',
        yearLabel: '2026',
        version: 'test',
        items: d.city.items,
        sources: [],
        note: '',
        periods: [
          PolicyPeriod(
            from: DateTime(2026),
            to: DateTime(2026, 6, 30),
            items: items(1800000, 50000),
            verified: true,
          ),
          PolicyPeriod(
            from: DateTime(2026, 7),
            to: DateTime(2026, 12, 31),
            items: items(2400000, 100000),
            verified: true,
          ),
        ],
      );
      final summary = PlanSnapshotDetails(
        plan(
          PayrollEngine.calculate(
            d.copyWith(city: city, estimateConfirmed: false),
          ).single,
        ),
      );
      expect(summary.socialBases, contains('养老：¥18,000.00 – ¥24,000.00（年内变化）'));
      expect(summary.socialBases, contains('¥33,000.00'));
      expect(summary.housing, contains('个人 5% – 10%（年内变化） / 公司 12%'));
      final jan = PayrollComparison(summary.plan, summary.plan, 1);
      final dec = PayrollComparison(summary.plan, summary.plan, 12);
      expect(jan.annualSettings, dec.annualSettings);
      expect(jan.monthlySettings['【月】住房公积金比例（个人 / 单位）']!.$1, '5% / 12%');
      expect(dec.monthlySettings['【月】住房公积金比例（个人 / 单位）']!.$1, '10% / 12%');
      expect(jan.monthlySettings['【月】住房公积金缴纳基数']!.$1, contains('¥18,000.00'));
      expect(dec.monthlySettings['【月】住房公积金缴纳基数']!.$1, contains('¥24,000.00'));
      expect(
        dec.overviewMonthly[2].a! - dec.overviewMonthly[1].a!,
        240000 + 288000 + 66000 + 192000,
      );
    },
  );

  test(
    'legacy and different-year plans retain missing data without invented zeros or deltas',
    () {
      final old = PayrollPlan(
        id: 'old',
        name: '旧版',
        savedAt: DateTime(2026),
        legacy: {
          'inputs': CalculatorInputs.defaults()
              .withCustomHousingFundBase(2000000)
              .toJson(),
          'months': [],
          'annualNetCashCents': 12300,
          'annualEmployeePensionCents': 3000000,
        },
      );
      final summary = PlanSnapshotDetails(old);
      expect(summary.housing, contains('原输入基数 ¥20,000.00'));
      expect(summary.socialBases, '未记录实际基数');
      expect(summary.pension, '未记录');
      expect(summary.bonusMethod, '未记录');
      final r = PayrollEngine.calculate(fixture()).single;
      final c = PayrollComparison(old, plan(r), 1);
      expect(c.overviewAnnual.firstWhere((m) => m.label == '【年】个人养老金').a, null);
      expect(c.overviewAnnual[2].a, null);
      expect(c.overviewMonthly[2].a, null);
      expect(c.overviewAnnual.every((m) => m.difference == null), isTrue);
      final next = PayrollEngine.calculate(
        fixture().copyWith(year: 2027),
      ).single;
      expect(
        PayrollComparison(
          plan(r),
          plan(next),
          1,
        ).overviewMonthly.every((m) => m.difference == null),
        isTrue,
      );
    },
  );
}
