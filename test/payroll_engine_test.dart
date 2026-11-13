import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/domain/payroll_engine.dart';
import 'package:pay_cal/domain/payroll_comparison.dart';
import 'fixtures/payroll_fixture.dart';

void main() {
  test(
    'result snapshot freezes nested rows and retains original engine metadata',
    () {
      final r = PayrollEngine.calculate(fixture()).single;
      expect(() => r.months.first['net'] = 0, throwsUnsupportedError);
      expect(
        () => (r.months.first['items'] as List).first['employee'] = 0,
        throwsUnsupportedError,
      );
      final saved = {...r.toJson(), 'engineVersion': 'historical-v2.0.0'};
      expect(
        PayrollResult.fromJson(saved).toJson()['engineVersion'],
        'historical-v2.0.0',
      );
    },
  );

  test(
    'decimal amounts and ppm are exact and reject invalid / overflow text',
    () {
      expect(parseDecimal('￥33,000.01', 2), 3300001);
      expect(parseDecimal('0.125', 4, max: rateScale), 1250);
      expect(rateText(1250), '0.125%');
      for (final text in [
        '',
        '.',
        '-1',
        '1e6',
        '1.001',
        '1,2',
        '12¥34',
        '1.2,3',
        '1000000000',
        '99999999999999999999999999',
      ]) {
        expect(parseDecimal(text, 2), null);
      }
      expect(parseDecimal('100.0001', 4, max: rateScale), null);
    },
  );
  test('screenshot A independent annual and monthly benchmark', () {
    final r = PayrollEngine.calculate(fixture()).single;
    expect(r.months.first['net'], 2510775);
    expect(r.months.first['tax'], 46725);
    expect(r.sum('net'), 28644000);
    expect(r.sum('tax'), 2046000);
    expect(r.sum('housing'), 9504000);
    expect(r.itemSum('hf', 'employee', month: 1), 396000);
    expect(r.sum('employerCost'), 54846000);
  });
  test('legacy B benchmark including explicit three yuan fixed fee', () {
    var d = fixture().copyWith(salary: '35000');
    d = d.copyWith(
      overrides: {'med': d.city.items[1].copyWith(employeeFixed: 300)},
    );
    final r = PayrollEngine.calculate(d).single;
    expect(r.sum('net'), 30129120);
    expect(r.sum('tax'), 2417280);
    expect(r.sum('employerCost'), 58170000);
    expect(r.months.map((m) => m['tax']).toList(), [
      51366,
      51366,
      158928,
      171220,
      171220,
      171220,
      171220,
      171220,
      272200,
      342440,
      342440,
      342440,
    ]);
  });
  test('bonus separate vs merged, correct monthly booking', () {
    final d = fixture().copyWith(bonus: '36000', bonusEligible: true);
    final r = PayrollEngine.calculate(d);
    expect(r[0].sum('tax'), 2154000);
    expect(r[0].sum('net'), 32136000);
    expect(r[1].sum('tax'), 2766000);
    expect(r[1].sum('net'), 31524000);
    expect(r[0].months.last['bonusTax'], 108000);
    expect(r[0].months.take(11).every((m) => m['bonusTax'] == 0), true);
    final earlier = PayrollEngine.calculate(d.copyWith(bonusMonth: 3))[0];
    expect(earlier.months[2]['bonusTax'], 108000);
    expect(earlier.months.last['bonusTax'], 0);
  });
  test('bonus boundary jump and eligibility/expiry gates', () {
    expect(PayrollEngine.separateBonusTax(3600000), 108000);
    expect(PayrollEngine.separateBonusTax(3600001), 339000);
    expect(
      () => PayrollEngine.calculate(fixture().copyWith(bonus: '100')),
      throwsA(isA<PayrollException>()),
    );
    expect(
      () => PayrollEngine.calculate(
        fixture().copyWith(bonus: '100', bonusEligible: true, year: 2028),
      ),
      throwsA(isA<PayrollException>()),
    );
    expect(
      PayrollEngine.calculate(
        fixture().copyWith(
          bonus: '100',
          year: 2028,
          bonusMode: BonusMode.merged,
        ),
      ),
      hasLength(1),
    );
  });
  test('all wage and bonus band boundaries belong to lower band', () {
    for (var i = 0; i < PayrollEngine.limits.length; i++) {
      final boundary = PayrollEngine.limits[i];
      expect(PayrollEngine.bracket(boundary - 1), i);
      expect(PayrollEngine.bracket(boundary), i);
      expect(PayrollEngine.bracket(boundary + 1), i + 1);
      expect(
        PayrollEngine.wageTax(boundary),
        PayrollEngine.percentage(boundary, PayrollEngine.rates[i]) -
            PayrollEngine.wageQuick[i],
      );
    }
  });
  test(
    'pension payment and deduction timing are separate from payroll cash',
    () {
      final d = fixture().copyWith(
        pensionMode: PensionMode.monthly,
        pension: '1000',
      );
      final now = PayrollEngine.calculate(d).single,
          later = PayrollEngine.calculate(
            d.copyWith(pensionAtSettlement: true),
          ).single;
      expect(now.annualTaxDue, 1806000);
      expect(now.sum('net'), 28884000);
      expect(now.sum('available'), 27684000);
      expect(later.annualTaxDue, 1806000);
      expect(later.sum('tax'), 2046000);
      expect(later.sum('net'), 28644000);
      expect(later.refundEstimate, 240000);
      expect(
        () => PayrollEngine.calculate(d.copyWith(pension: '1000.01')),
        throwsA(isA<PayrollException>()),
      );
    },
  );
  test(
    'cumulative raw negative balance is retained and tax already paid never decreases',
    () {
      final d = fixture(
        zeroContributions: true,
      ).copyWith(salary: '10000', deduction: '0');
      final varying = PayrollEngine.calculate(
        d,
        monthlySalaries: [400000, 1000000, ...List.filled(10, 1000000)],
      ).single;
      expect(varying.months[1]['taxBase'], 400000);
      expect(varying.months[1]['tax'], 12000);
      final once = PayrollEngine.calculate(
        d.copyWith(
          pensionMode: PensionMode.once,
          pension: '12000',
          pensionMonth: 2,
        ),
      ).single;
      expect(once.months.take(4).map((m) => m['tax']).toList(), [
        15000,
        0,
        0,
        9000,
      ]);
    },
  );
  test('each item clamps independently, ppm and rounding apply per party', () {
    final d = fixture().copyWith(
      overrides: {
        'pension': fixture().city.items[0].copyWith(
          minBase: 100000,
          maxBase: 200000,
        ),
        'hf': fixture().city.items[5].copyWith(
          minBase: 300000,
          maxBase: 400000,
          employerRate: 100000,
          roundingUnit: 100,
        ),
      },
      deductible: '0',
    );
    final r = PayrollEngine.calculate(d).single;
    expect((r.months.first['items'] as List).first['base'], 200000);
    expect(r.itemSum('hf', 'employee', month: 1), 48000);
    expect(r.itemSum('hf', 'employer', month: 1), 40000);
    expect(PayrollEngine.percentage(1000000, 1250), 1250);
    expect(PayrollEngine.percentage(10500, 50000, unit: 100), 500);
  });
  test(
    'missing fields and excessive/custom deductions cannot silently pass',
    () {
      final d = fixture();
      expect(
        () => PayrollEngine.calculate(
          d.copyWith(
            overrides: {
              'inj': const Contribution(
                kind: 'inj',
                employeeRate: 0,
                employerRate: 2000,
              ),
            },
          ),
        ),
        throwsA(isA<PayrollException>()),
      );
      expect(
        () => PayrollEngine.calculate(
          d.copyWith(
            overrides: {'hf': d.city.items.last.copyWith(employeeRate: 200000)},
          ),
        ),
        throwsA(isA<PayrollException>()),
      );
      expect(
        () => PayrollEngine.calculate(d.copyWith(deductible: '99999')),
        throwsA(isA<PayrollException>()),
      );
      expect(
        () => PayrollEngine.calculate(d.copyWith(estimateConfirmed: false)),
        throwsA(isA<PayrollException>()),
      );
    },
  );
  test('period resolver rejects gaps and overlap; changes apply in July', () {
    final d = fixture();
    CityReference city(List<PolicyPeriod> p) => CityReference(
      id: 'periods',
      name: '分段规则',
      province: '',
      search: '',
      yearLabel: '2026',
      version: 'test',
      items: d.city.items,
      sources: [],
      note: '',
      periods: p,
    );
    final h1 = PolicyPeriod(
      from: DateTime(2026),
      to: DateTime(2026, 6, 30),
      items: d.city.items,
      verified: true,
    );
    final h2 = PolicyPeriod(
      from: DateTime(2026, 7),
      to: DateTime(2026, 12, 31),
      items: d.city.items
          .map((e) => e.kind == 'inj' ? e.copyWith(employerRate: 4000) : e)
          .toList(),
      verified: true,
    );
    expect(
      () => PayrollEngine.calculate(
        d.copyWith(city: city([h1]), estimateConfirmed: false),
      ),
      throwsA(isA<PayrollException>()),
    );
    expect(
      () => PayrollEngine.calculate(
        d.copyWith(city: city([h1, h1, h2]), estimateConfirmed: false),
      ),
      throwsA(isA<PayrollException>()),
    );
    final r = PayrollEngine.calculate(
      d.copyWith(city: city([h1, h2]), estimateConfirmed: false),
    ).single;
    expect(r.months[6]['employerCost'] - r.months[5]['employerCost'], 6600);
  });
  test(
    'negative cash and maximum input remain valid and snapshots round-trip',
    () {
      final d = fixture().copyWith(salary: '0', socialBase: '33000');
      final r = PayrollEngine.calculate(d).single;
      expect(r.sum('net'), lessThan(0));
      expect(
        PayrollResult.fromJson(
          objectMap(jsonDecode(jsonEncode(r.toJson()))),
        ).sum('net'),
        r.sum('net'),
      );
      final max = PayrollEngine.calculate(
        fixture().copyWith(salary: '999999999.99'),
      ).single;
      expect(max.sum('employerCost'), greaterThan(0));
      for (final month in max.months) {
        expect(
          month['net'],
          month['salary'] + month['bonus'] - month['employee'] - month['tax'],
        );
      }
    },
  );
  test('comparison isolates company difference and reverses its sign', () {
    final d = fixture(), a = PayrollEngine.calculate(d).single;
    final b = PayrollEngine.calculate(
      d.copyWith(
        overrides: {'inj': d.city.items[3].copyWith(employerRate: 4000)},
      ),
    ).single;
    PayrollPlan plan(String id, PayrollResult r) =>
        PayrollPlan(id: id, name: id, savedAt: DateTime(2026), result: r);
    final compare = PayrollComparison(plan('a', a), plan('b', b), 1);
    expect(compare.overviewAnnual[1].difference, 0);
    expect(
      compare.overviewAnnual.firstWhere((m) => m.label == '【年】单位成本').difference,
      79200,
    );
    expect(
      compare.overviewMonthly
          .firstWhere((m) => m.label == '【月】工伤保险（单位）')
          .difference,
      6600,
    );
    expect(
      PayrollComparison(
        plan('b', b),
        plan('a', a),
        1,
      ).overviewAnnual.firstWhere((m) => m.label == '【年】单位成本').difference,
      -79200,
    );
    expect(
      compare.overviewMonthly.firstWhere((m) => m.label == '【月】住房公积金（个人）').a,
      396000,
    );
  });
}
