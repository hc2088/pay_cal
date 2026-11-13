import 'package:pay_cal/domain/payroll_models.dart';

PayrollDraft fixture({bool zeroContributions = false}) {
  final old = zeroContributions ? 0 : 1;
  final items = [
    Contribution(
      kind: 'pension',
      minBase: 0,
      maxBase: moneyLimit,
      employeeRate: 80000 * old,
      employerRate: 160000 * old,
    ),
    Contribution(
      kind: 'med',
      minBase: 0,
      maxBase: moneyLimit,
      employeeRate: 20000 * old,
      employerRate: 98000 * old,
    ),
    Contribution(
      kind: 'unemp',
      minBase: 0,
      maxBase: moneyLimit,
      employeeRate: 5000 * old,
      employerRate: 5000 * old,
    ),
    Contribution(
      kind: 'inj',
      minBase: 0,
      maxBase: moneyLimit,
      employeeRate: 0,
      employerRate: 2000 * old,
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
      employeeRate: 120000 * old,
      employerRate: 120000 * old,
      defaultRateMax: 120000,
    ),
  ];
  return PayrollDraft(
    id: 'fixture',
    city: CityReference(
      id: 'test',
      name: '测试城市',
      province: '',
      search: 'test',
      yearLabel: '2026',
      version: 'fixture-v1',
      items: items,
      sources: [],
      note: '独立核验算例',
    ),
    year: 2026,
    salary: '33000',
    deduction: '5000',
    estimateConfirmed: true,
  );
}
