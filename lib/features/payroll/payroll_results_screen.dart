import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/payroll_controller.dart';
import '../../domain/payroll_breakdown.dart';
import '../../domain/payroll_models.dart';
import 'annual_tax_details.dart';
import 'monthly_details_screen.dart';
import 'payroll_result_widgets.dart';
import 'payroll_share.dart';
import 'payroll_widgets.dart';
import 'plan_comparison_table.dart';

String strategyName(BonusMode mode) =>
    mode == BonusMode.separate ? '奖金单独计税' : '奖金并入工资';

String resultStrategyName(PayrollResult result) =>
    result.sum('bonus') == 0 ? '固定工资测算' : strategyName(result.strategy);

class PayrollResultsScreen extends ConsumerStatefulWidget {
  const PayrollResultsScreen({
    super.key,
    required this.results,
    this.savedName,
  });
  final List<PayrollResult> results;
  final String? savedName;
  @override
  ConsumerState<PayrollResultsScreen> createState() =>
      _PayrollResultsScreenState();
}

class _PayrollResultsScreenState extends ConsumerState<PayrollResultsScreen> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(payrollControllerProvider),
        r = widget.results[selected],
        d = r.draft;
    final title = widget.savedName ?? '测算结果';
    final january = MonthBreakdown(r, 1);
    final monthAmountsVary = r.months.any(
      (m) =>
          m['employee'] != r.months.first['employee'] ||
          m['employer'] != r.months.first['employer'] ||
          m['salary'] != r.months.first['salary'],
    );
    final monthNote = monthAmountsVary ? '按 1 月展示，各月见每月详情' : '每月';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '分享结果',
            icon: const Icon(Icons.ios_share),
            onPressed: () => previewPayrollImage(
              context,
              ResultExport(result: r, title: title),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '${d.city.name} · ${d.year} 年 · ${resultStrategyName(r)}',
            style: const TextStyle(color: payrollMuted),
          ),
          const SizedBox(height: 10),
          PolicyNotice(
            text: d.estimateConfirmed ? '自定义估算 · 当前缴费参数用于全年' : '按逐月已核验规则计算',
          ),
          if (widget.results.length > 1) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: '年终奖计税比较',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < widget.results.length; i++)
                        ChoiceChip(
                          label: Text(strategyName(widget.results[i].strategy)),
                          selected: selected == i,
                          onSelected: (_) => setState(() => selected = i),
                        ),
                    ],
                  ),
                  for (final option in widget.results)
                    MetricRow(
                      strategyName(option.strategy),
                      displayMoney(option.annualTaxDue),
                      emphasis: option == r,
                    ),
                  Text(
                    '年度应纳税估算相差 ${displayMoney((widget.results[0].annualTaxDue - widget.results[1].annualTaxDue).abs())}。选择方式仅用于测算。',
                    style: const TextStyle(color: payrollMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          AnnualCashSummary(key: const Key('result-cash-summary'), result: r),
          const SizedBox(height: 16),
          SectionCard(
            child: AnnualTotalIncome(
              key: const Key('result-annual-total-income'),
              result: r,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '月收入',
            trailing: TextButton(
              key: const Key('more-months'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MonthlyDetailsScreen(result: r),
                ),
              ),
              child: const Text('更多月详情 ›'),
            ),
            child: MonthIncomeTable(
              months: [r.months.first],
              onMonthTap: (month) => showMonthDetails(context, r, month),
            ),
          ),
          const SizedBox(height: 16),
          ResultExpandableCard(
            key: ValueKey('result-social-$selected'),
            title: '社保',
            amount: '${displayMoney(january.personalSocial)} / 月',
            subtitle:
                '个人每月社保 · ${january.socialBaseDescription}${monthAmountsVary ? '\n$monthNote' : ''}',
            children: [SocialContributionDetails(month: january)],
          ),
          const SizedBox(height: 16),
          ResultExpandableCard(
            key: ValueKey('result-housing-$selected'),
            title: '公积金',
            amount: '${displayMoney(january.value('housing'))} / 月',
            subtitle:
                '公司 + 个人 · 缴费基数 ${displayMoney(january.housing.base)}${monthAmountsVary ? '\n$monthNote' : ''}',
            children: [HousingContributionDetails(month: january)],
          ),
          const SizedBox(height: 16),
          ResultExpandableCard(
            key: ValueKey('result-company-$selected'),
            title: '公司支出',
            amount: '${displayMoney(january.regularCompanyCost)} / 月',
            subtitle:
                '月薪支出 + 公司社保 + 公司公积金${monthAmountsVary ? '\n$monthNote' : ''}',
            footer: MetricRow(
              '单位总成本',
              '${displayMoney(PayrollBreakdown(r).annualCompanyCost)} / 年',
              key: const Key('result-unit-total-cost'),
              emphasis: true,
            ),
            children: [CompanyCostDetails(month: january)],
          ),
          const SizedBox(height: 16),
          SectionCard(
            key: const Key('result-parameters'),
            title: '参数配置',
            child: PlanSettingsSummary.fromResult(result: r),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: ExpansionTile(
              key: PageStorageKey('annual-explanation-$selected'),
              title: const Text('计算说明'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 12),
              children: [
                AnnualTaxDetails(result: r),
                const Divider(height: 28),
                MetricRow('税前月薪', '${d.salary} 元'),
                MetricRow(
                  '专项附加扣除',
                  '${d.deduction.isEmpty ? '0' : d.deduction} 元/月',
                ),
                if (r.sum('bonus') > 0) MetricRow('奖金发放', '${d.bonusMonth} 月'),
                MetricRow('规则版本', d.city.version),
                MetricRow('生成时间', displayDate(r.createdAt)),
                MetricRow('养老金投入后可用现金', displayMoney(r.sum('available'))),
                const Text(
                  '年度个税为本年预扣合计。税后年薪不扣个人养老金投入，不包含次年汇算可能退税；公积金单独列示，不计入工资到账。',
                  style: TextStyle(color: payrollMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.savedName == null)
            FilledButton.icon(
              onPressed: c.busy || c.isSaved(r)
                  ? null
                  : () async {
                      final name = await askName(
                        context,
                        '${d.city.name} · 月薪 ${d.salary}',
                      );
                      if (name == null) return;
                      try {
                        await c.saveResult(r, name);
                        if (context.mounted) showMessage(context, '已保存到我的方案');
                      } catch (_) {
                        if (context.mounted) {
                          showMessage(context, '方案保存失败，结果仍保留，可重试');
                        }
                      }
                    },
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Padding(
                padding: const EdgeInsets.all(13),
                child: Text(c.isSaved(r) ? '已保存' : '保存为方案'),
              ),
            ),
        ],
      ),
    );
  }
}

class ResultExport extends StatelessWidget {
  const ResultExport({super.key, required this.result, required this.title});
  final PayrollResult result;
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        '${result.draft.city.name} · ${result.draft.year} · ${resultStrategyName(result)}',
      ),
      Text(result.draft.estimateConfirmed ? '自定义估算 · 当前参数用于全年' : '按逐月已核验规则'),
      const SizedBox(height: 16),
      AnnualCashSummary(key: const Key('export-cash-summary'), result: result),
      const SizedBox(height: 12),
      SectionCard(
        child: AnnualTotalIncome(
          key: const Key('export-annual-total-income'),
          fieldPrefix: 'export',
          result: result,
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        key: const Key('export-tax-adjustments'),
        title: '计税扣除与可用现金 · 全年',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MetricRow(
              '专项附加扣除',
              displayMoney(PayrollBreakdown(result).annualAdditionalDeduction),
            ),
            const FormulaText('用于计算个税，不从税后工资中再次扣除。'),
            MetricRow('个人养老金（自愿缴存）', displayMoney(result.sum('pension'))),
            MetricRow(
              '养老金投入后可用现金',
              displayMoney(result.sum('available')),
              emphasis: true,
            ),
            const FormulaText('可用现金 = 税后年薪 − 自愿缴存的个人养老金；与社保中的个人养老保险不同。'),
            const Divider(),
            MetricRow('汇算税额差（预扣 − 应纳）', displayMoney(result.refundEstimate)),
            const FormulaText('正数为预计可退税，负数为预计需补税，均不计入本年税后工资。'),
          ],
        ),
      ),
      const Divider(),
      const Text(
        '参数配置',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      PlanSettingsSummary.fromResult(
        key: const Key('export-parameters'),
        result: result,
      ),
      MetricRow('税前月薪', '${result.draft.salary} 元'),
      MetricRow('年终奖', displayMoney(result.sum('bonus'))),
      MetricRow(
        '单位总成本',
        '${displayMoney(PayrollBreakdown(result).annualCompanyCost)} / 年',
        key: const Key('export-unit-total-cost'),
        emphasis: true,
      ),
      const FormulaText('单位成本包含税前年薪、单位社保和单位公积金，不与个人收入相加。'),
      const Divider(),
      const Text(
        '12 个月明细',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const FormulaText(monthlyCompensationNote),
      for (final m in result.months) ...[
        MetricRow(
          '${m['month']} 月',
          '税后工资 ${displayMoney(m['net'])}\n个税 ${displayMoney(m['tax'])}',
        ),
        MonthlyTotalIncome(data: m),
        const Divider(),
      ],
      const Divider(),
      Text(
        '生成于 ${displayDate(result.createdAt)}\n规则 ${result.draft.city.version}\n账户缴费与现金分开；汇算税额差不计入本年到账。',
        style: const TextStyle(fontSize: 11, color: payrollMuted),
      ),
    ],
  );
}
