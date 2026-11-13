import 'dart:convert';
import 'dart:math';

import '../calculation/calculator_inputs.dart'
    show CalculatorInputs, SocialBaseMode, HousingFundBaseMode;

const moneyLimit = 99999999999;
const rateScale = 1000000;
const contributionNames = {
  'pension': '养老保险',
  'med': '医疗保险',
  'unemp': '失业保险',
  'inj': '工伤保险',
  'mat': '生育保险',
  'hf': '住房公积金',
};

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
Map<String, dynamic> objectMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);

Object? _freezeJson(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _freezeJson(item))),
    );
  }
  if (value is List) return List.unmodifiable(value.map(_freezeJson));
  return value;
}

int checkedInt(Object? value, {int min = 0, int max = moneyLimit}) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('金额或比例超出支持范围');
  }
  return value;
}

/// Parses decimal input without floating point, including intermediate/invalid text.
int? parseDecimal(String text, int places, {int max = moneyLimit}) {
  final input = text.trim().replaceFirst(RegExp(r'^[¥￥]\s*'), '');
  if (RegExp(r'[,，]').hasMatch(input) &&
      !RegExp(
        '^\\d{1,3}(?:[,，]\\d{3})+(?:\\.\\d{0,$places})?\$',
      ).hasMatch(input)) {
    return null;
  }
  final cleaned = input.replaceAll(RegExp(r'[,，]'), '');
  if (!RegExp('^\\d+(?:\\.\\d{0,$places})?\$').hasMatch(cleaned)) return null;
  final parts = cleaned.split('.');
  final digits =
      parts[0] + (parts.length == 2 ? parts[1] : '').padRight(places, '0');
  final value = BigInt.tryParse(digits);
  if (value == null || value > BigInt.from(max)) return null;
  return value.toInt();
}

String decimalText(int value, int places) {
  final divisor = pow(10, places).toInt();
  final fraction = (value.abs() % divisor)
      .toString()
      .padLeft(places, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '${value < 0 ? '-' : ''}${value.abs() ~/ divisor}${fraction.isEmpty ? '' : '.$fraction'}';
}

String rateText(int? value) =>
    value == null ? '待补充' : '${decimalText(value, 4)}%';

class Contribution {
  const Contribution({
    required this.kind,
    this.minBase,
    this.maxBase,
    this.employeeRate,
    this.employerRate,
    this.employeeFixed = 0,
    this.employerFixed = 0,
    this.actualBase,
    this.roundingUnit = 1,
    this.defaultRateMax,
    this.overridden = false,
  });
  final String kind;
  final int? minBase,
      maxBase,
      employeeRate,
      employerRate,
      actualBase,
      defaultRateMax;
  final int employeeFixed, employerFixed, roundingUnit;
  final bool overridden;
  String get label => contributionNames[kind] ?? kind;
  bool get complete =>
      minBase != null &&
      maxBase != null &&
      employeeRate != null &&
      employerRate != null;
  Contribution copyWith({
    int? minBase,
    int? maxBase,
    int? employeeRate,
    int? employerRate,
    int? employeeFixed,
    int? employerFixed,
    int? actualBase,
    bool clearActual = false,
    int? roundingUnit,
    bool? overridden,
  }) => Contribution(
    kind: kind,
    minBase: minBase ?? this.minBase,
    maxBase: maxBase ?? this.maxBase,
    employeeRate: employeeRate ?? this.employeeRate,
    employerRate: employerRate ?? this.employerRate,
    employeeFixed: employeeFixed ?? this.employeeFixed,
    employerFixed: employerFixed ?? this.employerFixed,
    actualBase: clearActual ? null : actualBase ?? this.actualBase,
    roundingUnit: roundingUnit ?? this.roundingUnit,
    defaultRateMax: defaultRateMax,
    overridden: overridden ?? true,
  );
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'minBase': minBase,
    'maxBase': maxBase,
    'employeeRate': employeeRate,
    'employerRate': employerRate,
    'employeeFixed': employeeFixed,
    'employerFixed': employerFixed,
    'actualBase': actualBase,
    'roundingUnit': roundingUnit,
    'defaultRateMax': defaultRateMax,
    'overridden': overridden,
  };
  factory Contribution.fromJson(Map<String, dynamic> j) {
    int? optional(String k, {int max = moneyLimit}) =>
        j[k] == null ? null : checkedInt(j[k], max: max);
    final kind = j['kind'] as String;
    if (!contributionNames.containsKey(kind)) {
      throw const FormatException('未知缴费项目');
    }
    final low = optional('minBase'), high = optional('maxBase');
    if (low != null && high != null && low > high) {
      throw const FormatException('基数下限超过上限');
    }
    return Contribution(
      kind: kind,
      minBase: low,
      maxBase: high,
      employeeRate: optional('employeeRate', max: rateScale),
      employerRate: optional('employerRate', max: rateScale),
      employeeFixed: checkedInt(j['employeeFixed'] ?? 0),
      employerFixed: checkedInt(j['employerFixed'] ?? 0),
      actualBase: optional('actualBase'),
      roundingUnit: checkedInt(j['roundingUnit'] ?? 1, min: 1, max: 100),
      defaultRateMax: optional('defaultRateMax', max: rateScale),
      overridden: j['overridden'] == true,
    );
  }
}

