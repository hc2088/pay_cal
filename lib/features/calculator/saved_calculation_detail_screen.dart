import 'package:flutter/material.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/calculation_engine.dart';
import '../../calculation/money_format.dart';
import '../../calculation/saved_calculation.dart';
import 'calculation_history_format.dart';
import 'calculation_share_service.dart';

const Color _detailNavy = Color(0xFF18324B);
const Color _detailTeal = Color(0xFF1D9A8A);
const Color _detailMuted = Color(0xFF718195);
const Color _detailLine = Color(0xFFE7EDF3);

class SavedCalculationDetailScreen extends StatelessWidget {
  const SavedCalculationDetailScreen({required this.calculation, super.key});

  final SavedCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final List<MonthlyCalculationResult> months = calculation.months;
    final bool housingFollowsSocial =
        calculation.inputs.housingFundBaseMode ==
        HousingFundBaseMode.followSocialBase;
    int sum(int Function(MonthlyCalculationResult) select) => months.fold<int>(
      0,
      (int total, MonthlyCalculationResult month) => total + select(month),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('结果概览'),
        actions: <Widget>[
          Builder(
            builder: (BuildContext buttonContext) => IconButton(
              tooltip: '截图并分享',
              onPressed: () => shareSalarySnapshot(
                buttonContext,
                SalaryShareSnapshot.saved(calculation),
              ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: <Widget>[
          Text(
            '保存于 ${formatSavedTimestamp(calculation.savedAt)} · 规则版本 ${calculation.rulesVersion}',
            style: const TextStyle(color: _detailMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          const _SectionHeading(title: '全年汇总', subtitle: '保存时的全年测算结果'),
          const SizedBox(height: 9),
          _SummaryCard(
            title: '全年单位成本',
            value: formatCents(calculation.annualEmployerCostCents),
          ),
          const SizedBox(height: 8),
          _SummaryCard(
            title: '全年税后现金',
            value: formatCents(calculation.annualNetCashCents),
            accent: true,
          ),
          const SizedBox(height: 8),
          _SummaryCard(
            title: '全年综合到手',
            value: formatCents(calculation.annualBenefitACents),
          ),
          const SizedBox(height: 8),
          _SummaryCard(
            title: '全年综合到手 + 养老',
            value: formatCents(calculation.annualBenefitBCents),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '全年个人扣款和个税',
            rows: <_InfoRowData>[
              _InfoRowData(
                '个人养老保险',
                formatCents(
                  sum((MonthlyCalculationResult m) => m.employeePensionCents),
                ),
              ),
              _InfoRowData(
                '个人医疗保险',
                formatCents(
                  sum((MonthlyCalculationResult m) => m.employeeMedicalCents),
                ),
              ),
              _InfoRowData(
                '个人失业保险',
                formatCents(
                  sum(
                    (MonthlyCalculationResult m) => m.employeeUnemploymentCents,
                  ),
                ),
              ),
              _InfoRowData(
                '个人公积金',
                formatCents(
                  sum(
                    (MonthlyCalculationResult m) => m.employeeHousingFundCents,
                  ),
                ),
              ),
              _InfoRowData(
                '个人大病统筹',
                formatCents(
                  sum((MonthlyCalculationResult m) => m.criticalIllnessCents),
                ),
              ),
              _InfoRowData(
                '个人扣款合计',
                formatCents(
                  sum(
                    (MonthlyCalculationResult m) =>
                        m.personalDeductionTotalCents,
                  ),
                ),
              ),
              _InfoRowData(
                '累计应纳税所得额',
                formatCents(calculation.annualTaxableIncomeCents),
              ),
              _InfoRowData('累计预扣个税', formatCents(calculation.annualTaxCents)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '保存时的测算参数',
            rows: <_InfoRowData>[
              _InfoRowData(
                '月税前工资',
                formatCents(calculation.inputs.grossMonthlySalaryCents),
              ),
              _InfoRowData(
                '月专项附加扣除',
                formatCents(calculation.inputs.specialAdditionalDeductionCents),
              ),
              _InfoRowData(
                calculation.inputs.socialBaseMode == SocialBaseMode.custom
                    ? '自定义社保基数'
                    : '社保基数（跟随工资）',
                formatCents(calculation.inputs.socialBaseCents),
              ),
              _InfoRowData(
                housingFollowsSocial ? '公积金基数（跟随社保）' : '公积金基数（自定义）',
                formatCents(calculation.inputs.housingFundBaseCents),
              ),
              _InfoRowData(
                '公积金比例（单位和个人）',
                formatRate(calculation.inputs.housingFundRateBps),
              ),
              _InfoRowData(
                '工伤保险费率（单位）',
                formatRate(calculation.inputs.workInjuryRateBps),
              ),
              _InfoRowData('个人大病统筹', '¥3.00 / 月'),
            ],
          ),
          const SizedBox(height: 17),
          const _SectionHeading(
            title: '逐月薪资明细',
            subtitle: '展开月份可查看该月的个人扣款、累计个税、单位成本和综合到手构成',
          ),
          const SizedBox(height: 9),
          for (final MonthlyCalculationResult month in months)
            _MonthlyBreakdownCard(calculation: calculation, month: month),
          const SizedBox(height: 8),
          const Text(
            '综合到手 = 税后现金 + 双边公积金 + 个人医保账户入账；个人失业保险和大病统筹是现金扣款，不属于综合权益。个人养老账户另计入“综合到手 + 养老”。账户入账不等于全部可立即支取。',
            style: TextStyle(color: _detailMuted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBreakdownCard extends StatelessWidget {
  const _MonthlyBreakdownCard({required this.calculation, required this.month});

  final SavedCalculation calculation;
  final MonthlyCalculationResult month;

  @override
  Widget build(BuildContext context) {
    final int bilateralFund =
        month.employerHousingFundCents + month.employeeHousingFundCents;
    final CalculatorInputs inputs = calculation.inputs;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
          title: Text(
            '${month.month.toString().padLeft(2, '0')} 月',
            style: const TextStyle(
              color: _detailNavy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '税前 ${formatCents(month.salaryCents)} · 税后现金 ${formatCents(month.netCashCents)} · 预扣税 ${formatCents(month.monthlyTaxCents)}',
            style: const TextStyle(color: _detailMuted, fontSize: 10.5),
          ),
          children: <Widget>[
            _BreakdownSection(
              title: '个人扣款和个税',
              rows: <_InfoRowData>[
                _InfoRowData('税前工资', formatCents(month.salaryCents)),
                _InfoRowData(
                  '个人养老保险 · ${formatRate(employeePensionRateBps)}',
                  formatCents(month.employeePensionCents),
                ),
                _InfoRowData(
                  '个人医疗保险 · ${formatRate(employeeMedicalRateBps)}',
                  formatCents(month.employeeMedicalCents),
                ),
                _InfoRowData(
                  '个人失业保险 · ${formatRate(employeeUnemploymentRateBps)}',
                  formatCents(month.employeeUnemploymentCents),
                ),
                _InfoRowData(
                  '个人公积金 · ${formatRate(inputs.housingFundRateBps)}',
                  formatCents(month.employeeHousingFundCents),
                ),
                _InfoRowData(
                  '个人大病统筹（固定）',
                  formatCents(month.criticalIllnessCents),
                ),
                _InfoRowData(
                  '个人扣款合计',
                  formatCents(month.personalDeductionTotalCents),
                ),
                _InfoRowData('基本减除费用', formatCents(basicDeductionCents)),
                _InfoRowData(
                  '专项附加扣除',
                  formatCents(inputs.specialAdditionalDeductionCents),
                ),
                _InfoRowData(
                  '本月新增应纳税所得额',
                  formatCents(month.taxableIncomeIncrementCents),
                ),
                _InfoRowData(
                  '累计应纳税所得额',
                  formatCents(month.cumulativeTaxableIncomeCents),
                ),
                _InfoRowData(
                  '适用税率 / 速算扣除数',
                  '${formatRate(month.taxBracketRateBps)} / ${formatCents(month.quickDeductionCents)}',
                ),
                _InfoRowData(
                  '累计应预扣税额',
                  formatCents(month.cumulativeTaxDueCents),
                ),
                _InfoRowData('本月预扣个税', formatCents(month.monthlyTaxCents)),
                _InfoRowData(
                  '税后现金',
                  formatCents(month.netCashCents),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 9),
            _BreakdownSection(
              title: '综合到手组成',
              rows: <_InfoRowData>[
                _InfoRowData('税后现金', formatCents(month.netCashCents)),
                _InfoRowData(
                  '单位公积金入账',
                  formatCents(month.employerHousingFundCents),
                ),
                _InfoRowData(
                  '个人公积金入账',
                  formatCents(month.employeeHousingFundCents),
                ),
                _InfoRowData(
                  '个人医保账户入账',
                  formatCents(month.employeeMedicalCents),
                ),
                _InfoRowData('双边公积金合计', formatCents(bilateralFund)),
                _InfoRowData(
                  '综合到手',
                  formatCents(month.benefitACents),
                  strong: true,
                ),
                _InfoRowData(
                  '个人养老账户（另计）',
                  formatCents(month.employeePensionCents),
                ),
                _InfoRowData(
                  '综合到手 + 养老',
                  formatCents(month.benefitBCents),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 9),
            _BreakdownSection(
              title: '单位承担与成本',
              rows: <_InfoRowData>[
                _InfoRowData(
                  '单位养老保险 · ${formatRate(employerPensionRateBps)}',
                  formatCents(month.employerPensionCents),
                ),
                _InfoRowData(
                  '单位医疗保险 · ${formatRate(employerMedicalRateBps)}',
                  formatCents(month.employerMedicalCents),
                ),
                _InfoRowData(
                  '单位失业保险 · ${formatRate(employerUnemploymentRateBps)}',
                  formatCents(month.employerUnemploymentCents),
                ),
                _InfoRowData(
                  '单位工伤保险 · ${formatRate(inputs.workInjuryRateBps)}',
                  formatCents(month.employerWorkInjuryCents),
                ),
                _InfoRowData(
                  '单位公积金 · ${formatRate(inputs.housingFundRateBps)}',
                  formatCents(month.employerHousingFundCents),
                ),
                _InfoRowData(
                  '单位总成本',
                  formatCents(month.employerTotalCostCents),
                  strong: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: const TextStyle(
          color: _detailNavy,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: const TextStyle(color: _detailMuted, fontSize: 10.5),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.accent = false,
  });

  final String title;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _detailLine),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: _detailMuted, fontSize: 11.5),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: accent ? _detailTeal : _detailNavy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(15, 13, 15, 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _detailLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: _detailNavy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        for (final _InfoRowData row in rows) _InfoRow(row: row),
      ],
    ),
  );
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: _detailNavy,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        for (final _InfoRowData row in rows) _InfoRow(row: row),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final _InfoRowData row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            row.label,
            style: TextStyle(
              color: row.strong ? _detailNavy : _detailMuted,
              fontSize: 10.5,
              fontWeight: row.strong ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            row.value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: row.strong ? _detailTeal : _detailNavy,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;
}
