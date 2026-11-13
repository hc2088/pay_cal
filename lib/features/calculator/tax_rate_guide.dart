import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../calculation/money_format.dart';
import '../../domain/payroll_engine.dart';
import '../../domain/payroll_models.dart';

/// Uses the same rate constants as the calculator, with unambiguous bounds.
class TaxRateGuide extends StatelessWidget {
  const TaxRateGuide({
    super.key,
    this.annualTaxableCents,
    required this.onOpenSource,
  });
  final int? annualTaxableCents;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final selected = annualTaxableCents == null
        ? null
        : PayrollEngine.bracket(annualTaxableCents!);
    return ListView(
      key: const PageStorageKey('tax-rate-guide'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        const Text(
          '综合所得税率与速算扣除表',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text('适用于全年应纳税所得额及工资薪金累计预扣。金额单位：元。'),
        if (annualTaxableCents != null) ...[
          const SizedBox(height: 12),
          Text(
            '本方案年度计税基数 ${formatCents(annualTaxableCents!)}，适用第 ${selected! + 1} 档：${rateText(PayrollEngine.rates[selected])}。',
            style: const TextStyle(
              color: Color(0xFF2956D9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _RateTable(selected: selected),
        const SizedBox(height: 16),
        const Text('应纳税额 = 应纳税所得额 × 适用税率 − 速算扣除数。计税基数小于 0 时按 0 计算；速算扣除数只减一次。'),
        const SizedBox(height: 12),
        const Text(
          '全年应纳税所得额 = 综合所得收入额 − 60,000 元基本减除费用 − 专项扣除 − 专项附加扣除 − 依法确定的其他扣除。符合条件的捐赠、减免税等按规定处理，本测算未包含这些事项。',
        ),
        const SizedBox(height: 12),
        const Text(
          '专项扣除是个人按规定缴纳的基本养老保险、基本医疗保险、失业保险和住房公积金等；专项附加扣除是子女教育、住房租金等申报项目，两者与每月 5,000 元减除费用分别计算。公司缴纳部分不重复扣除。',
        ),
        const SizedBox(height: 12),
        const Text(
          '每月工资预扣税 = max(0，累计应纳税所得额 × 预扣率 − 速算扣除数 − 此前已预扣工资个税)。全年已预扣与汇算应纳税额可能不同。',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenSource,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('查看税务机关原文'),
          ),
        ),
        const Divider(height: 32),
        const Text(
          '全年一次性奖金单独计税',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          '奖金 ÷ 12 的结果用于查下表。算税时使用奖金全额：奖金税 = 奖金全额 × 税率 − 月度速算扣除数。符合条件的奖金单独计税政策执行至 2027 年 12 月 31 日。',
        ),
        const SizedBox(height: 16),
        const _RateTable(bonus: true),
        const SizedBox(height: 16),
        const Text('详细扣除口径、养老金时点和官方政策来源见“完整说明”。'),
      ],
    );
  }
}

class _RateTable extends StatelessWidget {
  const _RateTable({this.bonus = false, this.selected});
  final bool bonus;
  final int? selected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final width = math.max(constraints.maxWidth, 320 * scale);
      String amount(int value) =>
          formatCents(value, withSymbol: false).replaceAll('.00', '');
      final limits = PayrollEngine.limits
          .map((v) => bonus ? v ~/ 12 : v)
          .toList();
      Widget cell(String value, {bool header = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: header ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (width > constraints.maxWidth)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('左右滑动查看完整税率表', style: TextStyle(fontSize: 12)),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Table(
                key: Key(
                  bonus ? 'bonus-tax-rate-table' : 'annual-tax-rate-table',
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(.7),
                  2: FlexColumnWidth(1.1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: const Color(0xFFE4EAF1)),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFEDF2F8)),
                    children: [
                      cell(bonus ? '奖金 ÷ 12（元）' : '应纳税所得额（元）', header: true),
                      cell('税率', header: true),
                      cell('速算扣除数（元）', header: true),
                    ],
                  ),
                  for (var i = 0; i < PayrollEngine.rates.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: selected == i
                            ? const Color(0xFFE6EEFF)
                            : i.isEven
                            ? Colors.white
                            : const Color(0xFFF5F7FA),
                      ),
                      children: [
                        cell(
                          i == 0
                              ? '不超过 ${amount(limits.first)}'
                              : i == limits.length
                              ? '超过 ${amount(limits.last)}'
                              : '超过 ${amount(limits[i - 1])}\n至 ${amount(limits[i])}（含）',
                        ),
                        cell(rateText(PayrollEngine.rates[i])),
                        cell(
                          amount(
                            (bonus
                                ? PayrollEngine.bonusQuick
                                : PayrollEngine.wageQuick)[i],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
