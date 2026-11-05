import 'package:flutter/material.dart';

import '../../calculation/calculation_engine.dart';
import '../../calculation/money_format.dart';

const Color _incomeNavy = Color(0xFF18324B);
const Color _incomeTeal = Color(0xFF1D9A8A);
const Color _incomeMuted = Color(0xFF718195);
const Color _incomeLine = Color(0xFFE7EDF3);

class IncomeTotals {
  const IncomeTotals({
    required this.grossSalaryCents,
    required this.netSalaryCents,
    required this.personalAfterTaxIncomeCents,
    required this.taxCents,
    required this.employerContributionCents,
    required this.personalContributionCents,
    required this.bilateralHousingFundCents,
    required this.personalMedicalCents,
    required this.personalPensionCents,
    required this.personalRightsCents,
    required this.employerTotalCostCents,
  });

  factory IncomeTotals.fromMonths(Iterable<MonthlyCalculationResult> months) {
    int grossSalary = 0;
    int netSalary = 0;
    int personalAfterTaxIncome = 0;
    int tax = 0;
    int employerContribution = 0;
    int personalContribution = 0;
    int bilateralHousingFund = 0;
    int personalMedical = 0;
    int personalPension = 0;
    int personalRights = 0;
    int employerTotalCost = 0;

    for (final MonthlyCalculationResult month in months) {
      grossSalary += month.salaryCents;
      netSalary += month.netCashCents;
      personalAfterTaxIncome +=
          month.netCashCents +
          month.employeePensionCents +
          month.employerMedicalCents +
          month.employeeMedicalCents;
      tax += month.monthlyTaxCents;
      employerContribution +=
          month.employerSocialTotalCents + month.employerHousingFundCents;
      personalContribution += month.personalDeductionTotalCents;
      bilateralHousingFund +=
          month.employerHousingFundCents + month.employeeHousingFundCents;
      personalMedical += month.employeeMedicalCents;
      personalPension += month.employeePensionCents;
      personalRights += month.benefitBCents;
      employerTotalCost += month.employerTotalCostCents;
    }

    return IncomeTotals(
      grossSalaryCents: grossSalary,
      netSalaryCents: netSalary,
      personalAfterTaxIncomeCents: personalAfterTaxIncome,
      taxCents: tax,
      employerContributionCents: employerContribution,
      personalContributionCents: personalContribution,
      bilateralHousingFundCents: bilateralHousingFund,
      personalMedicalCents: personalMedical,
      personalPensionCents: personalPension,
      personalRightsCents: personalRights,
      employerTotalCostCents: employerTotalCost,
    );
  }

  final int grossSalaryCents;
  final int netSalaryCents;
  final int personalAfterTaxIncomeCents;
  final int taxCents;
  final int employerContributionCents;
  final int personalContributionCents;
  final int bilateralHousingFundCents;
  final int personalMedicalCents;
  final int personalPensionCents;
  final int personalRightsCents;
  final int employerTotalCostCents;
}

class IncomeOverviewPanel extends StatelessWidget {
  const IncomeOverviewPanel({
    required this.totals,
    required this.annual,
    this.showHeading = true,
    this.compact = false,
    super.key,
  });

  final IncomeTotals totals;
  final bool annual;
  final bool showHeading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String period = annual ? '全年' : '本月';
    final double gap = compact ? 6 : 8;
    TextSpan amountSpan(int amountCents) => TextSpan(
      text: formatCents(amountCents),
      style: const TextStyle(color: _incomeNavy, fontWeight: FontWeight.w700),
    );
    final TextStyle formulaStyle = TextStyle(
      color: _incomeMuted,
      fontSize: compact ? 7.5 : 9,
      height: 1.25,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showHeading) ...<Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '关注数据',
                  style: TextStyle(
                    color: _incomeNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '金额单位：元',
                style: TextStyle(color: _incomeMuted, fontSize: 10),
              ),
            ],
          ),
          SizedBox(height: gap),
        ],
        _OverviewCard(
          label: '$period税前工资',
          amountCents: totals.grossSalaryCents,
          compact: compact,
        ),
        SizedBox(height: gap),
        _OverviewCard(
          label: '$period个人总收入',
          amountCents: totals.personalRightsCents,
          accent: true,
          compact: compact,
          formulas: <InlineSpan>[
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: '税后工资 = 税前工资 '),
                amountSpan(totals.grossSalaryCents),
                const TextSpan(text: ' − 个人缴费 '),
                amountSpan(totals.personalContributionCents),
                const TextSpan(text: ' − 个税 '),
                amountSpan(totals.taxCents),
              ],
            ),
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: '总收入 = 税后工资 '),
                amountSpan(totals.netSalaryCents),
                const TextSpan(text: ' + 双边公积金 '),
                amountSpan(totals.bilateralHousingFundCents),
                const TextSpan(text: ' + 个人医保 '),
                amountSpan(totals.personalMedicalCents),
                const TextSpan(text: ' + 个人养老 '),
                amountSpan(totals.personalPensionCents),
              ],
            ),
          ],
          formulaStyle: formulaStyle,
        ),
        SizedBox(height: gap),
        _OverviewCard(
          label: '$period单位总成本',
          amountCents: totals.employerTotalCostCents,
          compact: compact,
          formulas: <InlineSpan>[
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: '税前工资 '),
                amountSpan(totals.grossSalaryCents),
                const TextSpan(text: ' + 单位五险一金 '),
                amountSpan(totals.employerContributionCents),
              ],
            ),
          ],
          formulaStyle: formulaStyle,
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.amountCents,
    required this.compact,
    this.accent = false,
    this.formulas = const <InlineSpan>[],
    this.formulaStyle,
  });

  final String label;
  final int amountCents;
  final bool compact;
  final bool accent;
  final List<InlineSpan> formulas;
  final TextStyle? formulaStyle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 9 : 12,
      vertical: compact ? 7 : 9,
    ),
    decoration: BoxDecoration(
      color: accent ? const Color(0xFFF0FAF8) : Colors.white,
      borderRadius: BorderRadius.circular(compact ? 10 : 13),
      border: Border.all(color: _incomeLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _incomeMuted,
                  fontSize: compact ? 8.5 : 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatCents(amountCents),
                  style: TextStyle(
                    color: accent ? _incomeTeal : _incomeNavy,
                    fontSize: compact ? 12 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        for (final InlineSpan formula in formulas) ...<Widget>[
          SizedBox(height: compact ? 2 : 4),
          Text.rich(
            TextSpan(children: <InlineSpan>[formula]),
            style: formulaStyle,
          ),
        ],
      ],
    ),
  );
}

