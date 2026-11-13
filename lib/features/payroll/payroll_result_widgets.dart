import 'package:flutter/material.dart';
import '../../calculation/money_format.dart';
import '../../domain/payroll_breakdown.dart';
import '../../domain/payroll_models.dart';
import 'payroll_widgets.dart';

/// Keep cash and its deductions together on both the result and exported image.
class AnnualCashSummary extends StatelessWidget {
  const AnnualCashSummary({super.key, required this.result});
  final PayrollResult result;

  @override
  Widget build(BuildContext context) {
    final amounts = PayrollBreakdown(result);
    final entries = [
      (result.sum('bonus') > 0 ? '税前年薪（含奖金）' : '税前年薪', amounts.annualGross),
      ('减：年度个税', result.sum('tax')),
      ('减：个人社保', amounts.annualSocial),
      ('减：个人公积金', result.itemSum('hf', 'employee')),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF264AC2), Color(0xFF153482)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '税后年薪',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              displayMoney(result.sum('net')),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '月均 ${displayMoney(result.sum('net') ~/ 12)}${result.sum('bonus') > 0 ? ' · 含奖金摊分' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Divider(height: 24, color: Colors.white24),
          LayoutBuilder(
            builder: (context, box) {
              final columns =
                  box.maxWidth < 250 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                      entries.any((e) => e.$2.abs() >= 10000000000)
                  ? 1
                  : 2;
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i += columns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var j = i;
                            j < i + columns && j < entries.length;
                            j++
                          )
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: columns > 1 && j == i ? 12 : 0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entries[j].$1,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      displayMoney(entries[j].$2),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const Text(
            '税后年薪 = 税前年薪 − 个税 − 个人社保 − 个人公积金',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const Text(
            '个税为本年已预扣金额；不提前计入汇算退税。',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class AnnualTotalIncome extends StatelessWidget {
  const AnnualTotalIncome({
    super.key,
    required this.result,
    this.fieldPrefix = 'result',
  });
  final PayrollResult result;
  final String fieldPrefix;

  @override
  Widget build(BuildContext context) {
    final amounts = PayrollBreakdown(result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '年度总收入',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: payrollInk,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            displayMoney(amounts.annualTotalIncomeEstimate),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: payrollBlue,
            ),
          ),
        ),
        const FormulaText('由以下四项相加 · 含账户缴存估算'),
        const Divider(height: 20),
        MetricRow('税后工资（现金）', displayMoney(result.sum('net'))),
        MetricRow('公积金总额', displayMoney(result.sum('housing')), emphasis: true),
        Text(
          '个人 ${displayMoney(result.itemSum('hf', 'employee'))} + 公司 ${displayMoney(result.itemSum('hf', 'employer'))}',
          style: const TextStyle(
            fontSize: 12,
            color: payrollMuted,
            height: 1.5,
          ),
        ),
        MetricRow(
          '医疗保险个人入账',
          displayMoney(amounts.annualMedicalAccountEstimate),
          key: Key('$fieldPrefix-medical-account'),
          emphasis: true,
        ),
        MetricRow(
          '个人养老保险',
          displayMoney(amounts.annualPersonalPensionInsurance),
          emphasis: true,
        ),
        const SizedBox(height: 6),
        const FormulaText('账户缴存不属于工资现金；医保为个人比例缴费估算，不含固定附加费用，实际入账以当地规则为准。'),
      ],
    );
  }
}

class ResultExpandableCard extends StatelessWidget {
  const ResultExpandableCard({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.children,
    this.footer,
  });
  final String title, amount, subtitle;
  final List<Widget> children;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: payrollBlue,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: payrollMuted),
            ),
          ),
          children: children,
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: footer,
          ),
      ],
    ),
  );
}

class FormulaText extends StatelessWidget {
  const FormulaText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, color: payrollMuted, height: 1.65),
  );
}

class SocialContributionDetails extends StatelessWidget {
  const SocialContributionDetails({
    super.key,
    required this.month,
    this.showCompany = true,
  });
  final MonthBreakdown month;
  final bool showCompany;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in month.socialItems) ...[
        Text(
          item.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: payrollInk,
          ),
        ),
        FormulaText('当前缴费基数 ${displayMoney(item.base)}'),
        MetricRow(
          '个人缴纳',
          '${displayMoney(item.employee)} · ${rateText(item.value('employeeRate'))}',
        ),
        if (item.value('employeeFixed') != 0)
          FormulaText('含个人固定费用 ${displayMoney(item.value('employeeFixed'))}'),
        if (showCompany) ...[
          MetricRow(
            '公司缴纳',
            '${displayMoney(item.employer)} · ${rateText(item.value('employerRate'))}',
          ),
          if (item.value('employerFixed') != 0)
            FormulaText('含公司固定费用 ${displayMoney(item.value('employerFixed'))}'),
        ],
        const Divider(height: 24),
      ],
      MetricRow('个人社保合计', displayMoney(month.personalSocial), emphasis: true),
      if (showCompany) MetricRow('公司社保合计', displayMoney(month.companySocial)),
    ],
  );
}

