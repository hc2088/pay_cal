import 'package:flutter/material.dart';

import '../../calculation/saved_calculation.dart';
import '../../calculation/money_format.dart';
import 'calculation_history_format.dart';

const Color _detailNavy = Color(0xFF18324B);
const Color _detailTeal = Color(0xFF1D9A8A);
const Color _detailMuted = Color(0xFF718195);
const Color _detailLine = Color(0xFFE7EDF3);

class SavedCalculationDetailScreen extends StatelessWidget {
  const SavedCalculationDetailScreen({required this.calculation, super.key});

  final SavedCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final bool housingFollowsSocial =
        calculation.inputs.housingFundBaseMode.name == 'followSocialBase';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(title: const Text('结果概览')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '保存于 ${formatSavedTimestamp(calculation.savedAt)}',
              style: const TextStyle(color: _detailMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              title: '全年单位成本',
              value: formatCents(calculation.annualEmployerCostCents),
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              title: '全年税后现金',
              value: formatCents(calculation.annualNetCashCents),
              accent: true,
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              title: '全年权益 A',
              value: formatCents(calculation.annualBenefitACents),
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              title: '全年权益 B',
              value: formatCents(calculation.annualBenefitBCents),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: '全年累计预扣个税',
              rows: <_InfoRowData>[
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
                  formatCents(
                    calculation.inputs.specialAdditionalDeductionCents,
                  ),
                ),
                _InfoRowData(
                  calculation.inputs.socialBaseMode.name == 'custom'
                      ? '自定义社保基数'
                      : '社保基数（跟随工资）',
                  formatCents(calculation.inputs.socialBaseCents),
                ),
                _InfoRowData(
                  housingFollowsSocial ? '公积金基数（跟随社保）' : '公积金基数（自定义）',
                  formatCents(calculation.inputs.housingFundBaseCents),
                ),
                _InfoRowData(
                  '公积金比例',
                  '${formatRate(calculation.inputs.housingFundRateBps)}（单位和个人）',
                ),
                _InfoRowData(
                  '工伤保险费率',
                  formatRate(calculation.inputs.workInjuryRateBps),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: '公积金缴存结果',
              rows: <_InfoRowData>[
                _InfoRowData(
                  '个人月缴存额',
                  formatCents(calculation.annualEmployeeHousingFundCents ~/ 12),
                ),
                _InfoRowData(
                  '单位月缴存额',
                  formatCents(calculation.annualEmployerHousingFundCents ~/ 12),
                ),
                _InfoRowData(
                  '全年双边缴存额',
                  formatCents(
                    calculation.annualEmployeeHousingFundCents +
                        calculation.annualEmployerHousingFundCents,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '结果为保存时的快照，不会随当前测算参数变化。费率和当地缴费上下限可能造成实际差异。',
              style: TextStyle(color: _detailMuted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _detailLine),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _detailMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent ? _detailTeal : _detailNavy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 6),
          for (final _InfoRowData row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(color: _detailMuted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: _detailNavy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value);

  final String label;
  final String value;
}
