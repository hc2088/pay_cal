import 'package:flutter/material.dart';

import '../../calculation/calculation_engine.dart';
import '../../calculation/calculator_inputs.dart';
import '../../calculation/money_format.dart';

const Color _taxNavy = Color(0xFF18324B);
const Color _taxTeal = Color(0xFF1D9A8A);
const Color _taxMuted = Color(0xFF718195);
const Color _taxLine = Color(0xFFE7EDF3);

class TaxBasisBreakdown extends StatefulWidget {
  const TaxBasisBreakdown({
    required this.inputs,
    required this.months,
    this.initialMonth = 1,
    super.key,
  });

  final CalculatorInputs inputs;
  final List<MonthlyCalculationResult> months;
  final int initialMonth;

  @override
  State<TaxBasisBreakdown> createState() => _TaxBasisBreakdownState();
}

class _TaxBasisBreakdownState extends State<TaxBasisBreakdown> {
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth.clamp(1, 12);
  }

  @override
  void didUpdateWidget(covariant TaxBasisBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMonth != widget.initialMonth) {
      _selectedMonth = widget.initialMonth.clamp(1, 12);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.months.isEmpty) {
      return const SizedBox.shrink();
    }
    final MonthlyCalculationResult month = widget.months.firstWhere(
      (MonthlyCalculationResult item) => item.month == _selectedMonth,
      orElse: () => widget.months.first,
    );
    final int previousWithholdingCents = widget.months
        .where((MonthlyCalculationResult item) => item.month < month.month)
        .fold<int>(
          0,
          (int sum, MonthlyCalculationResult item) =>
              sum + item.monthlyTaxCents,
        );

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: _taxTeal,
              size: 19,
            ),
          ),
          title: const Text(
            '逐月扣税依据',
            style: TextStyle(color: _taxNavy, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            '查看个人缴费、累计扣除和适用税率档位',
            style: TextStyle(color: _taxMuted, fontSize: 11),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
          children: <Widget>[
            _monthSelector(month.month),
            const SizedBox(height: 12),
            _contributionSection(month),
            const SizedBox(height: 14),
            _taxCalculationSection(month, previousWithholdingCents),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector(int selectedMonth) => Row(
    children: <Widget>[
      const Expanded(
        child: Text(
          '查看当月计算过程',
          style: TextStyle(
            color: _taxNavy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _taxLine),
          borderRadius: BorderRadius.circular(11),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedMonth,
            items: <DropdownMenuItem<int>>[
              for (final MonthlyCalculationResult month in widget.months)
                DropdownMenuItem<int>(
                  value: month.month,
                  child: Text('${month.month} 月'),
                ),
            ],
            onChanged: (int? value) {
              if (value != null) {
                setState(() => _selectedMonth = value);
              }
            },
          ),
        ),
      ),
    ],
  );

  Widget _contributionSection(MonthlyCalculationResult month) {
    final CalculatorInputs inputs = widget.inputs;
    final List<_ContributionRow> rows = <_ContributionRow>[
      _ContributionRow(
        name: '养老保险',
        base: '社保基数',
        employerRate: employerPensionRateBps,
        employerAmount: month.employerPensionCents,
        employeeRate: employeePensionRateBps,
        employeeAmount: month.employeePensionCents,
      ),
      _ContributionRow(
        name: '医疗保险',
        base: '社保基数',
        employerRate: employerMedicalRateBps,
        employerAmount: month.employerMedicalCents,
        employeeRate: employeeMedicalRateBps,
        employeeAmount: month.employeeMedicalCents,
      ),
      const _ContributionRow(
        name: '生育保险',
        base: '未单独建模',
        employerRate: null,
        employerAmount: null,
        employeeRate: null,
        employeeAmount: null,
      ),
      _ContributionRow(
        name: '失业保险',
        base: '社保基数',
        employerRate: employerUnemploymentRateBps,
        employerAmount: month.employerUnemploymentCents,
        employeeRate: employeeUnemploymentRateBps,
        employeeAmount: month.employeeUnemploymentCents,
      ),
      _ContributionRow(
        name: '工伤保险',
        base: '社保基数',
        employerRate: inputs.workInjuryRateBps,
        employerAmount: month.employerWorkInjuryCents,
        employeeRate: null,
        employeeAmount: 0,
      ),
      _ContributionRow(
        name: '住房公积金',
        base: '公积金基数',
        employerRate: inputs.housingFundRateBps,
        employerAmount: month.employerHousingFundCents,
        employeeRate: inputs.housingFundRateBps,
        employeeAmount: month.employeeHousingFundCents,
      ),
      _ContributionRow(
        name: '大病统筹',
        base: '固定金额',
        employerRate: null,
        employerAmount: 0,
        employeeRate: null,
        employeeAmount: month.criticalIllnessCents,
      ),
    ];
    final int employerTotal =
        month.employerSocialTotalCents + month.employerHousingFundCents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _TaxSectionHeading(
          title: '五险一金缴费明细',
          subtitle: '单位和个人分别按对应基数、比例计算',
        ),
        const SizedBox(height: 8),
        for (int index = 0; index < rows.length; index++) ...<Widget>[
          _ContributionItemCard(row: rows[index]),
          const SizedBox(height: 6),
        ],
        _ContributionItemCard(
          row: _ContributionRow(
            name: '缴费合计',
            base: '元/月',
            employerRate: null,
            employerAmount: employerTotal,
            employeeRate: null,
            employeeAmount: month.personalDeductionTotalCents,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '社保基数 ${formatCents(month.socialBaseCents)} · 公积金基数 ${formatCents(inputs.housingFundBaseCents)}。生育保险当前没有独立费率和金额字段；个人扣款含个人社保、公积金和大病统筹，单位缴费不从个人工资扣除。',
          style: const TextStyle(color: _taxMuted, fontSize: 9, height: 1.4),
        ),
      ],
    );
  }

  Widget _taxCalculationSection(
    MonthlyCalculationResult month,
    int previousWithholdingCents,
  ) {
    final int monthCount = month.month;
    final int cumulativeSpecialDeductionCents =
        widget.inputs.specialAdditionalDeductionCents * monthCount;
    final int cumulativeBasicDeductionCents = basicDeductionCents * monthCount;
    final String bracketRange = _bracketRange(month);
    final int currentTaxableCents = month.taxableIncomeIncrementCents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _TaxSectionHeading(
          title: '累计预扣个税过程',
          subtitle: '个税按年累计计算，再减去前几月已预扣税额',
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _taxLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TaxValueRow(
                label: '本月税前工资',
                value: formatCents(month.salaryCents),
              ),
              _TaxValueRow(
                label: '本月个人缴费合计',
                value: '− ${formatCents(month.personalDeductionTotalCents)}',
              ),
              _TaxValueRow(
                label:
                    '累计专项附加扣除（每月 ${formatCents(widget.inputs.specialAdditionalDeductionCents)}）',
                value: '− ${formatCents(cumulativeSpecialDeductionCents)}',
              ),
              _TaxValueRow(
                label: '累计基本减除费用（每月 ¥5,000）',
                value: '− ${formatCents(cumulativeBasicDeductionCents)}',
              ),
              const Divider(height: 15),
              _TaxValueRow(
                label: '本月新增应纳税所得额',
                value: formatCents(currentTaxableCents),
                strong: true,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 3, bottom: 8),
                child: Text(
                  '计算：本月税前工资 − 个人缴费 − 本月专项附加扣除 − ¥5,000（小于 0 按 0）',
                  style: TextStyle(color: _taxMuted, fontSize: 9, height: 1.35),
                ),
              ),
              _TaxValueRow(
                label: '1—$monthCount 月累计应纳税所得额',
                value: formatCents(month.cumulativeTaxableIncomeCents),
                strong: true,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '适用税率档位：$bracketRange · ${formatRate(month.taxBracketRateBps)}',
                      style: const TextStyle(
                        color: _taxNavy,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '累计应纳税额 = 累计应纳税所得额 × ${formatRate(month.taxBracketRateBps)} − 速算扣除数 ${formatCents(month.quickDeductionCents)} = ${formatCents(month.cumulativeTaxDueCents)}',
                      style: const TextStyle(
                        color: _taxMuted,
                        fontSize: 9,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _TaxValueRow(
                label: '前几月已预扣',
                value: formatCents(previousWithholdingCents),
              ),
              _TaxValueRow(
                label: '$monthCount 月本月预扣个税',
                value: formatCents(month.monthlyTaxCents),
                strong: true,
                accent: true,
              ),
              const SizedBox(height: 3),
              const Text(
                '本月预扣税额 = max（累计应纳税额 − 前几月已预扣税额，0）',
                style: TextStyle(color: _taxMuted, fontSize: 9, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _bracketRange(MonthlyCalculationResult month) {
    final int index = cumulativeTaxBrackets.indexWhere(
      (TaxBracket bracket) =>
          bracket.rateBps == month.taxBracketRateBps &&
          bracket.quickDeductionCents == month.quickDeductionCents,
    );
    if (index < 0) {
      return '全年累计预扣税率';
    }
    final int? upperBound = cumulativeTaxBrackets[index].upperBoundCents;
    if (index == 0) {
      return upperBound == null
          ? '全年累计应纳税所得额'
          : '累计所得额不超过 ${formatCents(upperBound)}';
    }
    final int? lowerBound = cumulativeTaxBrackets[index - 1].upperBoundCents;
    if (upperBound == null) {
      return '累计所得额超过 ${formatCents(lowerBound!)}';
    }
    return '累计所得额超过 ${formatCents(lowerBound!)}，不超过 ${formatCents(upperBound)}';
  }
}

class _ContributionRow {
  const _ContributionRow({
    required this.name,
    required this.base,
    required this.employerRate,
    required this.employerAmount,
    required this.employeeRate,
    required this.employeeAmount,
  });

  final String name;
  final String base;
  final int? employerRate;
  final int? employerAmount;
  final int? employeeRate;
  final int? employeeAmount;
}

class _ContributionItemCard extends StatelessWidget {
  const _ContributionItemCard({required this.row});

  final _ContributionRow row;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: row.name == '缴费合计'
          ? const Color(0xFFEAF7F4)
          : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _taxLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                row.name,
                style: const TextStyle(
                  color: _taxNavy,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              row.base,
              style: const TextStyle(color: _taxMuted, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _ContributionAmount(
                label: '单位缴纳',
                rate: row.employerRate,
                amount: row.employerAmount,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ContributionAmount(
                label: '个人扣款',
                rate: row.employeeRate,
                amount: row.employeeAmount,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ContributionAmount extends StatelessWidget {
  const _ContributionAmount({
    required this.label,
    required this.rate,
    required this.amount,
  });

  final String label;
  final int? rate;
  final int? amount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _taxMuted, fontSize: 9),
            ),
          ),
          Text(
            rate == null ? '—' : formatRate(rate!),
            style: const TextStyle(color: _taxMuted, fontSize: 9),
          ),
        ],
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          amount == null ? '—' : formatCents(amount!),
          style: const TextStyle(
            color: _taxNavy,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _TaxSectionHeading extends StatelessWidget {
  const _TaxSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: const TextStyle(
          color: _taxNavy,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(color: _taxMuted, fontSize: 9)),
    ],
  );
}

class _TaxValueRow extends StatelessWidget {
  const _TaxValueRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool strong;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? _taxNavy : _taxMuted,
              fontSize: 10,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: accent ? _taxTeal : _taxNavy,
            fontSize: 10,
            fontWeight: strong || accent ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
