import 'package:flutter/material.dart';
import '../../domain/payroll_breakdown.dart';
import '../../domain/payroll_models.dart';
import 'payroll_result_widgets.dart';
import 'payroll_widgets.dart';

class MonthlyDetailsScreen extends StatelessWidget {
  const MonthlyDetailsScreen({super.key, required this.result});
  final PayrollResult result;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('每月详情')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${result.draft.year} 年 · ${result.draft.city.name}',
          style: const TextStyle(color: payrollMuted),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: MonthIncomeTable(
            months: result.months,
            onMonthTap: (month) => showMonthDetails(context, result, month),
          ),
        ),
        const SizedBox(height: 12),
        const FormulaText('金额单位：元。点击当月行查看缴费明细与累计个税计算过程。'),
        if (result.sum('bonus') > 0)
          FormulaText('${result.draft.bonusMonth} 月包含当月发放的奖金和对应个税。'),
      ],
    ),
  );
}

Future<void> showMonthDetails(
  BuildContext context,
  PayrollResult result,
  int month,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .88,
    minChildSize: .45,
    maxChildSize: .96,
    builder: (context, controller) => MonthDetailSheet(
      month: MonthBreakdown(result, month),
      controller: controller,
    ),
  ),
);

class MonthDetailSheet extends StatelessWidget {
  const MonthDetailSheet({
    super.key,
    required this.month,
    required this.controller,
  });
  final MonthBreakdown month;
  final ScrollController controller;
  @override
  Widget build(BuildContext context) {
    final m = month;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFC4CEDA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 8, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${m.month} 月详情',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭明细',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SectionCard(
                key: const Key('month-net-section'),
                title: m.value('bonus') == 0 ? '税后月薪' : '税后月薪（含当月奖金）',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      displayMoney(m.value('net')),
                      style: const TextStyle(
                        fontSize: 26,
                        color: payrollBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FormulaText(
                      '税前月薪 − 个人社保 − 个人公积金 − 个税${m.value('bonus') == 0 ? '' : ' + 当月奖金'}',
                    ),
                    FormulaText(
                      '${displayMoney(m.value('salary'))} − ${displayMoney(m.personalSocial)} − ${displayMoney(m.housing.employee)} − ${displayMoney(m.value('tax'))}${m.value('bonus') == 0 ? '' : ' + ${displayMoney(m.value('bonus'))}'} = ${displayMoney(m.value('net'))}',
                    ),
                    if (m.value('pension') > 0) ...[
                      const Divider(height: 24),
                      MetricRow('个人养老金投入', displayMoney(m.value('pension'))),
                      MetricRow('投入后可用现金', displayMoney(m.value('available'))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                key: const Key('month-total-section'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonthlyTotalIncome(data: m.data),
                    const SizedBox(height: 10),
                    const FormulaText(monthlyCompensationNote),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                key: const Key('month-social-section'),
                title: '个人社保',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MetricRow(
                      '当月合计',
                      displayMoney(m.personalSocial),
                      emphasis: true,
                    ),
                    FormulaText(m.socialBaseDescription),
                    const SizedBox(height: 16),
                    SocialContributionDetails(month: m, showCompany: false),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                key: const Key('month-housing-section'),
                title: '公积金',
                child: Column(
                  children: [
                    MetricRow(
                      '公司 + 个人',
                      displayMoney(m.value('housing')),
                      emphasis: true,
                    ),
                    HousingContributionDetails(month: m),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                key: const Key('month-tax-section'),
                title: '个税',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MetricRow(
                      '当月个税',
                      displayMoney(m.value('tax')),
                      emphasis: true,
                    ),
                    const FormulaText('累计应纳税所得额 × 预扣率 − 速算扣除数 − 此前累计已缴税额'),
                    FormulaText(
                      '${displayMoney(m.value('taxBase'))} × ${rateText(m.value('taxRate'))} − ${displayMoney(m.value('quick'))} − ${displayMoney(m.previouslyPaid)}',
                    ),
                    MetricRow(
                      '累计应预扣税额',
                      displayMoney(m.value('cumulativeDue')),
                    ),
                    MetricRow('此前累计已缴税额', displayMoney(m.previouslyPaid)),
                    MetricRow(
                      '本月工资预扣个税',
                      displayMoney(m.value('wageTax')),
                      emphasis: true,
                    ),
                    if (m.value('cumulativeDue') < m.previouslyPaid)
                      const FormulaText('差额为负，本月预扣税额为 0；多预缴部分在年度汇算时处理。'),
                    if (m.value('bonusTax') > 0) ...[
                      MetricRow('当月奖金单独计税', displayMoney(m.value('bonusTax'))),
                      FormulaText(
                        '当月个税 = 工资预扣 ${displayMoney(m.value('wageTax'))} + 奖金个税 ${displayMoney(m.value('bonusTax'))}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                key: const Key('month-tax-basis-section'),
                title: '累计应纳税所得额',
                child: CumulativeTaxDetails(month: m),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CumulativeTaxDetails extends StatelessWidget {
  const CumulativeTaxDetails({super.key, required this.month});
  final MonthBreakdown month;
  @override
  Widget build(BuildContext context) {
    final m = month;
    final deductibleParts = m.hasCustomDeductible
        ? '社保公积金可扣除额 ${displayMoney(m.cumulativeDeductible)}'
        : '个人社保 ${displayMoney(m.cumulativeSocial)} − 个人公积金 ${displayMoney(m.cumulativeHousing)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          displayMoney(m.value('taxBase')),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: payrollBlue,
          ),
        ),
        const SizedBox(height: 10),
        FormulaText('截至 ${m.month} 月：累计收入 − 累计扣除'),
        MetricRow('累计收入', displayMoney(m.cumulativeIncome), emphasis: true),
        MetricRow('累计税前工资', displayMoney(m.cumulativeSalary)),
        if (m.cumulativeMergedBonus > 0)
          MetricRow('累计并入奖金', displayMoney(m.cumulativeMergedBonus)),
        if (m.cumulativeBenefit > 0)
          MetricRow('累计单位应税福利', displayMoney(m.cumulativeBenefit)),
        const Divider(height: 24),
        MetricRow('累计扣除', displayMoney(m.deductionTotal), emphasis: true),
        MetricRow(
          '累计减除费用（5,000 元/月）',
          displayMoney(m.cumulativeBasicDeduction),
        ),
        if (m.hasCustomDeductible) ...[
          MetricRow('累计社保公积金可扣除额', displayMoney(m.cumulativeDeductible)),
          FormulaText(
            '实际个人社保 ${displayMoney(m.cumulativeSocial)}、个人公积金 ${displayMoney(m.cumulativeHousing)}；计税按已确认的可扣除额。',
          ),
        ] else ...[
          MetricRow('累计个人社保', displayMoney(m.cumulativeSocial)),
          MetricRow('累计个人公积金', displayMoney(m.cumulativeHousing)),
        ],
        MetricRow('累计专项附加扣除', displayMoney(m.cumulativeAdditionalDeduction)),
        MetricRow('累计个人养老金扣除', displayMoney(m.cumulativePensionDeduction)),
        if (m.result.draft.pensionAtSettlement && m.cumulative('pension') > 0)
          FormulaText(
            '养老金已缴 ${displayMoney(m.cumulative('pension'))}，选择在年度汇算扣除，本月预扣环节暂不扣除。',
          ),
        const Divider(height: 24),
        FormulaText(
          '累计收入 ${displayMoney(m.cumulativeIncome)} − 减除费用 ${displayMoney(m.cumulativeBasicDeduction)} − $deductibleParts − 专项附加扣除 ${displayMoney(m.cumulativeAdditionalDeduction)} − 养老金扣除 ${displayMoney(m.cumulativePensionDeduction)} = ${displayMoney(m.value('rawTaxBase'))}',
        ),
        if (m.value('rawTaxBase') < 0)
          const FormulaText('扣除后余额小于 0，累计计税所得额按 0 计算。'),
      ],
    );
  }
}