class PolicyPeriod {
  PolicyPeriod({
    required this.from,
    required this.to,
    required List<Contribution> items,
    required this.verified,
  }) : items = List.unmodifiable(items);
  final DateTime from, to;
  final List<Contribution> items;
  final bool verified;
  bool contains(DateTime date) => !date.isBefore(from) && !date.isAfter(to);
  Map<String, dynamic> toJson() => {
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'verified': verified,
  };
  factory PolicyPeriod.fromJson(Map<String, dynamic> j) => PolicyPeriod(
    from: DateTime.parse(j['from']),
    to: DateTime.parse(j['to']),
    verified: j['verified'] == true,
    items: (j['items'] as List)
        .map((e) => Contribution.fromJson(objectMap(e)))
        .toList(),
  );
}

class CityReference {
  CityReference({
    required this.id,
    required this.name,
    required this.province,
    required this.search,
    required this.yearLabel,
    required this.version,
    required List<Contribution> items,
    required List<String> sources,
    required this.note,
    List<PolicyPeriod> periods = const [],
    List<Map<String, dynamic>> tiers = const [],
  }) : items = List.unmodifiable(items),
       sources = List.unmodifiable(sources),
       periods = List.unmodifiable(periods),
       tiers = List.unmodifiable(
         tiers.map((e) => Map<String, dynamic>.unmodifiable(e)),
       );
  final String id, name, province, search, yearLabel, version, note;
  final List<Contribution> items;
  final List<String> sources;
  final List<PolicyPeriod> periods;
  final List<Map<String, dynamic>> tiers;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'province': province,
    'search': search,
    'yearLabel': yearLabel,
    'version': version,
    'note': note,
    'items': items.map((e) => e.toJson()).toList(),
    'sources': sources,
    'periods': periods.map((e) => e.toJson()).toList(),
    'tiers': tiers,
  };
  factory CityReference.fromJson(Map<String, dynamic> j) => CityReference(
    id: j['id'],
    name: j['name'],
    province: j['province'],
    search: j['search'],
    yearLabel: j['yearLabel'],
    version: j['version'],
    note: j['note'],
    items: (j['items'] as List)
        .map((e) => Contribution.fromJson(objectMap(e)))
        .toList(),
    sources: List<String>.from(j['sources']),
    periods: ((j['periods'] ?? []) as List)
        .map((e) => PolicyPeriod.fromJson(objectMap(e)))
        .toList(),
    tiers: ((j['tiers'] ?? []) as List).map(objectMap).toList(),
  );
}

enum BonusMode { compare, separate, merged }

enum PensionMode { none, monthly, once }