class MonthlyIncomeTable extends StatelessWidget {
  const MonthlyIncomeTable({
    required this.months,
    this.selectedMonth,
    this.showHeading = true,
    this.compact = false,
    super.key,
  });

  final List<MonthlyCalculationResult> months;
  final int? selectedMonth;
  final bool showHeading;
  final bool compact;

  static const List<int> _columnFlexes = <int>[8, 18, 20, 18, 22, 14];

  @override
  Widget build(BuildContext context) {
    final IncomeTotals totals = IncomeTotals.fromMonths(months);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showHeading) ...<Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '逐月收入明细',
                  style: TextStyle(
                    color: _incomeNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text('单位：元', style: TextStyle(color: _incomeMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 7 : 10),
            border: Border.all(color: _incomeLine),
          ),
          child: Column(
            children: <Widget>[
              _row(
                values: const <String>[
                  '月份',
                  '税前\n工资',
                  '单位五险\n一金',
                  '单位\n总成本',
                  '税后\n总收入',
                  '扣税',
                ],
                header: true,
              ),
              for (int index = 0; index < months.length; index++)
                _row(
                  values: _monthValues(months[index]),
                  selected: months[index].month == selectedMonth,
                  alternate: index.isOdd,
                ),
              _row(
                values: <String>[
                  '全年',
                  formatCents(totals.grossSalaryCents, withSymbol: false),
                  formatCents(
                    totals.employerContributionCents,
                    withSymbol: false,
                  ),
                  formatCents(totals.employerTotalCostCents, withSymbol: false),
                  formatCents(
                    totals.personalAfterTaxIncomeCents,
                    withSymbol: false,
                  ),
                  formatCents(totals.taxCents, withSymbol: false),
                ],
                total: true,
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 7),
        Text(
          '税后总收入 = 税后工资 + 个人养老账户入账 + 双边医保账户入账（单位和个人）；单位总成本 = 税前工资 + 单位五险一金。',
          style: TextStyle(
            color: _incomeMuted,
            fontSize: compact ? 7 : 9,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  List<String> _monthValues(MonthlyCalculationResult month) => <String>[
    '${month.month.toString().padLeft(2, '0')}月',
    formatCents(month.salaryCents, withSymbol: false),
    formatCents(
      month.employerSocialTotalCents + month.employerHousingFundCents,
      withSymbol: false,
    ),
    formatCents(month.employerTotalCostCents, withSymbol: false),
    formatCents(
      month.netCashCents +
          month.employeePensionCents +
          month.employerMedicalCents +
          month.employeeMedicalCents,
      withSymbol: false,
    ),
    formatCents(month.monthlyTaxCents, withSymbol: false),
  ];

  Widget _row({
    required List<String> values,
    bool header = false,
    bool total = false,
    bool selected = false,
    bool alternate = false,
  }) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: header
          ? const Color(0xFFEAF1F7)
          : total || selected
          ? const Color(0xFFEAF7F4)
          : alternate
          ? const Color(0xFFF8FAFC)
          : Colors.white,
      border: header || total
          ? null
          : const Border(bottom: BorderSide(color: _incomeLine, width: 0.5)),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 2 : 4,
      vertical: compact ? 3 : 5,
    ),
    child: Row(
      children: <Widget>[
        for (int index = 0; index < values.length; index++)
          Expanded(
            flex: _columnFlexes[index],
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
              child: header
                  ? Text(
                      values[index],
                      textAlign: index == 0
                          ? TextAlign.start
                          : TextAlign.center,
                      maxLines: 2,
                      softWrap: true,
                      style: TextStyle(
                        color: _incomeMuted,
                        fontSize: compact ? 6.5 : 8,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: index == 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Text(
                        values[index],
                        maxLines: 1,
                        style: TextStyle(
                          color: total || selected ? _incomeTeal : _incomeNavy,
                          fontSize: compact ? 7 : 8.5,
                          fontWeight: total || selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
      ],
    ),
  );
}
