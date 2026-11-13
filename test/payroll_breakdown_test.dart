import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_cal/domain/payroll_breakdown.dart';
import 'package:pay_cal/domain/payroll_engine.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'fixtures/payroll_fixture.dart';

void main() {
  test(
    'monthly total includes pension insurance and reconciles to annual income',
    () {
      final d = fixture();
      final r = PayrollEngine.calculate(
        d.copyWith(
          overrides: {'med': d.city.items[1].copyWith(employeeFixed: 300)},
        ),
      ).single;
      final january = MonthlyCompensation(r.months.first);
      expect(january.net, 2510484);
      expect(january.housing, 792000);
      expect(january.medicalAccountEstimate, 66000);
      expect(january.personalPensionInsurance, 264000);
      expect(january.totalEstimate, 3632484);
      // December uses its own cumulative withholding, not January's net pay.
      final december = MonthlyCompensation(r.months.last);
      expect(december.totalEstimate, 3367760);
      expect(PayrollBreakdown(r).annualPersonalPensionInsurance, 3168000);
      expect(PayrollBreakdown(r).annualTotalIncomeEstimate, 42105120);
      expect(
        PayrollBreakdown(r).annualTotalIncomeEstimate,
        r.months.fold<int>(
          0,
          (sum, row) => sum + MonthlyCompensation(row).totalEstimate!,
        ),
      );
      final saved = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
      (saved['months'][0]['items'][1] as Map).remove('employeeFixed');
      final old = PayrollResult.fromJson(saved);
      expect(MonthlyCompensation(old.months.first).totalEstimate, null);
      expect(PayrollBreakdown(old).annualTotalIncomeEstimate, null);
      final zero = PayrollEngine.calculate(
        fixture(
          zeroContributions: true,
        ).copyWith(salary: '4000', deduction: '0'),
      ).single;
      expect(MonthlyCompensation(zero.months.first).totalEstimate, 400000);
      expect(PayrollBreakdown(zero).annualPersonalPensionInsurance, 0);
      expect(PayrollBreakdown(zero).annualTotalIncomeEstimate, 4800000);
    },
  );

  test(
    'annual company cost sums every month and includes the bonus exactly once',
    () {
      for (final r in PayrollEngine.calculate(
        fixture().copyWith(bonus: '36000', bonusMonth: 3, bonusEligible: true),
      )) {
        final a = PayrollBreakdown(r);
        expect(
          a.annualTotalIncomeEstimate,
          r.strategy == BonusMode.separate ? 45600000 : 44988000,
        );
        expect(a.annualCompanySocial, 10494000);
        expect(a.annualCompanyHousing, 4752000);
        expect(a.annualCompanyCost, 58446000);
        expect(
          a.annualCompanyCost,
          a.annualGross + a.annualCompanySocial + a.annualCompanyHousing,
        );
        final march = MonthlyCompensation(r.months[2]);
        expect(
          march.totalEstimate,
          (r.months[2]['net'] as int) + 792000 + 66000 + 264000,
        );
      }
      final varying = PayrollEngine.calculate(
        fixture(),
        monthlySalaries: [3300000, ...List.filled(11, 4000000)],
      ).single;
      final totals = PayrollBreakdown(varying);
      expect(totals.annualPersonalPensionInsurance, 3784000);
      expect(
        totals.annualTotalIncomeEstimate,
        varying.months.fold<int>(
          0,
          (sum, row) => sum + MonthlyCompensation(row).totalEstimate!,
        ),
      );
      expect(totals.annualCompanyCost, 65510500);
      expect(
        totals.annualCompanyCost,
        isNot((varying.months.first['employerCost'] as int) * 12),
      );
    },
  );

  test(
    'medical account estimate excludes fixed fees and uses saved monthly contributions',
    () {
      final d = fixture();
      final r = PayrollEngine.calculate(
        d.copyWith(
          overrides: {'med': d.city.items[1].copyWith(employeeFixed: 300)},
        ),
        monthlySalaries: [3300000, 3600000, ...List.filled(10, 4000000)],
      ).single;
      expect(r.itemSum('med', 'employee'), 941600);
      expect(PayrollBreakdown(r).annualMedicalAccountEstimate, 938000);
      final saved = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
      expect(
        PayrollBreakdown(
          PayrollResult.fromJson(saved),
        ).annualMedicalAccountEstimate,
        938000,
      );
      // Missing historical fixed-fee detail must not silently be treated as zero.
      (saved['months'][0]['items'][1] as Map).remove('employeeFixed');
      expect(
        PayrollBreakdown(
          PayrollResult.fromJson(saved),
        ).annualMedicalAccountEstimate,
        null,
      );
      expect(
        PayrollBreakdown(
          PayrollEngine.calculate(fixture(zeroContributions: true)).single,
        ).annualMedicalAccountEstimate,
        0,
      );
    },
  );

  test(
    'annual explanation reconciles the reference salary, taxable income and tax',
    () {
      final r = PayrollEngine.calculate(fixture()).single;
      final a = AnnualTaxBreakdown(r);
      expect(a.gross, 39600000);
      expect(a.basicDeduction, 6000000);
      expect(a.deductible, 8910000);
      expect(a.social, 4158000);
      expect(a.housing, 4752000);
      expect(a.additionalDeduction, 6000000);
      expect(a.taxBase, 18690000);
      expect(a.taxRate, 200000);
      expect(a.quickDeduction, 1692000);
      expect(a.annualWageTax, 2046000);
      expect(a.withheldTax, 2046000);
      expect(a.gross - a.withheldTax - a.social - a.housing, 28644000);
      expect(a.net, 28644000);
      expect(PayrollBreakdown(r).annualTotalIncomeEstimate, 42108000);
      final restored = AnnualTaxBreakdown(
        PayrollResult.fromJson(jsonDecode(jsonEncode(r.toJson()))),
      );
      expect(restored.rawTaxBase, a.rawTaxBase);
      expect(restored.annualWageTax, a.annualWageTax);
    },
  );

  test(
    'annual bonus explanation uses the saved strategy and the correct quick deduction table',
    () {
      final results = PayrollEngine.calculate(
        fixture().copyWith(
          bonus: '36000.01',
          bonusMonth: 3,
          bonusEligible: true,
        ),
      );
      final separate = AnnualTaxBreakdown(results.first);
      final merged = AnnualTaxBreakdown(results.last);
      expect(separate.taxBase, 18690000);
      expect(separate.bonusTaxRate, 100000);
      expect(separate.bonusQuickDeduction, 21000);
      expect(separate.bonusTax, 339000);
      expect(separate.annualWageTax, 2046000);
      expect(merged.taxBase, 22290001);
      expect(merged.bonusTax, 0);
      expect(merged.annualWageTax, 2766000);
      for (final a in [separate, merged]) {
        expect(a.gross - a.withheldTax - a.social - a.housing, a.net);
        expect(a.annualWageTax + a.bonusTax, a.result.annualTaxDue);
      }
    },
  );

  test(
    'annual pension deduction reconciles settlement tax without changing prepaid cash',
    () {
      for (final atSettlement in [false, true]) {
        final a = AnnualTaxBreakdown(
          PayrollEngine.calculate(
            fixture().copyWith(
              pensionMode: PensionMode.once,
              pensionMonth: 12,
              pension: '12000',
              pensionAtSettlement: atSettlement,
            ),
          ).single,
        );
        expect(a.pension, 1200000);
        expect(a.taxBase, 17490000);
        expect(a.annualWageTax, 1806000);
        expect(a.withholdingTaxBase, atSettlement ? 18690000 : 17490000);
        expect(a.withheldTax, atSettlement ? 2046000 : 1806000);
        expect(a.result.refundEstimate, atSettlement ? 240000 : 0);
        expect(a.net - a.result.sum('available'), 1200000);
        final income = PayrollBreakdown(a.result);
        // Use employee social-insurance payments, not voluntary pension deposits.
        expect(income.annualPersonalPensionInsurance, 3168000);
        expect(
          income.annualTotalIncomeEstimate,
          atSettlement ? 42108000 : 42348000,
        );
        expect(
          income.annualTotalIncomeEstimate,
          a.result.months.fold<int>(
            0,
            (sum, row) => sum + MonthlyCompensation(row).totalEstimate!,
          ),
        );
        for (final row in a.result.months) {
          final month = MonthlyCompensation(row);
          expect(
            month.totalEstimate! -
                month.net -
                month.housing -
                month.medicalAccountEstimate!,
            month.personalPensionInsurance,
          );
        }
      }
    },
  );

  test(
    'annual taxable income uses confirmed deductible contributions and noncash benefits',
    () {
      final a = AnnualTaxBreakdown(
        PayrollEngine.calculate(
          fixture().copyWith(deductible: '1000', taxableBenefit: '200'),
        ).single,
      );
      expect(a.hasCustomDeductible, isTrue);
      expect(a.income, 39840000);
      expect(a.gross, 39600000);
      expect(a.deductible, 1200000);
      expect(a.taxBase, 26640000);
      expect(a.annualWageTax, 3636000);
      expect(a.social + a.housing, 8910000);
      expect(a.net, 27054000);
    },
  );

  test(
    'negative annual taxable income does not erase tax already withheld',
    () {
      final a = AnnualTaxBreakdown(
        PayrollEngine.calculate(
          fixture(zeroContributions: true).copyWith(deduction: '0'),
          monthlySalaries: [2000000, ...List.filled(11, 0)],
        ).single,
      );
      expect(a.rawTaxBase, -4000000);
      expect(a.taxBase, 0);
      expect(a.annualWageTax, 0);
      expect(a.withheldTax, 45000);
      expect(a.result.refundEstimate, 45000);
      expect(a.net, 1955000);
    },
  );

  test(
    'reference screenshots reconcile annual, monthly and contribution amounts',
    () {
      final r = PayrollEngine.calculate(fixture()).single;
      final a = PayrollBreakdown(r), m = a.month(1);
      expect(a.annualGross, 39600000);
      expect(a.annualAdditionalDeduction, 6000000);
      expect(a.annualSocial, 4158000);
      expect(r.sum('housing'), 9504000);
      expect(m.personalSocial, 346500);
      expect(m.companySocial, 874500);
      expect(m.housing.employee, 396000);
      expect(m.housing.employer, 396000);
      expect(m.regularCompanyCost, 4570500);
      expect(m.value('net'), 2510775);
      expect(m.value('tax'), 46725);
      expect(m.cumulativeIncome, 3300000);
      expect(m.deductionTotal, 1742500);
      expect(m.value('taxBase'), 1557500);
      expect(m.previouslyPaid, 0);
      expect(a.month(3).previouslyPaid, 93450);
      expect(a.month(12).value('taxBase'), 18690000);
      expect(
        r.sum('net'),
        a.annualGross -
            a.annualSocial -
            r.itemSum('hf', 'employee') -
            r.sum('tax'),
      );
      for (var i = 1; i <= 12; i++) {
        final month = a.month(i);
        expect(month.rawTaxBaseFromParts, month.value('rawTaxBase'));
      }
    },
  );
  test(
    'bonus months keep separate tax out of cumulative wage income and prior wage tax',
    () {
      final results = PayrollEngine.calculate(
        fixture().copyWith(bonus: '36000', bonusMonth: 3, bonusEligible: true),
      );
      final separate = MonthBreakdown(results.first, 3);
      final merged = MonthBreakdown(results.last, 3);
      expect(separate.cumulativeMergedBonus, 0);
      expect(merged.cumulativeMergedBonus, 3600000);
      expect(merged.cumulativeIncome - separate.cumulativeIncome, 3600000);
      expect(separate.value('bonusTax'), 108000);
      expect(
        MonthBreakdown(results.first, 4).previouslyPaid,
        results.first.months
            .take(3)
            .fold<int>(0, (sum, m) => sum + (m['wageTax'] as int)),
      );
      for (final r in results) {
        final m = MonthBreakdown(r, 3);
        expect(
          m.value('net'),
          m.gross - m.personalSocial - m.housing.employee - m.value('tax'),
        );
        expect(m.rawTaxBaseFromParts, m.value('rawTaxBase'));
        expect(
          m.regularCompanyCost + m.value('bonus'),
          m.value('employerCost'),
        );
      }
    },
  );
  test(
    'pension payment does not reduce displayed salary cash; deduction respects timing',
    () {
      for (final settlement in [false, true]) {
        final r = PayrollEngine.calculate(
          fixture().copyWith(
            pensionMode: PensionMode.monthly,
            pension: '1000',
            pensionAtSettlement: settlement,
          ),
        ).single;
        final m = MonthBreakdown(r, 6);
        expect(m.cumulativePensionDeduction, settlement ? 0 : 600000);
        expect(m.rawTaxBaseFromParts, m.value('rawTaxBase'));
        expect(m.value('net') - m.value('available'), 100000);
        expect(
          r.sum('net'),
          PayrollBreakdown(r).annualGross - r.sum('employee') - r.sum('tax'),
        );
      }
    },
  );
  test(
    'custom deductible and changing pay use actual cumulative amounts and item bases',
    () {
      final draft = fixture();
      final r = PayrollEngine.calculate(
        draft.copyWith(
          deductible: '1000',
          taxableBenefit: '200',
          overrides: {
            'pension': draft.city.items.first.copyWith(actualBase: 1800000),
            'hf': draft.city.items.last.copyWith(actualBase: 2200000),
          },
        ),
        monthlySalaries: [3300000, 3600000, ...List.filled(10, 4000000)],
      ).single;
      final m = MonthBreakdown(r, 2);
      expect(m.cumulativeSalary, 6900000);
      expect(m.cumulativeBenefit, 40000);
      expect(m.cumulativeDeductible, 200000);
      expect(m.hasCustomDeductible, isTrue);
      expect(m.socialItems.first.base, 1800000);
      expect(m.housing.base, 2200000);
      expect(m.rawTaxBaseFromParts, m.value('rawTaxBase'));
      expect(m.socialBaseDescription, contains('不同'));
    },
  );
  test('negative tax basis and zero contributions remain explainable', () {
    final r = PayrollEngine.calculate(
      fixture(zeroContributions: true).copyWith(salary: '4000', deduction: '0'),
    ).single;
    final m = MonthBreakdown(r, 2);
    expect(m.rawTaxBaseFromParts, -200000);
    expect(m.value('rawTaxBase'), -200000);
    expect(m.value('taxBase'), 0);
    expect(m.housing.employee + m.housing.employer, 0);
    expect(m.personalSocial, 0);
  });
  test(
    'restored snapshots produce the same explanations without current city data',
    () {
      final r = PayrollEngine.calculate(fixture()).single;
      final loaded = PayrollResult.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(PayrollBreakdown(loaded).annualSocial, 4158000);
      expect(MonthBreakdown(loaded, 12).rawTaxBaseFromParts, 18690000);
    },
  );
}
