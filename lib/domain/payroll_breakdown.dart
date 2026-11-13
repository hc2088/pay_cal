import 'dart:math' as math;
import 'payroll_engine.dart';
import 'payroll_models.dart';

/// Presentation amounts read only from the saved calculation snapshot.
/// Never resolve today's city policy or recalculate historical tax here.
class PayrollBreakdown {
  const PayrollBreakdown(this.result);
  final PayrollResult result;

  int get annualGross => result.sum('salary') + result.sum('bonus');
  int get annualSocial =>
      result.sum('employee') - result.itemSum('hf', 'employee');
  int get annualAdditionalDeduction =>
      _amount(result.draft.deduction) * result.months.length;
  int get annualCompanyHousing => result.itemSum('hf', 'employer');
  int get annualCompanySocial => result.sum('employer') - annualCompanyHousing;
  int get annualCompanyCost => result.sum('employerCost');
  int get annualPersonalPensionInsurance =>
      result.itemSum('pension', 'employee');

  /// Estimate the employee's medical-account allocation from the saved
  /// proportional contribution. Fixed mutual-aid charges are not allocations.
  /// Older snapshots without a fixed-charge split cannot establish this value.
  int? get annualMedicalAccountEstimate {
    var total = 0;
    for (final row in result.months) {
      final amount = MonthlyCompensation(row).medicalAccountEstimate;
      if (amount == null) return null;
      total += amount;
    }
    return total;
  }

  int? get annualTotalIncomeEstimate {
    final medical = annualMedicalAccountEstimate;
    return medical == null
        ? null
        : result.sum('net') +
              result.sum('housing') +
              medical +
              annualPersonalPensionInsurance;
  }

  MonthBreakdown month(int month) => MonthBreakdown(result, month);
}

/// Cash salary plus housing deposits, estimated medical-account allocation,
/// and employee pension insurance. This is not gross pay or spendable cash.
class MonthlyCompensation {
  const MonthlyCompensation(this.data);
  final Map<String, dynamic> data;
  int get net => data['net'] as int;
  int get housing => data['housing'] as int;
  int get personalPensionInsurance =>
      (data['items'] as List).firstWhere(
            (item) => item['kind'] == 'pension',
          )['employee']
          as int;
  int? get medicalAccountEstimate {
    final medical = (data['items'] as List).firstWhere(
      (item) => item['kind'] == 'med',
    );
    final paid = medical['employee'], fixed = medical['employeeFixed'];
    if (paid is! int || fixed is! int || fixed < 0 || fixed > paid) return null;
    return paid - fixed;
  }

  int? get totalEstimate {
    final medical = medicalAccountEstimate;
    return medical == null
        ? null
        : net + housing + medical + personalPensionInsurance;
  }
}

/// Annual explanation of a saved result. Paid tax and annual tax due remain
/// separate: pension deductions at settlement and falling cumulative income
/// can make withholding greater than the final annual liability.
class AnnualTaxBreakdown {
  AnnualTaxBreakdown(this.result) : december = MonthBreakdown(result, 12);
  final PayrollResult result;
  final MonthBreakdown december;
  int get salary => result.sum('salary');
  int get bonus => result.sum('bonus');
  bool get separateBonus => result.strategy == BonusMode.separate && bonus > 0;
  int get mergedBonus => separateBonus ? 0 : bonus;
  int get benefit => december.cumulativeBenefit;
  int get gross => salary + bonus;
  int get income => salary + mergedBonus + benefit;
  int get social => december.cumulativeSocial;
  int get housing => december.cumulativeHousing;
  int get deductible => december.cumulativeDeductible;
  bool get hasCustomDeductible => december.hasCustomDeductible;
  int get basicDeduction => december.cumulativeBasicDeduction;
  int get additionalDeduction => december.cumulativeAdditionalDeduction;
  int get pension => result.sum('pension');
  int get deductionTotal =>
      basicDeduction + deductible + additionalDeduction + pension;
  int get rawTaxBase => income - deductionTotal;
  int get taxBase => math.max(0, rawTaxBase);
  int get taxBracket => PayrollEngine.bracket(taxBase);
  int get taxRate => PayrollEngine.rates[taxBracket];
  int get quickDeduction => PayrollEngine.wageQuick[taxBracket];
  int get bonusTax => result.sum('bonusTax');
  int get bonusTaxRate => PayrollEngine.rates[PayrollEngine.bracket(bonus)];
  int get bonusQuickDeduction =>
      PayrollEngine.bonusQuick[PayrollEngine.bracket(bonus)];
  int get annualWageTax => result.annualTaxDue - bonusTax;
  int get withheldWageTax => result.sum('wageTax');
  int get withheldTax => result.sum('tax');
  int get net => result.sum('net');
  int get withholdingTaxBase => december.value('taxBase');
}

