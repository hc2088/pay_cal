import '../calculation/money_format.dart';
import 'payroll_models.dart';
import 'payroll_breakdown.dart';
import 'plan_snapshot_details.dart';

class ComparisonMetric {
  const ComparisonMetric(this.label, this.a, this.b, {this.comparable = true});
  final String label;
  final int? a, b;
  final bool comparable;
  int? get difference => comparable && a != null && b != null ? b! - a! : null;
  bool get isDifferent => !comparable || a == null || b == null || a != b;
}

class PayrollComparison {
  PayrollComparison(this.a, this.b, this.month);
  final PayrollPlan a, b;
  final int month;
  bool get sameYear =>
      a.result != null &&
      b.result != null &&
      a.result!.draft.year == b.result!.draft.year;

  ComparisonMetric _metric(String label, int? Function(PayrollPlan) value) =>
      ComparisonMetric(label, value(a), value(b), comparable: sameYear);

  bool get hasBonus =>
      [a, b].any((p) => p.result != null && p.result!.sum('bonus') > 0);

  int? _sumRecordedMonths(PayrollPlan p, String field) {
    final rows = p.legacy?['months'];
    if (rows is! List ||
        rows.length != 12 ||
        rows.any((m) => m[field] is! int)) {
      return null;
    }
    return rows.fold<int>(0, (sum, m) => sum + (m[field] as int));
  }

  int? _social(PayrollPlan p, {required bool annual}) {
    if (p.result == null) return null;
    return annual
        ? PayrollBreakdown(p.result!).annualSocial
        : MonthBreakdown(p.result!, month).personalSocial;
  }

  int? _medicalAccount(PayrollPlan p, {required bool annual}) {
    final r = p.result;
    if (r == null) return null;
    return annual
        ? PayrollBreakdown(r).annualMedicalAccountEstimate
        : MonthlyCompensation(r.months[month - 1]).medicalAccountEstimate;
  }

  int? _inclusiveIncome(PayrollPlan p, {required bool annual}) {
    final r = p.result;
    if (r == null) return null;
    return annual
        ? PayrollBreakdown(r).annualTotalIncomeEstimate
        : MonthlyCompensation(r.months[month - 1]).totalEstimate;
  }

  List<ComparisonMetric> get overviewAnnual => [
    _metric('【年】单位成本', (p) => _value(p, 'employerCost')),
    _metric('【年】个人税后收入', (p) => _value(p, 'net')),
    _metric(
      '【年】个人税后收入（加公积金、个人医保、个人养老保险）',
      (p) => _inclusiveIncome(p, annual: true),
    ),
    _metric(
      hasBonus ? '【年】税前收入（含奖金）' : '【年】税前工资',
      (p) => p.result != null
          ? PayrollBreakdown(p.result!).annualGross
          : _sumRecordedMonths(p, 'salaryCents'),
    ),
    if (hasBonus) _metric('【年】年终奖', (p) => _value(p, 'bonus')),
    _metric('【年】个税', (p) => _value(p, 'tax')),
    _metric('【年】应纳个税（汇算估算）', (p) => p.result?.annualTaxDue),
    _metric('【年】公积金（公司＋个人）', (p) => _value(p, 'housing')),
    _metric('【年】医保个人账户（估算）', (p) => _medicalAccount(p, annual: true)),
    _metric(
      '【年】养老保险（个人）',
      (p) => _item(p, 'pension', 'employee', annual: true),
    ),
    _metric('【年】社保（个人）', (p) => _social(p, annual: true)),
    _metric('【年】个人养老金', (p) => _value(p, 'pension')),
    _metric('【年】专项附加扣除', (p) {
      final monthly = PlanSnapshotDetails(p).additionalDeduction;
      return monthly == null ? null : monthly * 12;
    }),
    _metric('【年】养老金投入后可用现金', (p) => _value(p, 'available')),
  ];

