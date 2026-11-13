import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../calculation/money_format.dart';
import '../../domain/payroll_comparison.dart';
import '../../domain/payroll_models.dart';
import '../../domain/plan_snapshot_details.dart';
import 'payroll_widgets.dart';

class ComparisonTableEntry {
  const ComparisonTableEntry(this.label, this.left, this.right, {this.delta});
  factory ComparisonTableEntry.metric(ComparisonMetric metric) =>
      ComparisonTableEntry(
        metric.label,
        metric.a == null ? '未记录' : formatCents(metric.a!, withSymbol: false),
        metric.b == null ? '未记录' : formatCents(metric.b!, withSymbol: false),
        delta: metric.difference,
      );
  final String label, left, right;
  final int? delta;
  bool get different => left != right;
}

List<ComparisonTableEntry> comparisonOverview(
  PayrollComparison comparison,
  bool onlyDifferences,
) {
  List<ComparisonTableEntry> section(
    List<ComparisonMetric> metrics,
    Map<String, (String, String)> settings,
    String empty,
  ) {
    final rows = [
      ...metrics
          .where((m) => !onlyDifferences || m.isDifferent)
          .map(ComparisonTableEntry.metric),
      for (final e in settings.entries.where(
        (e) => !onlyDifferences || e.value.$1 != e.value.$2,
      ))
        ComparisonTableEntry(e.key, e.value.$1, e.value.$2),
    ];
    return rows.isEmpty ? [ComparisonTableEntry(empty, '—', '—')] : rows;
  }

  return [
    ...section(comparison.overviewAnnual, comparison.annualSettings, '年度项目无差异'),
    ...section(
      comparison.overviewMonthly,
      comparison.monthlySettings,
      '本月项目无差异',
    ),
  ];
}

/// A single set of column widths is used for both the fixed header and body.
/// Widen the scrollable table for large text or large amounts instead of
/// shrinking values or replacing the requested side-by-side comparison.
double comparisonTableWidth(
  BuildContext context,
  double available,
  List<ComparisonTableEntry> rows,
) {
  final scale = MediaQuery.textScalerOf(context);
  var valueWidth = scale.scale(100);
  for (final row in rows) {
    for (final text in [row.left, row.right]) {
      if (!RegExp(r'^-?[\d,.]+$').hasMatch(text)) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        textScaler: scale,
        textDirection: TextDirection.ltr,
      )..layout();
      valueWidth = math.max(valueWidth, painter.width + 22);
      painter.dispose();
    }
  }
  return math.max(available, scale.scale(128) + valueWidth * 2);
}

class PlanComparisonTable extends StatelessWidget {
  const PlanComparisonTable({
    super.key,
    required this.first,
    required this.second,
    required this.rows,
    this.showHeader = true,
    this.compact = false,
  });
  final PayrollPlan first, second;
  final List<ComparisonTableEntry> rows;
  final bool showHeader, compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 11.0 : 13.0;
    Widget cell(
      String text, {
      bool label = false,
      bool different = false,
      int? delta,
    }) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 11 : 14,
      ),
      child: Column(
        crossAxisAlignment: label
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            label ? text.replaceAll('（', '\n（') : text,
            textAlign: label ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              color: different ? payrollBlue : payrollInk,
              fontWeight: different ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (delta != null && delta != 0) ...[
            const SizedBox(height: 4),
            Text(
              '差额 ${delta > 0 ? '+' : ''}${formatCents(delta, withSymbol: false)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: payrollMuted,
              ),
            ),
          ],
        ],
      ),
    );
    Widget heading(PayrollPlan plan, String letter) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text(
              '月薪 ${PlanSnapshotDetails(plan).monthlySalary.replaceAll('¥', '')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: payrollInk,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$letter · ${plan.name}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: payrollMuted,
              ),
            ),
          ],
        ),
      );
      // Image export renders without a Navigator/Overlay. Keep the export
      // header static; only the interactive screen needs a tooltip.
      return compact
          ? content
          : Tooltip(message: '$letter · ${plan.name}', child: content);
    }

    return Table(
      columnWidths: {
        0: FixedColumnWidth(
          compact ? 106 : MediaQuery.textScalerOf(context).scale(128),
        ),
        1: const FlexColumnWidth(),
        2: const FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(color: const Color(0xFFE4EAF1)),
      children: [
        if (showHeader)
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFEDF2F8)),
            children: [
              cell('项目', label: true),
              heading(first, 'A'),
              heading(second, 'B'),
            ],
          ),
        for (var i = 0; i < rows.length; i++)
          TableRow(
            key: ValueKey('comparison-row-${rows[i].label}'),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : const Color(0xFFF5F7FA),
            ),
            children: [
              cell(rows[i].label, label: true),
              cell(rows[i].left),
              cell(
                rows[i].right,
                different: rows[i].different,
                delta: rows[i].delta,
              ),
            ],
          ),
      ],
    );
  }
}

class PlanSettingsSummary extends StatelessWidget {
  const PlanSettingsSummary({super.key, required PayrollPlan this.plan})
    : result = null;
  const PlanSettingsSummary.fromResult({
    super.key,
    required PayrollResult this.result,
  }) : plan = null;
  final PayrollPlan? plan;
  final PayrollResult? result;
  @override
  Widget build(BuildContext context) {
    final details = result == null
        ? PlanSnapshotDetails(plan!)
        : PlanSnapshotDetails.fromResult(result!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in {
          '税前月薪': details.monthlySalary,
          ...details.settings,
        }.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          color: payrollMuted,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: const TextStyle(fontSize: 13, color: payrollInk),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            color: payrollMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: payrollInk,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}
