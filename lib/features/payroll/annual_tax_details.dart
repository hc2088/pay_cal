import 'package:flutter/material.dart';
import '../../domain/payroll_breakdown.dart';
import '../../domain/payroll_models.dart';
import '../calculator/methodology_screen.dart';
import 'payroll_result_widgets.dart';
import 'payroll_widgets.dart';

class AnnualTaxDetails extends StatelessWidget {
  const AnnualTaxDetails({super.key, required this.result});
  final PayrollResult result;

  @override
  Widget build(BuildContext context) {
    final a = AnnualTaxBreakdown(result);
    Widget heading(String title, {bool help = false}) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (help)
            IconButton(
              key: const Key('annual-tax-help'),
              tooltip: '查看税率与速算扣除表',
              icon: const Icon(Icons.info_outline, color: payrollBlue),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MethodologyScreen(
                    showTaxRates: true,
                    annualTaxableCents: a.taxBase,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('年度税后工资'),
        FormulaText(
          '税后工资 = 税前工资${a.bonus > 0 ? '及奖金' : ''} − 已预扣个税 − 个人社保 − 个人公积金',
        ),
        MetricRow('全年税前工资', displayMoney(a.salary)),
        if (a.bonus > 0) MetricRow('全年奖金', displayMoney(a.bonus)),
        MetricRow('全年已预扣个税', displayMoney(a.withheldTax)),
        MetricRow('全年个人社保', displayMoney(a.social)),
        MetricRow('全年个人公积金', displayMoney(a.housing)),
        FormulaText(
          '${displayMoney(a.gross)} − ${displayMoney(a.withheldTax)} − ${displayMoney(a.social)} − ${displayMoney(a.housing)} = ${displayMoney(a.net)}',
          key: const Key('annual-net-formula'),
        ),
        MetricRow('税后年薪', displayMoney(a.net), emphasis: true),
        const FormulaText('个人养老金从到账后另行投入，不重复扣减税后工资；可能退税不提前计入到账。'),
        const Divider(height: 28),
        heading('年度应纳税所得额'),
        const FormulaText('应纳税所得额是查税率表的计税基数，不是最终缴纳的税款。'),
        const FormulaText(
          '年度应纳税所得额 = 综合所得收入额 − 基本减除费用 − 专项扣除 − 专项附加扣除 − 依法确定的其他扣除',
        ),
        MetricRow('全年综合所得收入额', displayMoney(a.income), emphasis: true),
        MetricRow('工资收入', displayMoney(a.salary)),
        if (a.mergedBonus > 0) MetricRow('并入计税奖金', displayMoney(a.mergedBonus)),
        if (a.benefit > 0) MetricRow('单位应税福利', displayMoney(a.benefit)),
        if (a.separateBonus)
          FormulaText('年终奖 ${displayMoney(a.bonus)} 单独计税，不计入此处综合所得收入额。'),
        MetricRow('基本减除费用（5,000 元 × 12 月）', displayMoney(a.basicDeduction)),
        MetricRow('专项扣除（个人社保及公积金可扣除额）', displayMoney(a.deductible)),
        if (a.hasCustomDeductible)
          FormulaText(
            '实际缴费为社保 ${displayMoney(a.social)}、公积金 ${displayMoney(a.housing)}；计税使用已确认的可扣除额 ${displayMoney(a.deductible)}。',
          )
        else ...[
          MetricRow('其中：个人社保', displayMoney(a.social)),
          MetricRow('其中：个人公积金', displayMoney(a.housing)),
        ],
        MetricRow('专项附加扣除', displayMoney(a.additionalDeduction)),
        MetricRow('其他扣除：个人养老金', displayMoney(a.pension)),
        const FormulaText('社保公积金只扣个人依法可扣除部分，公司缴纳不在工资中重复减除。当前方案的其他扣除仅包含个人养老金。'),
        FormulaText(
          '${displayMoney(a.income)} − ${displayMoney(a.basicDeduction)} − ${displayMoney(a.deductible)} − ${displayMoney(a.additionalDeduction)} − ${displayMoney(a.pension)} = ${displayMoney(a.rawTaxBase)}',
          key: const Key('annual-tax-base-formula'),
        ),
        if (a.rawTaxBase < 0) const FormulaText('扣除后余额小于 0，应纳税所得额按 0 计算。'),
        MetricRow('年度应纳税所得额', displayMoney(a.taxBase), emphasis: true),
        const Divider(height: 28),
        heading('年度个税计算', help: true),
        const FormulaText('综合所得应纳税额 = 年度应纳税所得额 × 适用税率 − 速算扣除数'),
        MetricRow('适用税率', rateText(a.taxRate)),
        MetricRow('速算扣除数', displayMoney(a.quickDeduction)),
        FormulaText(
          '${displayMoney(a.taxBase)} × ${rateText(a.taxRate)} − ${displayMoney(a.quickDeduction)} = ${displayMoney(a.annualWageTax)}',
          key: const Key('annual-tax-formula'),
        ),
        if (a.separateBonus) ...[
          const SizedBox(height: 10),
          const FormulaText('奖金单独计税：奖金 ÷ 12 确定税率和月度速算扣除数，奖金全额 × 税率 − 速算扣除数。'),
          MetricRow('奖金适用税率', rateText(a.bonusTaxRate)),
          MetricRow('奖金速算扣除数', displayMoney(a.bonusQuickDeduction)),
          FormulaText(
            '${displayMoney(a.bonus)} × ${rateText(a.bonusTaxRate)} − ${displayMoney(a.bonusQuickDeduction)} = ${displayMoney(a.bonusTax)}',
          ),
          FormulaText(
            '全年应纳个税 = 综合所得税 ${displayMoney(a.annualWageTax)} + 奖金税 ${displayMoney(a.bonusTax)} = ${displayMoney(result.annualTaxDue)}',
          ),
        ],
        MetricRow(
          '全年应纳个税（估算）',
          displayMoney(result.annualTaxDue),
          emphasis: true,
        ),
        const Divider(height: 28),
        heading('预扣与年度汇算'),
        MetricRow('工资累计已预扣', displayMoney(a.withheldWageTax)),
        if (a.separateBonus) MetricRow('奖金已扣个税', displayMoney(a.bonusTax)),
        MetricRow('全年已预扣合计', displayMoney(a.withheldTax)),
        if (result.draft.pensionAtSettlement && a.pension > 0) ...[
          FormulaText('个人养老金 ${displayMoney(a.pension)} 留待年度汇算扣除，未减少本年工资预扣税。'),
          MetricRow('12 月预扣计税基数', displayMoney(a.withholdingTaxBase)),
          MetricRow('汇算后年度计税基数', displayMoney(a.taxBase)),
        ],
        const FormulaText('汇算税额差 = 全年已预扣个税 − 全年应纳个税'),
        FormulaText(
          '${displayMoney(a.withheldTax)} − ${displayMoney(result.annualTaxDue)} = ${displayMoney(result.refundEstimate)}',
        ),
        MetricRow(
          result.refundEstimate < 0 ? '预计需补税' : '预计可退税',
          displayMoney(result.refundEstimate.abs()),
          emphasis: true,
        ),
        const FormulaText(
          '月度个税按累计预扣法计算，累计税额下降时不在工资中即时退税。本页仅按本方案收入与扣除估算；其他综合所得、捐赠和减免税未计入。',
        ),
      ],
    );
  }
}