  List<ComparisonMetric> get overviewMonthly => [
    _metric('【月】单位成本', (p) => _value(p, 'employerCost', annual: false)),
    _metric('【月】个人税后收入', (p) => _value(p, 'net', annual: false)),
    _metric(
      '【月】个人税后收入（加公积金、个人医保、个人养老保险）',
      (p) => _inclusiveIncome(p, annual: false),
    ),
    _metric('【月】税前工资', (p) => _value(p, 'salary', annual: false)),
    if (hasBonus) _metric('【月】年终奖', (p) => _value(p, 'bonus', annual: false)),
    _metric('【月】个税', (p) => _value(p, 'tax', annual: false)),
    _metric('【月】公积金（公司＋个人）', (p) => _value(p, 'housing', annual: false)),
    _metric('【月】医保个人账户（估算）', (p) => _medicalAccount(p, annual: false)),
    _metric('【月】社保（个人）', (p) => _social(p, annual: false)),
    for (final kind in contributionNames.keys)
      _metric(
        '【月】${contributionNames[kind]}（个人）',
        (p) => _item(p, kind, 'employee'),
      ),
    for (final kind in contributionNames.keys)
      _metric(
        '【月】${contributionNames[kind]}（单位）',
        (p) => _item(p, kind, 'employer'),
      ),
    _metric('【月】五险一金合计（个人）', (p) => _value(p, 'employee', annual: false)),
    _metric('【月】五险一金合计（单位）', (p) => _value(p, 'employer', annual: false)),
    _metric('【月】个人养老金', (p) => _value(p, 'pension', annual: false)),
    _metric('【月】养老金投入后可用现金', (p) => _value(p, 'available', annual: false)),
    _metric('【月】专项附加扣除', (p) => PlanSnapshotDetails(p).additionalDeduction),
    _metric('【月】个人缴费可税前扣除额', (p) => _value(p, 'deductible', annual: false)),
    _metric('【月】单位应税福利', (p) {
      final value = p.result?.draft.taxableBenefit;
      return value == null
          ? null
          : value.trim().isEmpty
          ? 0
          : parseDecimal(value, 2);
    }),
  ];

  int? _value(PayrollPlan p, String field, {bool annual = true}) {
    if (p.result != null) {
      return annual
          ? p.result!.sum(field)
          : p.result!.months[month - 1][field] as int?;
    }
    if (field == 'housing') {
      final x = _item(p, 'hf', 'employer', annual: annual),
          y = _item(p, 'hf', 'employee', annual: annual);
      return x == null || y == null ? null : x + y;
    }
    if (annual) return p.value(field);
    final rows = p.legacy?['months'];
    if (rows is! List || rows.length != 12) return null;
    final key = {
      'net': 'netCashCents',
      'tax': 'monthlyTaxCents',
      'employerCost': 'employerTotalCostCents',
      'salary': 'salaryCents',
    }[field];
    return key == null ? null : rows[month - 1][key] as int?;
  }

  int? _item(PayrollPlan p, String kind, String side, {bool annual = false}) {
    if (p.result != null) {
      return p.result!.itemSum(kind, side, month: annual ? null : month);
    }
    final suffix = {
      'pension': 'PensionCents',
      'med': 'MedicalCents',
      'unemp': 'UnemploymentCents',
      'inj': 'WorkInjuryCents',
      'hf': 'HousingFundCents',
    }[kind];
    if (suffix == null) return null;
    if (annual) {
      final sideName = side == 'employee' ? 'Employee' : 'Employer';
      final saved = p.legacy?['annual$sideName$suffix'];
      return saved is int ? saved : _sumRecordedMonths(p, '$side$suffix');
    }
    final rows = p.legacy?['months'];
    if (rows is! List || rows.length != 12) return null;
    return rows[month - 1]['$side$suffix'] as int?;
  }

  Map<String, (String, String)> _settings(
    Map<String, String Function(PayrollPlan)> fields,
  ) => {for (final e in fields.entries) e.key: (e.value(a), e.value(b))};