class PayrollDraft {
  PayrollDraft({
    required this.id,
    required this.city,
    required this.year,
    this.salary = '',
    this.deduction = '0',
    this.bonus = '0',
    this.bonusMonth = 12,
    this.bonusMode = BonusMode.compare,
    this.bonusEligible = false,
    this.pensionMode = PensionMode.none,
    this.pension = '0',
    this.pensionMonth = 12,
    this.pensionAtSettlement = false,
    this.socialBase = '',
    this.housingBase = '',
    this.deductible = '',
    this.taxableBenefit = '0',
    this.estimateConfirmed = false,
    this.medicalTier = '',
    Map<String, Contribution> overrides = const {},
  }) : overrides = Map.unmodifiable(overrides);
  final String id;
  final CityReference city;
  final int year, bonusMonth, pensionMonth;
  final String salary,
      deduction,
      bonus,
      pension,
      socialBase,
      housingBase,
      deductible,
      taxableBenefit,
      medicalTier;
  final BonusMode bonusMode;
  final PensionMode pensionMode;
  final bool bonusEligible, pensionAtSettlement, estimateConfirmed;
  final Map<String, Contribution> overrides;
  List<Contribution> get effectiveItems =>
      city.items.map((e) => overrides[e.kind] ?? e).toList();
  String get scope => '${city.id}:$year';
  PayrollDraft copyWith({
    String? id,
    CityReference? city,
    int? year,
    String? salary,
    String? deduction,
    String? bonus,
    int? bonusMonth,
    BonusMode? bonusMode,
    bool? bonusEligible,
    PensionMode? pensionMode,
    String? pension,
    int? pensionMonth,
    bool? pensionAtSettlement,
    String? socialBase,
    String? housingBase,
    String? deductible,
    String? taxableBenefit,
    bool? estimateConfirmed,
    String? medicalTier,
    Map<String, Contribution>? overrides,
  }) => PayrollDraft(
    id: id ?? this.id,
    city: city ?? this.city,
    year: year ?? this.year,
    salary: salary ?? this.salary,
    deduction: deduction ?? this.deduction,
    bonus: bonus ?? this.bonus,
    bonusMonth: bonusMonth ?? this.bonusMonth,
    bonusMode: bonusMode ?? this.bonusMode,
    bonusEligible: bonusEligible ?? this.bonusEligible,
    pensionMode: pensionMode ?? this.pensionMode,
    pension: pension ?? this.pension,
    pensionMonth: pensionMonth ?? this.pensionMonth,
    pensionAtSettlement: pensionAtSettlement ?? this.pensionAtSettlement,
    socialBase: socialBase ?? this.socialBase,
    housingBase: housingBase ?? this.housingBase,
    deductible: deductible ?? this.deductible,
    taxableBenefit: taxableBenefit ?? this.taxableBenefit,
    estimateConfirmed: estimateConfirmed ?? this.estimateConfirmed,
    medicalTier: medicalTier ?? this.medicalTier,
    overrides: overrides ?? this.overrides,
  );
  PayrollDraft resetContributions() => copyWith(
    overrides: {},
    socialBase: '',
    housingBase: '',
    deductible: '',
    taxableBenefit: '0',
    medicalTier: '',
    estimateConfirmed: false,
  );
  PayrollDraft changeCity(CityReference city) =>
      resetContributions().copyWith(city: city);
  Map<String, dynamic> toJson() => {
    'schemaVersion': 4,
    'id': id,
    'city': city.toJson(),
    'year': year,
    'salary': salary,
    'deduction': deduction,
    'bonus': bonus,
    'bonusMonth': bonusMonth,
    'bonusMode': bonusMode.name,
    'bonusEligible': bonusEligible,
    'pensionMode': pensionMode.name,
    'pension': pension,
    'pensionMonth': pensionMonth,
    'pensionAtSettlement': pensionAtSettlement,
    'socialBase': socialBase,
    'housingBase': housingBase,
    'deductible': deductible,
    'taxableBenefit': taxableBenefit,
    'estimateConfirmed': estimateConfirmed,
    'medicalTier': medicalTier,
    'overrides': overrides.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory PayrollDraft.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 4) throw const FormatException('不支持的草稿版本');
    return PayrollDraft(
      id: j['id'],
      city: CityReference.fromJson(objectMap(j['city'])),
      year: checkedInt(j['year'], min: 2019, max: 2100),
      salary: j['salary'],
      deduction: j['deduction'],
      bonus: j['bonus'],
      bonusMonth: checkedInt(j['bonusMonth'], min: 1, max: 12),
      bonusMode: BonusMode.values.byName(j['bonusMode']),
      bonusEligible: j['bonusEligible'] == true,
      pensionMode: PensionMode.values.byName(j['pensionMode']),
      pension: j['pension'],
      pensionMonth: checkedInt(j['pensionMonth'], min: 1, max: 12),
      pensionAtSettlement: j['pensionAtSettlement'] == true,
      socialBase: j['socialBase'],
      housingBase: j['housingBase'],
      deductible: j['deductible'],
      taxableBenefit: j['taxableBenefit'],
      estimateConfirmed: j['estimateConfirmed'] == true,
      medicalTier: j['medicalTier'] ?? '',
      overrides: objectMap(
        j['overrides'],
      ).map((k, v) => MapEntry(k, Contribution.fromJson(objectMap(v)))),
    );
  }
  String encode() => jsonEncode(toJson());

  factory PayrollDraft.fromLegacy(CalculatorInputs old) {
    final items = [
      const Contribution(
        kind: 'pension',
        minBase: 0,
        maxBase: moneyLimit,
        employeeRate: 80000,
        employerRate: 160000,
      ),
      const Contribution(
        kind: 'med',
        minBase: 0,
        maxBase: moneyLimit,
        employeeRate: 20000,
        employerRate: 98000,
        employeeFixed: 300,
      ),
      const Contribution(
        kind: 'unemp',
        minBase: 0,
        maxBase: moneyLimit,
        employeeRate: 5000,
        employerRate: 5000,
      ),
      Contribution(
        kind: 'inj',
        minBase: 0,
        maxBase: moneyLimit,
        employeeRate: 0,
        employerRate: old.workInjuryRateBps * 100,
      ),
      const Contribution(
        kind: 'mat',
        minBase: 0,
        maxBase: moneyLimit,
        employeeRate: 0,
        employerRate: 0,
      ),
      Contribution(
        kind: 'hf',
        minBase: 0,
        maxBase: moneyLimit,
        employeeRate: old.housingFundRateBps * 100,
        employerRate: old.housingFundRateBps * 100,
      ),
    ];
    return PayrollDraft(
      id: newId(),
      city: CityReference(
        id: 'legacy',
        name: '旧版自定义',
        province: '',
        search: '',
        yearLabel: '年度未知',
        version: 'legacy-reference-v1',
        items: items,
        sources: [],
        note: '原参数已保留，未推断城市。请核对年度与扣除口径。',
      ),
      year: DateTime.now().year,
      salary: decimalText(old.grossMonthlySalaryCents, 2),
      deduction: decimalText(old.specialAdditionalDeductionCents, 2),
      socialBase:
          old.socialBaseMode == SocialBaseMode.followSalary ||
              old.customSocialBaseCents == null
          ? ''
          : decimalText(old.customSocialBaseCents!, 2),
      housingBase:
          old.housingFundBaseMode == HousingFundBaseMode.followSocialBase ||
              old.customHousingFundBaseCents == null
          ? ''
          : decimalText(old.customHousingFundBaseCents!, 2),
    );
  }
}