class HousingContributionDetails extends StatelessWidget {
  const HousingContributionDetails({super.key, required this.month});
  final MonthBreakdown month;
  @override
  Widget build(BuildContext context) {
    final item = month.housing, total = item.employee + item.employer;
    String share(int amount) => total == 0
        ? '0%'
        : rateText(((amount * 10000 + total ~/ 2) ~/ total) * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormulaText('当前缴费基数 ${displayMoney(item.base)}'),
        MetricRow('个人缴纳', displayMoney(item.employee), emphasis: true),
        FormulaText(
          '缴费比例 ${rateText(item.value('employeeRate'))} · 占总额 ${share(item.employee)}',
        ),
        if (item.value('employeeFixed') != 0)
          FormulaText('含个人固定费用 ${displayMoney(item.value('employeeFixed'))}'),
        const SizedBox(height: 8),
        MetricRow('公司缴纳', displayMoney(item.employer), emphasis: true),
        FormulaText(
          '缴费比例 ${rateText(item.value('employerRate'))} · 占总额 ${share(item.employer)}',
        ),
        if (item.value('employerFixed') != 0)
          FormulaText('含公司固定费用 ${displayMoney(item.value('employerFixed'))}'),
        const SizedBox(height: 12),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.employee / total,
              minHeight: 8,
              color: payrollBlue,
              backgroundColor: const Color(0xFF83C8BF),
              semanticsLabel:
                  '个人占比 ${share(item.employee)}，公司占比 ${share(item.employer)}',
            ),
          ),
        const SizedBox(height: 8),
        FormulaText(
          '${displayMoney(item.employee)} + ${displayMoney(item.employer)} = ${displayMoney(total)}',
        ),
      ],
    );
  }
}

class CompanyCostDetails extends StatelessWidget {
  const CompanyCostDetails({super.key, required this.month});
  final MonthBreakdown month;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      MetricRow('月薪支出', displayMoney(month.value('salary'))),
      MetricRow('公司社保支出', displayMoney(month.companySocial)),
      MetricRow('公司公积金支出', displayMoney(month.housing.employer)),
      const Divider(),
      MetricRow('每月合计', displayMoney(month.regularCompanyCost), emphasis: true),
      if (month.result.sum('bonus') > 0)
        FormulaText(
          '年终奖 ${displayMoney(month.result.sum('bonus'))} 在 ${month.result.draft.bonusMonth} 月另计。',
        ),
    ],
  );
}

const monthlyCompensationNote =
    '月度总收入 = 税后工资 + 公积金（公司＋个人）+ 医保个人账户估算 + 个人养老保险。账户缴存不属于工资现金；个人养老保险不含另行自愿缴存的个人养老金。';

class MonthlyTotalIncome extends StatelessWidget {
  const MonthlyTotalIncome({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final amount = MonthlyCompensation(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricRow('月度总收入', displayMoney(amount.totalEstimate), emphasis: true),
        FormulaText(
          '（税后工资 ${displayMoney(amount.net)} + 公积金（公司＋个人）${displayMoney(amount.housing)} + 医保个人账户（估算）${displayMoney(amount.medicalAccountEstimate)} + 个人养老保险 ${displayMoney(amount.personalPensionInsurance)}）',
        ),
      ],
    );
  }
}

/// Normal-size tables match the reference; narrow screens and large text use
/// labelled rows so that neither amounts nor column labels are truncated.
class MonthIncomeTable extends StatelessWidget {
  const MonthIncomeTable({
    super.key,
    required this.months,
    required this.onMonthTap,
  });
  final List<Map<String, dynamic>> months;
  final ValueChanged<int> onMonthTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stacked =
          box.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
          months.any((m) => (m['net'] as int).abs() >= 100000000);
      Widget cells(
        String month,
        String net,
        String tax, {
        bool heading = false,
      }) => Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              month,
              style: TextStyle(color: heading ? payrollMuted : payrollInk),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              net,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: heading ? payrollMuted : payrollInk,
                fontWeight: heading ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              tax,
              textAlign: TextAlign.right,
              style: TextStyle(color: heading ? payrollMuted : payrollInk),
            ),
          ),
          const SizedBox(width: 24),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!stacked) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: cells('月份', '税后工资', '个税', heading: true),
            ),
            const Divider(height: 1),
          ],
          for (final m in months)
            Semantics(
              button: true,
              label: '${m['month']} 月详情',
              child: InkWell(
                key: ValueKey('month-income-${m['month']}'),
                onTap: () => onMonthTap(m['month'] as int),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${m['month']} 月',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      '详情',
                                      style: TextStyle(color: payrollBlue),
                                    ),
                                    const Icon(Icons.chevron_right, size: 20),
                                  ],
                                ),
                                MetricRow(
                                  '税后工资',
                                  displayMoney(m['net'] as int),
                                  emphasis: true,
                                ),
                                MetricRow('个税', displayMoney(m['tax'] as int)),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                cells(
                                  '${m['month']} 月',
                                  formatCents(
                                    m['net'] as int,
                                    withSymbol: false,
                                  ),
                                  formatCents(
                                    m['tax'] as int,
                                    withSymbol: false,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: payrollMuted,
                                ),
                              ],
                            ),
                      const SizedBox(height: 8),
                      MonthlyTotalIncome(
                        key: ValueKey('month-total-${m['month']}'),
                        data: m,
                      ),
                      const Divider(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          const FormulaText(monthlyCompensationNote),
        ],
      );
    },
  );
}
