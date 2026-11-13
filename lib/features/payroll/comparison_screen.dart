import 'package:flutter/material.dart';
import '../../domain/payroll_comparison.dart';
import '../../domain/payroll_models.dart';
import 'plan_comparison_table.dart';
import 'payroll_share.dart';
import 'payroll_widgets.dart';

const comparisonScopeNote =
    '金额单位：元。个人税后收入为已扣个税后的工资现金；加项收入另含双边公积金、医保个人账户估算和个人养老保险缴费，不含另行缴纳的个人养老金。医保估算排除固定附加费用，账户缴费不属于工资现金。单位成本含工资、当期奖金及单位五险一金；个税为预扣合计。年度在前，所选月份的金额与缴费规则在后，差额按 B − A 显示。';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({
    super.key,
    required this.first,
    required this.second,
  });
  final PayrollPlan first, second;
  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late PayrollPlan a = widget.first, b = widget.second;
  final horizontal = ScrollController();
  int month = 1;
  bool onlyDifferences = false;
  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comparison = PayrollComparison(a, b, month);
    final overview = comparisonOverview(comparison, onlyDifferences);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: scale > 1.4 ? kToolbarHeight * scale : null,
        title: Text('方案对比', maxLines: scale > 1.4 ? 2 : 1),
        actions: [
          IconButton(
            tooltip: '交换 A / B',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() {
              final old = a;
              a = b;
              b = old;
            }),
          ),
          IconButton(
            tooltip: '分享比较',
            icon: const Icon(Icons.ios_share),
            onPressed: () => previewPayrollImage(
              context,
              ComparisonExport(
                comparison: comparison,
                onlyDifferences: onlyDifferences,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 20,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int>(
                    key: const Key('comparison-month'),
                    value: month,
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text('$m 月明细')),
                    ],
                    onChanged: (v) => setState(() => month = v!),
                  ),
                  FilterChip(
                    label: const Text('只看差异'),
                    selected: onlyDifferences,
                    onSelected: (v) => setState(() => onlyDifferences = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width = comparisonTableWidth(
                      context,
                      box.maxWidth,
                      overview,
                    );
                    final table = Scrollbar(
                      controller: horizontal,
                      thumbVisibility: width > box.maxWidth,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        key: const Key('comparison-horizontal'),
                        controller: horizontal,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          child: Column(
                            children: [
                              PlanComparisonTable(
                                key: const Key('comparison-header'),
                                first: a,
                                second: b,
                                rows: const [],
                              ),
                              Expanded(
                                child: ListView(
                                  key: const Key('comparison-body'),
                                  padding: const EdgeInsets.only(bottom: 24),
                                  children: [
                                    if (!comparison.sameYear)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: PolicyNotice(
                                          text:
                                              '年度不同或未记录，仅并列展示，不计算差额；缺失值保留为“未记录”。',
                                        ),
                                      ),
                                    PlanComparisonTable(
                                      key: const Key('comparison-overview'),
                                      first: a,
                                      second: b,
                                      rows: overview,
                                      showHeader: false,
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        comparisonScopeNote,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: payrollMuted,
                                        ),
                                      ),
                                    ),
                                    if (comparison.hasBonus)
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        child: Text(
                                          '奖金月份的个人税后收入、个税和单位成本均包含当月奖金；年终奖行仅列示其中的奖金金额，不重复相加。',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: payrollMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    return Column(
                      children: [
                        if (width > box.maxWidth)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              '左右滑动查看各方案',
                              style: TextStyle(
                                fontSize: 12,
                                color: payrollMuted,
                              ),
                            ),
                          ),
                        Expanded(child: table),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComparisonExport extends StatelessWidget {
  const ComparisonExport({
    super.key,
    required this.comparison,
    required this.onlyDifferences,
  });
  final PayrollComparison comparison;
  final bool onlyDifferences;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '方案对比 · ${onlyDifferences ? '仅差异' : '完整'}',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      Text('A：${comparison.a.name}\nB：${comparison.b.name}'),
      const SizedBox(height: 8),
      Text(
        comparison.sameYear
            ? '${comparison.a.result!.draft.year} 年 · ${comparison.month} 月明细'
            : '年度不同或未记录 · ${comparison.month} 月明细 · 不计算差额',
      ),
      const SizedBox(height: 16),
      PlanComparisonTable(
        first: comparison.a,
        second: comparison.b,
        compact: true,
        rows: comparisonOverview(comparison, onlyDifferences),
      ),
      const SizedBox(height: 12),
      const Text(
        comparisonScopeNote,
        style: TextStyle(fontSize: 11, color: payrollMuted),
      ),
      if (comparison.hasBonus)
        const Text(
          '奖金月份的个人税后收入、个税和单位成本均包含当月奖金；年终奖行仅列示其中的奖金金额，不重复相加。',
          style: TextStyle(fontSize: 11, color: payrollMuted),
        ),
      const SizedBox(height: 8),
      Text(
        '生成于 ${displayDate(DateTime.now())} · 到账不含预计次年退税。',
        style: const TextStyle(fontSize: 11, color: payrollMuted),
      ),
    ],
  );
}