/// Immutable result values. All UI, comparison and exports read this snapshot.
class PayrollResult {
  PayrollResult({
    required this.draft,
    required this.strategy,
    required List<Map<String, dynamic>> months,
    required this.annualTaxDue,
    required this.refundEstimate,
    required this.createdAt,
    this.engineVersion = 'payroll-v2.0.0',
  }) : months = List.unmodifiable(
         months.map((m) => _freezeJson(m) as Map<String, dynamic>),
       );
  final PayrollDraft draft;
  final BonusMode strategy;
  final List<Map<String, dynamic>> months;
  final int annualTaxDue, refundEstimate;
  final DateTime createdAt;
  final String engineVersion;
  int sum(String key) => months.fold(0, (s, m) => s + (m[key] as int));
  int itemSum(String kind, String side, {int? month}) {
    final selected = month == null ? months : [months[month - 1]];
    return selected.fold(
      0,
      (s, m) =>
          s +
          (m['items'] as List)
              .where((e) => e['kind'] == kind)
              .fold<int>(0, (a, e) => a + (e[side] as int)),
    );
  }

  Map<String, dynamic> toJson() => {
    'resultSchemaVersion': 1,
    'engineVersion': engineVersion,
    'draft': draft.toJson(),
    'strategy': strategy.name,
    'months': months,
    'annualTaxDue': annualTaxDue,
    'refundEstimate': refundEstimate,
    'createdAt': createdAt.toIso8601String(),
  };
  factory PayrollResult.fromJson(Map<String, dynamic> j) {
    if (j['resultSchemaVersion'] != 1) throw const FormatException('不支持的结果版本');
    final months = (j['months'] as List).map(objectMap).toList();
    if (months.length != 12) throw const FormatException('结果月份不完整');
    for (var i = 0; i < 12; i++) {
      final m = months[i];
      if (m['month'] != i + 1) throw const FormatException('结果月份顺序错误');
      for (final key in [
        'salary',
        'bonus',
        'employee',
        'employer',
        'tax',
        'wageTax',
        'bonusTax',
        'pension',
        'housing',
        'employerCost',
        'taxBase',
        'taxRate',
        'quick',
        'cumulativeDue',
        'deductible',
        'cumulativePaid',
      ]) {
        checkedInt(m[key], max: moneyLimit * 100);
      }
      for (final key in ['net', 'available', 'rawTaxBase']) {
        checkedInt(m[key], min: -moneyLimit * 100, max: moneyLimit * 100);
      }
      final items = (m['items'] as List).map(objectMap).toList();
      if (items.length != 6 ||
          items.map((e) => e['kind']).toSet().length != 6) {
        throw const FormatException('缴费明细不完整');
      }
      for (final item in items) {
        if (!contributionNames.containsKey(item['kind'])) {
          throw const FormatException('未知缴费明细');
        }
        for (final key in [
          'base',
          'reference',
          'employee',
          'employer',
          'employeeRate',
          'employerRate',
        ]) {
          checkedInt(item[key], max: moneyLimit * 10);
        }
      }
      if (m['net'] != m['salary'] + m['bonus'] - m['employee'] - m['tax'] ||
          m['available'] != m['net'] - m['pension']) {
        throw const FormatException('快照现金汇总不一致');
      }
    }
    return PayrollResult(
      draft: PayrollDraft.fromJson(objectMap(j['draft'])),
      strategy: BonusMode.values.byName(j['strategy']),
      months: months,
      annualTaxDue: checkedInt(j['annualTaxDue'], max: moneyLimit * 100),
      refundEstimate: checkedInt(
        j['refundEstimate'],
        min: -moneyLimit * 100,
        max: moneyLimit * 100,
      ),
      createdAt: DateTime.parse(j['createdAt']),
      engineVersion: j['engineVersion'] as String,
    );
  }
}

class PayrollPlan {
  PayrollPlan({
    required this.id,
    required this.name,
    required this.savedAt,
    this.result,
    this.legacy,
  });
  final String id, name;
  final DateTime savedAt;
  final PayrollResult? result;
  final Map<String, dynamic>? legacy;
  bool get isLegacy => legacy != null;
  int? value(String key) {
    if (result != null) return result!.sum(key);
    final field = {
      'net': 'annualNetCashCents',
      'tax': 'annualTaxCents',
      'employerCost': 'annualEmployerCostCents',
    }[key];
    return field == null ? null : legacy?[field] as int?;
  }
}
