import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/calculation_engine.dart';
import '../../calculation/money_format.dart';
import '../../calculation/saved_calculation.dart';
import 'calculator_providers.dart';
import 'calculation_history_screen.dart';
import 'calculation_share_service.dart';
import 'income_breakdown_widgets.dart';
import 'salary_scheme_panel.dart';
import 'calculator_settings_screen.dart';
import 'methodology_screen.dart';
import 'tax_basis_breakdown.dart';

const Color _navy = Color(0xFF18324B);
const Color _teal = Color(0xFF1D9A8A);
const Color _muted = Color(0xFF718195);
const Color _line = Color(0xFFE7EDF3);
const Color _page = Color(0xFFF3F6FA);

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  bool _annualView = true;
  int _month = 1;

  Future<void> _saveCurrentCalculation(
    CalculatorInputs inputs,
    CalculationResult result,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await ref
          .read(calculationHistoryProvider.notifier)
          .saveCalculation(inputs, result);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本次测算已保存，可在历史记录中查看。')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请检查设备存储空间后重试。')));
      }
    }
  }

  void _openCalculationHistory() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const CalculationHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CalculatorInputs inputs = ref.watch(calculatorInputsProvider);
    final CalculationResult result = ref.watch(calculationProvider);
    final List<SavedCalculation> history = ref.watch(
      calculationHistoryProvider,
    );
    return Scaffold(
      backgroundColor: _page,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = constraints.maxWidth > 900
                  ? 860
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: maxWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _header(inputs, result),
                        const SizedBox(height: 20),
                        _parameters(inputs, history.length),
                        const SizedBox(height: 22),
                        _results(inputs, result),
                        const SizedBox(height: 18),
                        _monthsCard(result),
                        const SizedBox(height: 14),
                        TaxBasisBreakdown(
                          inputs: inputs,
                          months: result.months,
                          initialMonth: _month,
                        ),
                        const SizedBox(height: 14),
                        _disclaimer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(CalculatorInputs inputs, CalculationResult result) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _navy.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '薪酬测算',
                style: TextStyle(
                  color: _navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '把工资拆成现金、成本和长期权益',
                style: TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Builder(
          builder: (BuildContext buttonContext) => IconButton(
            tooltip: '截图并分享',
            onPressed: () => shareSalarySnapshot(
              buttonContext,
              SalaryShareSnapshot.current(inputs: inputs, result: result),
            ),
            style: IconButton.styleFrom(
              foregroundColor: _teal,
              backgroundColor: Colors.white,
              side: const BorderSide(color: _line),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const MethodologyScreen(),
              ),
            );
          },
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: const Text('算法说明'),
          style: TextButton.styleFrom(
            foregroundColor: _teal,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _line),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _parameters(CalculatorInputs inputs, int historyCount) {
    return Column(
      children: <Widget>[
        SalarySchemePanel(
          inputs: inputs,
          title: '当前薪资方案',
          subtitle: '参数与结果概览、分享页保持一致',
          trailing: OutlinedButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('编辑'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _line),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 9),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _saveCurrentCalculation(
                  inputs,
                  ref.read(calculationProvider),
                ),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('保存本次'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF1F7),
                  foregroundColor: _muted,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openCalculationHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text('历史记录 $historyCount'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _line),
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openSettings() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const CalculatorSettingsScreen(),
      ),
    );
  }

  Widget _results(CalculatorInputs inputs, CalculationResult result) {
    final MonthlyCalculationResult month = result.months[_month - 1];
    final IncomeTotals totals = IncomeTotals.fromMonths(
      _annualView ? result.months : <MonthlyCalculationResult>[month],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: _SectionTitle(
                eyebrow: 'RESULTS',
                title: '结果概览',
                subtitle: '金额单位：人民币元',
              ),
            ),
            _ViewToggle(
              annual: _annualView,
              onChanged: (bool annual) => setState(() => _annualView = annual),
            ),
          ],
        ),
        if (!_annualView) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text('查看月份', style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _month,
                    items: List<DropdownMenuItem<int>>.generate(
                      12,
                      (int i) => DropdownMenuItem<int>(
                        value: i + 1,
                        child: Text('${i + 1} 月'),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value != null) setState(() => _month = value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        IncomeOverviewPanel(totals: totals, annual: _annualView),
        const SizedBox(height: 8),
        _notice(
          '税后工资 = 税前工资 − 个人缴费合计 − 个税；单位总支出 = 税前工资 + 单位五险一金；个人总权益 = 税后工资 + 双边公积金 + 个人医保入账 + 个人养老入账。',
          background: Colors.white,
          foreground: _muted,
          icon: Icons.info_outline_rounded,
        ),
        if (inputs.socialBaseMode == SocialBaseMode.custom) ...<Widget>[
          const SizedBox(height: 9),
          _notice(
            '自定义社保基数 ${formatCents(inputs.socialBaseCents)}，工资 ${formatCents(inputs.grossMonthlySalaryCents)}',
            background: const Color(0xFFFFF7E8),
            foreground: const Color(0xFF805C1E),
            icon: Icons.tune_rounded,
          ),
        ],
      ],
    );
  }

  Widget _monthsCard(CalculationResult result) {
    final MonthlyCalculationResult month = result.months[_month - 1];
    final String preview = _annualView
        ? '全年 12 个月 · 按月查看工资、缴费、个税与账户入账'
        : '$_month 月 · 税后工资 ${formatCents(month.netCashCents)} · ${formatRate(month.taxBracketRateBps)} 档';

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(17, 0, 17, 17),
          leading: Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: _teal,
              size: 19,
            ),
          ),
          title: const Text(
            '逐月收益明细',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            preview,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          children: <Widget>[
            MonthlyIncomeTable(
              months: result.months,
              selectedMonth: _annualView ? null : _month,
              showHeading: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _disclaimer() {
    return _notice(
      '以上为测算结果，不等同于正式工资单。地区费率、缴费上下限及年度汇算可能造成差异；个人养老账户和公积金的使用受相关政策限制。',
      background: const Color(0xFFEFF3F7),
      foreground: _muted,
      icon: Icons.info_outline_rounded,
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.annual, required this.onChanged});

  final bool annual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ToggleItem(
            label: '全年',
            selected: annual,
            onTap: () => onChanged(true),
          ),
          _ToggleItem(
            label: '月度',
            selected: !annual,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _navy : _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: const TextStyle(
            color: _teal,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10.5)),
      ],
    );
  }
}

Widget _notice(
  String text, {
  required Color background,
  required Color foreground,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: foreground, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: foreground, fontSize: 11, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
