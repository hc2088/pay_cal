import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/payroll_controller.dart';
import '../../domain/payroll_models.dart';
import 'comparison_screen.dart';
import 'plan_comparison_table.dart';
import 'payroll_results_screen.dart';
import 'payroll_widgets.dart';
export 'comparison_screen.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, required this.onCopy});
  final VoidCallback onCopy;
  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  final selected = <String>[];
  void _open(PayrollPlan p) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => p.result == null
          ? LegacyPlanScreen(plan: p)
          : PayrollResultsScreen(results: [p.result!], savedName: p.name),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(payrollControllerProvider);
    selected.removeWhere((id) => !c.plans.any((p) => p.id == id));
    if (c.plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open_rounded,
                size: 62,
                color: payrollMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                '保存一份方案，方便下次比较',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '测算结果页点击“保存为方案”。工资、规则和当时结果会一起保存。',
                textAlign: TextAlign.center,
                style: TextStyle(color: payrollMuted),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: widget.onCopy, child: const Text('去测算')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (c.recoveryCount > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: PolicyNotice(
              text: '${c.recoveryCount} 条记录需要恢复，原文已保留，可在工具页导出备份。',
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '选择两份方案比较 · 已选 ${selected.length}/2',
                  style: const TextStyle(color: payrollMuted, fontSize: 13),
                ),
              ),
              FilledButton(
                onPressed: selected.length != 2
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ComparisonScreen(
                            first: c.plans.firstWhere(
                              (p) => p.id == selected[0],
                            ),
                            second: c.plans.firstWhere(
                              (p) => p.id == selected[1],
                            ),
                          ),
                        ),
                      ),
                child: const Text('开始对比'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: c.plans.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = c.plans[i];
              return Card(
                key: ValueKey('plan-card-${p.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            key: ValueKey('select-plan-${p.id}'),
                            value: selected.contains(p.id),
                            onChanged: (v) => setState(() {
                              if (v == false) {
                                selected.remove(p.id);
                              } else if (selected.length < 2) {
                                selected.add(p.id);
                              } else {
                                showMessage(context, '一次选择两份方案');
                              }
                            }),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _open(p),
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'open') {
                                _open(p);
                                return;
                              }
                              if (action == 'copy') {
                                c.copyPlan(p);
                                widget.onCopy();
                                return;
                              }
                              if (action == 'rename') {
                                final name = await askName(context, p.name);
                                if (name == null) return;
                                try {
                                  await c.rename(p.id, name);
                                } catch (_) {
                                  if (context.mounted) {
                                    showMessage(context, '重命名失败，请重试');
                                  }
                                }
                                return;
                              }
                              if (action == 'delete' &&
                                  await confirmAction(
                                    context,
                                    '删除“${p.name}”？',
                                    '只删除该方案，其他方案与当前草稿不变。',
                                  )) {
                                try {
                                  await c.delete(p.id);
                                } catch (_) {
                                  if (context.mounted) {
                                    showMessage(context, '删除失败，请重试');
                                  }
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'open', child: Text('查看结果')),
                              PopupMenuItem(
                                value: 'copy',
                                child: Text('复制并重算'),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('重命名'),
                              ),
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _open(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              p.result == null
                                  ? '旧版记录 · 年度与城市未记录'
                                  : '${p.result!.draft.city.name} · ${p.result!.draft.year} · ${resultStrategyName(p.result!)}',
                              style: const TextStyle(
                                color: payrollMuted,
                                fontSize: 12,
                              ),
                            ),
                            MetricRow(
                              '税后年薪',
                              displayMoney(p.value('net')),
                              emphasis: true,
                            ),
                            MetricRow('全年预扣个税', displayMoney(p.value('tax'))),
                            const Divider(height: 22),
                            PlanSettingsSummary(plan: p),
                            const SizedBox(height: 12),
                            Text(
                              displayDate(p.savedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: payrollMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class LegacyPlanScreen extends StatelessWidget {
  const LegacyPlanScreen({super.key, required this.plan});
  final PayrollPlan plan;
  @override
  Widget build(BuildContext context) {
    final rows = plan.legacy!['months'];
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PolicyNotice(
            text: '旧版快照，保留当时金额与口径；未用新版引擎重算。城市和年度未记录，不能直接作同年度高低结论。',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '原年度摘要',
            child: Column(
              children: [
                MetricRow('税后年薪', displayMoney(plan.value('net'))),
                MetricRow('全年预扣个税', displayMoney(plan.value('tax'))),
                MetricRow('全年企业成本', displayMoney(plan.value('employerCost'))),
                MetricRow(
                  '旧口径综合到手',
                  displayMoney(plan.legacy!['annualBenefitACents'] as int?),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (rows is! List || rows.isEmpty)
            const Text('原记录未保存月明细，不自动重建。')
          else
            SectionCard(
              title: '原月明细',
              child: Column(
                children: [
                  for (final m in rows)
                    MetricRow(
                      '${m['month']} 月',
                      '到账 ${displayMoney(m['netCashCents'])}\n个税 ${displayMoney(m['monthlyTaxCents'])}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
