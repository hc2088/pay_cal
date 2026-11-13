import '../calculation/money_format.dart';
import 'payroll_models.dart';

/// Compact plan metadata uses saved contributions, not today's city defaults.
class PlanSnapshotDetails {
  const PlanSnapshotDetails(this.plan);

  /// Unsaved results use the same presentation snapshot as saved plans.
  /// This wrapper does not save a plan or resolve current city parameters.
  factory PlanSnapshotDetails.fromResult(PayrollResult result) =>
      PlanSnapshotDetails(
        PayrollPlan(
          id: result.draft.id,
          name: '',
          savedAt: result.createdAt,
          result: result,
        ),
      );
  final PayrollPlan plan;
  PayrollResult? get result => plan.result;

  Map<String, dynamic> get _legacyInputs =>
      (plan.legacy?['inputs'] as Map?)?.cast<String, dynamic>() ?? {};

  String get monthlySalary {
    final r = result;
    if (r != null) return _range(r.months.map((m) => m['salary'] as int));
    return _money(_legacyInputs['grossMonthlySalaryCents'] as int?);
  }

  List<int> _itemValues(String kind, String field) => [
    for (final month in result!.months)
      for (final item in month['items'] as List)
        if (item['kind'] == kind && item[field] is int) item[field] as int,
  ];

  String get socialBases {
    if (result == null) {
      final rows = plan.legacy?['months'];
      final recorded = rows is List
          ? rows
                .where((m) => m['socialBaseCents'] is int)
                .map((m) => m['socialBaseCents'] as int)
                .toList()
          : <int>[];
      return recorded.isEmpty ? '未记录实际基数' : '基数 ${_range(recorded)}';
    }
    final groups = <String, List<String>>{};
    for (final entry in const {
      'pension': '养老',
      'med': '医疗',
      'unemp': '失业',
      'inj': '工伤',
      'mat': '生育',
    }.entries) {
      final range = _range(_itemValues(entry.key, 'base'));
      groups.putIfAbsent(range, () => []).add(entry.value);
    }
    if (groups.length == 1) return '基数 ${groups.keys.single}';
    return groups.entries
        .map((e) => '${e.value.join(' / ')}：${e.key}')
        .join('\n');
  }

  String get housing {
    if (result == null) {
      final i = _legacyInputs;
      final social = i['socialBaseMode'] == 'custom'
          ? i['customSocialBaseCents'] as int?
          : i['grossMonthlySalaryCents'] as int?;
      final base = i['housingFundBaseMode'] == 'custom'
          ? i['customHousingFundBaseCents'] as int?
          : social;
      final rate = i['housingFundRateBps'] as int?;
      return '原输入基数 ${_money(base)}\n个人 / 公司 ${rate == null ? '未记录' : rateText(rate * 100)}';
    }
    return '基数 ${_range(_itemValues('hf', 'base'))}\n个人 ${_range(_itemValues('hf', 'employeeRate'), rate: true)} / 公司 ${_range(_itemValues('hf', 'employerRate'), rate: true)}';
  }

  int? get additionalDeduction => result == null
      ? _legacyInputs['specialAdditionalDeductionCents'] as int?
      : result!.draft.deduction.trim().isEmpty
      ? 0
      : parseDecimal(result!.draft.deduction, 2);

  String get pension {
    final r = result;
    if (r == null) return '未记录';
    if (r.sum('pension') == 0) return '不缴纳';
    final d = r.draft;
    return d.pensionMode == PensionMode.monthly
        ? '${_money(parseDecimal(d.pension, 2))} / 月'
        : '${d.pensionMonth} 月一次缴纳 ${_money(r.sum('pension'))}';
  }

  String get bonusMethod {
    final r = result;
    if (r == null) return '未记录';
    if (r.sum('bonus') == 0) return '无年终奖';
    return r.strategy == BonusMode.separate ? '单独计税' : '并入工资';
  }

  Map<String, String> get settings => {
    '社保': socialBases,
    '公积金': housing,
    '专项扣除':
        '${_money(additionalDeduction)}${additionalDeduction == null ? '' : ' / 月（专项附加扣除）'}',
    '个人养老金': pension,
    '年终奖计算方式': bonusMethod,
    if (result != null && result!.sum('bonus') > 0)
      '年终奖': '${_money(result!.sum('bonus'))} · ${result!.draft.bonusMonth} 月',
  };

  static String _money(int? value) =>
      value == null ? '未记录' : formatCents(value);
  static String _range(Iterable<int> values, {bool rate = false}) {
    final sorted = values.toSet().toList()..sort();
    if (sorted.isEmpty) return '未记录';
    final format = rate ? rateText : _money;
    if (sorted.length == 1) return format(sorted.single);
    return '${format(sorted.first)} – ${format(sorted.last)}（年内变化）';
  }
}
