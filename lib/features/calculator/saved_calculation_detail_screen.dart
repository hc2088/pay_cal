import 'package:flutter/material.dart';

import '../../calculation/saved_calculation.dart';
import 'calculation_history_format.dart';
import 'calculation_share_service.dart';
import 'income_breakdown_widgets.dart';
import 'salary_scheme_panel.dart';
import 'tax_basis_breakdown.dart';

const Color _detailMuted = Color(0xFF718195);

class SavedCalculationDetailScreen extends StatelessWidget {
  const SavedCalculationDetailScreen({required this.calculation, super.key});

  final SavedCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final IncomeTotals totals = IncomeTotals.fromMonths(calculation.months);

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
          const SizedBox(height: 12),
          SalarySchemePanel(
            inputs: calculation.inputs,
            title: '保存时的测算参数',
            subtitle: '保留本次测算时的基数、扣除和缴费比例',
          ),
          const SizedBox(height: 12),
          IncomeOverviewPanel(totals: totals, annual: true),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: MonthlyIncomeTable(
                months: calculation.months,
                showHeading: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TaxBasisBreakdown(
            inputs: calculation.inputs,
            months: calculation.months,
          ),
          const SizedBox(height: 8),
          const Text(
            '个人缴费包含个人社保、公积金和大病统筹。个人总权益包含账户入账，账户资金不等于全部可立即支取；个税按累计预扣法逐月计算。',
            style: TextStyle(color: _detailMuted, fontSize: 10, height: 1.45),
          ),
        ],
      ),
    );
  }
}
