import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/saved_calculation.dart';
import '../../calculation/money_format.dart';
import 'calculation_history_format.dart';
import 'calculator_providers.dart';
import 'income_breakdown_widgets.dart';
import 'saved_calculation_detail_screen.dart';

const Color _historyNavy = Color(0xFF18324B);
const Color _historyTeal = Color(0xFF1D9A8A);
const Color _historyMuted = Color(0xFF718195);

class CalculationHistoryScreen extends ConsumerWidget {
  const CalculationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SavedCalculation> calculations = ref.watch(
      calculationHistoryProvider,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('历史测算'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: calculations.isEmpty
                ? null
                : () => _deleteAll(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            label: const Text('清空'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: calculations.isEmpty
          ? const _EmptyHistory()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              itemCount: calculations.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final SavedCalculation calculation = calculations[index];
                return _HistoryCard(
                  calculation: calculation,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          SavedCalculationDetailScreen(
                            calculation: calculation,
                          ),
                    ),
                  ),
                  onDelete: () => _deleteOne(context, ref, calculation),
                );
              },
            ),
    );
  }

  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    SavedCalculation calculation,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除这条测算？'),
        content: const Text('删除后无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(calculationHistoryProvider.notifier)
          .delete(calculation.id);
    } catch (_) {
      if (context.mounted) {
        _showStorageError(context);
      }
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清空全部历史测算？'),
        content: const Text('所有已保存的测算参数和结果都会被删除，且无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(calculationHistoryProvider.notifier).deleteAll();
    } catch (_) {
      if (context.mounted) {
        _showStorageError(context);
      }
    }
  }

  void _showStorageError(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存失败，请检查设备存储空间后重试。')));
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.calculation,
    required this.onTap,
    required this.onDelete,
  });

  final SavedCalculation calculation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final IncomeTotals totals = IncomeTotals.fromMonths(calculation.months);
    final inputs = calculation.inputs;
    final String socialMode =
        inputs.socialBaseMode == SocialBaseMode.followSalary ? '跟随工资' : '自定义';
    final String housingMode =
        inputs.housingFundBaseMode == HousingFundBaseMode.followSocialBase
        ? '跟随社保'
        : '自定义';

    return Card(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      formatSavedTimestamp(calculation.savedAt),
                      style: const TextStyle(
                        color: _historyNavy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除这条测算',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: _historyMuted,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: <Widget>[
                  _SchemeCondition(
                    label: '月薪',
                    value: formatCents(inputs.grossMonthlySalaryCents),
                  ),
                  _SchemeCondition(
                    label: '专项扣除',
                    value:
                        '${formatCents(inputs.specialAdditionalDeductionCents)}/月',
                  ),
                  _SchemeCondition(
                    label: '社保基数',
                    value: '${formatCents(inputs.socialBaseCents)}·$socialMode',
                  ),
                  _SchemeCondition(
                    label: '公积金基数',
                    value:
                        '${formatCents(inputs.housingFundBaseCents)}·$housingMode',
                  ),
                  _SchemeCondition(
                    label: '公积金比例',
                    value: formatRate(inputs.housingFundRateBps),
                  ),
                  _SchemeCondition(
                    label: '工伤比例',
                    value: formatRate(inputs.workInjuryRateBps),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FB),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _HistoryMetric(
                        label: '税前工资',
                        amountCents: totals.grossSalaryCents,
                      ),
                    ),
                    Expanded(
                      child: _HistoryMetric(
                        label: '单位五险一金',
                        amountCents: totals.employerContributionCents,
                      ),
                    ),
                    Expanded(
                      child: _HistoryMetric(
                        label: '单位总成本',
                        amountCents: totals.employerTotalCostCents,
                      ),
                    ),
                    Expanded(
                      child: _HistoryMetric(
                        label: '税后总收入',
                        amountCents: totals.personalAfterTaxIncomeCents,
                        accent: true,
                      ),
                    ),
                    Expanded(
                      child: _HistoryMetric(
                        label: '扣税',
                        amountCents: totals.taxCents,
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
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.label,
    required this.amountCents,
    this.accent = false,
  });

  final String label;
  final int amountCents;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _historyMuted,
            fontSize: 7.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            formatCents(amountCents, withSymbol: false),
            style: TextStyle(
              color: accent ? _historyTeal : _historyNavy,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SchemeCondition extends StatelessWidget {
  const _SchemeCondition({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8FB),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: _historyMuted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: _historyNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 8.5),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.history_rounded,
              color: _historyTeal.withValues(alpha: 0.7),
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              '还没有保存的测算',
              style: TextStyle(
                color: _historyNavy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '回到测算页，点击“保存本次测算”即可添加记录。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _historyMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
