import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/saved_calculation.dart';
import '../../calculation/money_format.dart';
import 'calculation_history_format.dart';
import 'calculator_providers.dart';
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
    final bool followsSocial =
        calculation.inputs.housingFundBaseMode.name == 'followSocialBase';

    return Card(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      formatSavedTimestamp(calculation.savedAt),
                      style: const TextStyle(
                        color: _historyNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '工资 ${formatCents(calculation.inputs.grossMonthlySalaryCents)}  ·  '
                      '社保 ${formatCents(calculation.inputs.socialBaseCents)}',
                      style: const TextStyle(
                        color: _historyMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '公积金基数 ${formatCents(calculation.inputs.housingFundBaseCents)}'
                      '${followsSocial ? '（跟随社保）' : '（自定义）'}',
                      style: const TextStyle(
                        color: _historyMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const Text(
                    '全年综合到手',
                    style: TextStyle(color: _historyMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCents(calculation.annualBenefitACents),
                    style: const TextStyle(
                      color: _historyTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: '删除这条测算',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: _historyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