  Map<String, (String, String)> get annualSettings => _settings({
    '【年】城市': (p) => p.result?.draft.city.name ?? '未记录',
    '【年】测算年度': (p) => p.result?.draft.year.toString() ?? '未记录',
    '【年】年终奖计算方式': (p) => PlanSnapshotDetails(p).bonusMethod,
    if (hasBonus)
      '【年】奖金发放月份': (p) => p.result == null
          ? '未记录'
          : p.result!.sum('bonus') == 0
          ? '无年终奖'
          : '${p.result!.draft.bonusMonth} 月',
    '【年】个人养老金缴纳计划': (p) => PlanSnapshotDetails(p).pension,
    '【年】个人养老金扣除时点': (p) => p.result == null
        ? '未记录'
        : p.result!.draft.pensionAtSettlement
        ? '年度汇算'
        : '当月预扣',
    '【年】规则版本': (p) =>
        p.result?.draft.city.version ??
        p.legacy?['rulesVersion'] as String? ??
        '旧版',
    '【年】计算引擎': (p) => p.result?.engineVersion ?? '旧版',
  });

  // Numeric values and applied rates come from the selected saved month.
  // Range/override metadata comes only from the policy embedded in that snapshot.
  Map<String, dynamic>? _savedItem(PayrollPlan p, String kind) =>
      p.result == null
      ? null
      : (p.result!.months[month - 1]['items'] as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e['kind'] == kind)
            .firstOrNull;

  Contribution? _savedRule(PayrollPlan p, String kind) {
    final d = p.result?.draft;
    if (d == null) return null;
    if (d.overrides.containsKey(kind)) return d.overrides[kind];
    if (d.estimateConfirmed) {
      return d.city.items.where((e) => e.kind == kind).firstOrNull;
    }
    final periods = d.city.periods
        .where((e) => e.contains(DateTime(d.year, month)))
        .toList();
    if (periods.length != 1) return null;
    return periods.single.items.where((e) => e.kind == kind).firstOrNull;
  }

  String _money(int? value) => value == null ? '未记录' : formatCents(value);

  Map<String, (String, String)> get monthlySettings => _settings({
    '【月】医保档次': (p) => p.result == null
        ? '未记录'
        : p.result!.draft.medicalTier.isEmpty
        ? '默认 / 不分档'
        : p.result!.draft.medicalTier,
    '【月】个人缴费扣除方式': (p) => p.result == null
        ? '未记录'
        : p.result!.draft.deductible.isEmpty
        ? '按个人实际缴费估算'
        : '自定义扣除额',
    '【月】社保参考基数': (p) => p.result == null
        ? '未记录'
        : p.result!.draft.socialBase.isEmpty
        ? '跟随工资'
        : _money(parseDecimal(p.result!.draft.socialBase, 2)),
    '【月】公积金参考基数': (p) => p.result == null
        ? '未记录'
        : p.result!.draft.housingBase.isEmpty
        ? '跟随社保'
        : _money(parseDecimal(p.result!.draft.housingBase, 2)),
    for (final kind in contributionNames.keys) ...{
      '【月】${contributionNames[kind]}缴纳基数': (p) {
        final item = _savedItem(p, kind), rule = _savedRule(p, kind);
        final specified = rule == null
            ? '未记录'
            : rule.actualBase == null
            ? '跟随参考基数'
            : _money(rule.actualBase);
        return '实际 ${_money(item?['base'] as int?)}\n指定 $specified';
      },
      '【月】${contributionNames[kind]}比例（个人 / 单位）': (p) {
        final item = _savedItem(p, kind);
        return '${rateText(item?['employeeRate'] as int?)} / ${rateText(item?['employerRate'] as int?)}';
      },
      '【月】${contributionNames[kind]}基数范围': (p) {
        final rule = _savedRule(p, kind);
        return rule == null
            ? '未记录'
            : '${_money(rule.minBase)} – ${_money(rule.maxBase)}';
      },
      '【月】${contributionNames[kind]}固定费用（个人 / 单位）': (p) {
        final item = _savedItem(p, kind);
        return '${_money(item?['employeeFixed'] as int?)} / ${_money(item?['employerFixed'] as int?)}';
      },
      '【月】${contributionNames[kind]}舍入单位': (p) =>
          _money(_savedItem(p, kind)?['roundingUnit'] as int?),
    },
  });
}