class ContributionBreakdown {
  const ContributionBreakdown(this.data);
  final Map<String, dynamic> data;
  String get kind => data['kind'] as String;
  String get name => contributionNames[kind]!;
  int value(String key) => data[key] as int? ?? 0;
  int get base => value('base');
  int get employee => value('employee');
  int get employer => value('employer');
}

class MonthBreakdown {
  MonthBreakdown(this.result, this.month)
    : data = result.months.firstWhere((m) => m['month'] == month);
  final PayrollResult result;
  final int month;
  final Map<String, dynamic> data;
  int value(String key) => data[key] as int;
  List<ContributionBreakdown> get items => (data['items'] as List)
      .map((e) => ContributionBreakdown(e as Map<String, dynamic>))
      .toList();
  List<ContributionBreakdown> get socialItems =>
      items.where((e) => e.kind != 'hf').toList();
  ContributionBreakdown get housing => items.singleWhere((e) => e.kind == 'hf');
  int get personalSocial => value('employee') - housing.employee;
  int get companySocial => value('employer') - housing.employer;
  int get regularCompanyCost => value('salary') + value('employer');
  int get gross => value('salary') + value('bonus');
  int get previouslyPaid => value('cumulativePaid') - value('wageTax');

  Iterable<Map<String, dynamic>> get _throughMonth =>
      result.months.where((m) => (m['month'] as int) <= month);
  int cumulative(String key) =>
      _throughMonth.fold(0, (sum, m) => sum + (m[key] as int));
  int get cumulativeSalary => cumulative('salary');
  int get cumulativeMergedBonus =>
      result.strategy == BonusMode.merged ? cumulative('bonus') : 0;
  int get cumulativeBenefit =>
      _amount(result.draft.taxableBenefit) * _throughMonth.length;
  int get cumulativeIncome =>
      cumulativeSalary + cumulativeMergedBonus + cumulativeBenefit;
  int get cumulativeBasicDeduction => 500000 * _throughMonth.length;
  int get cumulativeAdditionalDeduction =>
      _amount(result.draft.deduction) * _throughMonth.length;
  int get cumulativePensionDeduction =>
      result.draft.pensionAtSettlement ? 0 : cumulative('pension');
  int get cumulativeHousing => _throughMonth.fold(
    0,
    (sum, m) =>
        sum +
        (m['items'] as List)
            .where((e) => e['kind'] == 'hf')
            .fold<int>(0, (sum, e) => sum + (e['employee'] as int)),
  );
  int get cumulativeSocial => cumulative('employee') - cumulativeHousing;
  int get cumulativeDeductible => cumulative('deductible');
  bool get hasCustomDeductible =>
      cumulativeDeductible != cumulative('employee');
  int get deductionTotal =>
      cumulativeBasicDeduction +
      cumulativeDeductible +
      cumulativeAdditionalDeduction +
      cumulativePensionDeduction;
  int get rawTaxBaseFromParts => cumulativeIncome - deductionTotal;

  String get socialBaseDescription {
    final bases = socialItems.map((e) => e.base).toSet();
    return bases.length == 1
        ? '缴费基数 ${decimalText(bases.single, 2)} 元'
        : '各险种缴费基数不同，见下方明细';
  }
}

int _amount(String value) => value.trim().isEmpty ? 0 : parseDecimal(value, 2)!;
