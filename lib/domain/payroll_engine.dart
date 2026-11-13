import 'dart:math' as math;

import 'payroll_models.dart';

class PayrollException implements Exception {
  PayrollException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PayrollEngine {
  static const limits = [
    3600000,
    14400000,
    30000000,
    42000000,
    66000000,
    96000000,
  ];
  static const rates = [30000, 100000, 200000, 250000, 300000, 350000, 450000];
  static const wageQuick = [
    0,
    252000,
    1692000,
    3192000,
    5292000,
    8592000,
    18192000,
  ];
  static const bonusQuick = [0, 21000, 141000, 266000, 441000, 716000, 1516000];

  static int percentage(int base, int rate, {int unit = 1}) =>
      ((base * rate + rateScale * unit ~/ 2) ~/ (rateScale * unit)) * unit;
  static int bracket(int base) {
    for (var i = 0; i < limits.length; i++) {
      if (base <= limits[i]) return i;
    }
    return rates.length - 1;
  }

  static int wageTax(int base) {
    final taxable = math.max(0, base), i = bracket(taxable);
    return math.max(0, percentage(taxable, rates[i]) - wageQuick[i]);
  }

  static int separateBonusTax(int bonus) {
    final i = bracket(bonus);
    return math.max(0, percentage(bonus, rates[i]) - bonusQuick[i]);
  }

  static int amount(String raw, String label, {bool optional = false}) {
    final value = optional && raw.trim().isEmpty ? 0 : parseDecimal(raw, 2);
    if (value == null) {
      throw PayrollException('$label：请输入不超过 999,999,999.99 的非负金额，最多两位小数');
    }
    return value;
  }

  static List<Contribution> resolve(PayrollDraft draft, int month) {
    if (draft.estimateConfirmed) return draft.effectiveItems;
    final date = DateTime(draft.year, month);
    final matches = draft.city.periods.where((e) => e.contains(date)).toList();
    if (matches.length != 1 || !matches.single.verified) {
      throw PayrollException(
        '${draft.year} 年 $month 月规则未完整核验。请核对缴费设置后，明确选择按当前参数自定义估算全年。',
      );
    }
    return matches.single.items
        .map((e) => draft.overrides[e.kind] ?? e)
        .toList();
  }

  static List<PayrollResult> calculate(
    PayrollDraft draft, {
    List<int>? monthlySalaries,
  }) {
    amount(draft.salary, '税前月薪');
    final bonus = amount(draft.bonus, '年终奖', optional: true);
    if (bonus > 0 && draft.bonusMode != BonusMode.merged) {
      if (!draft.bonusEligible) {
        throw PayrollException('请确认奖金符合全年一次性奖金条件，且本年未使用单独计税。');
      }
      if (draft.year < 2024 || draft.year > 2027) {
        throw PayrollException('当前内置奖金单独计税规则仅覆盖 2024–2027 年，请选择并入计税或更新规则。');
      }
    }
    if (draft.city.tiers.isNotEmpty && draft.medicalTier.isEmpty) {
      throw PayrollException('请在五险一金设置中选择医保档次。');
    }
    final strategies = bonus == 0
        ? [BonusMode.merged]
        : draft.bonusMode == BonusMode.compare
        ? [BonusMode.separate, BonusMode.merged]
        : [draft.bonusMode];
    return strategies
        .map((s) => _calculate(draft, s, monthlySalaries))
        .toList();
  }

  static PayrollResult _calculate(
    PayrollDraft d,
    BonusMode strategy,
    List<int>? salaries,
  ) {
    final salary = amount(d.salary, '税前月薪');
    final deduction = amount(d.deduction, '专项附加扣除', optional: true);
    final bonus = amount(d.bonus, '年终奖', optional: true);
    final pension = d.pensionMode == PensionMode.none
        ? 0
        : amount(d.pension, '个人养老金');
    final annualPension = d.pensionMode == PensionMode.monthly
        ? pension * 12
        : pension;
    if (annualPension > 1200000) {
      throw PayrollException('个人养老金全年缴费不能超过 12,000 元。');
    }
    if (annualPension > 0 && d.year < 2024) {
      throw PayrollException('当前个人养老金扣除规则从 2024 年起适用。');
    }
    if (d.bonusMonth < 1 ||
        d.bonusMonth > 12 ||
        d.pensionMonth < 1 ||
        d.pensionMonth > 12) {
      throw PayrollException('月份须在 1–12 之间。');
    }
    if (salaries != null &&
        (salaries.length != 12 ||
            salaries.any((v) => v < 0 || v > moneyLimit))) {
      throw PayrollException('工资计划必须包含有效的 12 个月。');
    }
    final knownSocial = d.socialBase.trim().isEmpty
        ? null
        : amount(d.socialBase, '社保参考基数');
    final knownHousing = d.housingBase.trim().isEmpty
        ? null
        : amount(d.housingBase, '公积金参考基数');
    final knownDeductible = d.deductible.trim().isEmpty
        ? null
        : amount(d.deductible, '已确认月税前扣除额');
    final benefit = amount(d.taxableBenefit, '单位应税福利', optional: true);
    var rawTaxBase = 0, paid = 0, annualRawBeforePension = 0, bonusTaxTotal = 0;
    final months = <Map<String, dynamic>>[];
    for (var month = 1; month <= 12; month++) {
      final monthlySalary = salaries?[month - 1] ?? salary;
      final rules = resolve(d, month);
      if (rules.length != 6 || rules.map((e) => e.kind).toSet().length != 6) {
        throw PayrollException('五险一金配置不完整或存在重复项目。');
      }
      var employee = 0, employer = 0, housing = 0;
      final details = <Map<String, dynamic>>[];
      for (final r in rules) {
        if (!r.complete) throw PayrollException('${r.label}缺少基数范围或比例，请补齐后测算。');
        if (r.minBase! < 0 ||
            r.maxBase! < r.minBase! ||
            r.maxBase! > moneyLimit ||
            r.employeeRate! < 0 ||
            r.employeeRate! > rateScale ||
            r.employerRate! < 0 ||
            r.employerRate! > rateScale ||
            r.employeeFixed < 0 ||
            r.employerFixed < 0 ||
            !{1, 100}.contains(r.roundingUnit)) {
          throw PayrollException('${r.label}的范围、比例或舍入设置不正确。');
        }
        final original = d.city.items.firstWhere((e) => e.kind == r.kind);
        final exceeds =
            r.kind == 'hf' &&
            r.defaultRateMax != null &&
            (r.employeeRate! > r.defaultRateMax! ||
                r.employerRate! > r.defaultRateMax!);
        final changedBounds =
            r.minBase != original.minBase || r.maxBase != original.maxBase;
        if ((exceeds || changedBounds) && knownDeductible == null) {
          throw PayrollException(
            '修改基数边界或超范围比例后，请填写已确认的月税前扣除额与单位应税福利，不能自动全额扣除。',
          );
        }
        final reference =
            r.actualBase ??
            (r.kind == 'hf'
                ? (knownHousing ?? knownSocial ?? monthlySalary)
                : (knownSocial ?? monthlySalary));
        if (reference < 0 || reference > moneyLimit) {
          throw PayrollException('${r.label}实际基数超出范围。');
        }
        final base = reference.clamp(r.minBase!, r.maxBase!);
        final personal =
            percentage(base, r.employeeRate!, unit: r.roundingUnit) +
            r.employeeFixed;
        final company =
            percentage(base, r.employerRate!, unit: r.roundingUnit) +
            r.employerFixed;
        employee += personal;
        employer += company;
        if (r.kind == 'hf') housing = personal + company;
        details.add({
          'kind': r.kind,
          'reference': reference,
          'base': base,
          'employee': personal,
          'employer': company,
          'employeeRate': r.employeeRate,
          'employerRate': r.employerRate,
          'employeeFixed': r.employeeFixed,
          'employerFixed': r.employerFixed,
          'roundingUnit': r.roundingUnit,
        });
      }
      final deductible = knownDeductible ?? employee;
      if (deductible > employee) {
        throw PayrollException('已确认月税前扣除额不能超过该月个人实际缴费。');
      }
      final monthlyBonus = month == d.bonusMonth ? bonus : 0;
      final monthlyPension = d.pensionMode == PensionMode.monthly
          ? pension
          : d.pensionMode == PensionMode.once && month == d.pensionMonth
          ? pension
          : 0;
      final beforePension =
          monthlySalary +
          (strategy == BonusMode.merged ? monthlyBonus : 0) +
          benefit -
          deductible -
          deduction -
          500000;
      annualRawBeforePension += beforePension;
      rawTaxBase +=
          beforePension - (d.pensionAtSettlement ? 0 : monthlyPension);
      final taxBase = math.max(0, rawTaxBase),
          index = bracket(taxBase),
          due = wageTax(taxBase);
      final withholding = math.max(0, due - paid);
      paid += withholding;
      final bonusTax = strategy == BonusMode.separate
          ? separateBonusTax(monthlyBonus)
          : 0;
      bonusTaxTotal += bonusTax;
      final tax = withholding + bonusTax,
          net = monthlySalary + monthlyBonus - employee - tax;
      months.add({
        'month': month,
        'salary': monthlySalary,
        'bonus': monthlyBonus,
        'employee': employee,
        'employer': employer,
        'tax': tax,
        'wageTax': withholding,
        'bonusTax': bonusTax,
        'net': net,
        'available': net - monthlyPension,
        'pension': monthlyPension,
        'housing': housing,
        'employerCost': monthlySalary + monthlyBonus + employer,
        'rawTaxBase': rawTaxBase,
        'taxBase': taxBase,
        'taxRate': rates[index],
        'quick': wageQuick[index],
        'cumulativeDue': due,
        'cumulativePaid': paid,
        'deductible': deductible,
        'items': details,
      });
    }
    final annualWageTax = wageTax(annualRawBeforePension - annualPension);
    return PayrollResult(
      draft: d,
      strategy: strategy,
      months: months,
      annualTaxDue: annualWageTax + bonusTaxTotal,
      refundEstimate: paid - annualWageTax,
      createdAt: DateTime.now(),
    );
  }
}
