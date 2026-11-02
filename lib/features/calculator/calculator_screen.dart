import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/calculation_engine.dart';
import '../../calculation/money_format.dart';
import '../../calculation/saved_calculation.dart';
import 'calculator_providers.dart';
import 'calculation_history_screen.dart';
import 'calculation_share_service.dart';
import 'calculator_settings_screen.dart';
import 'methodology_screen.dart';

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
                        _calculationDetails(inputs, result),
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
    final String socialMode =
        inputs.socialBaseMode == SocialBaseMode.followSalary ? '跟随工资' : '自定义';
    final String housingMode =
        inputs.housingFundBaseMode == HousingFundBaseMode.followSocialBase
        ? '跟随社保'
        : '自定义';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: _SectionTitle(
                  eyebrow: 'CURRENT SCHEME',
                  title: '当前薪资方案',
                  subtitle: '核心参数一目了然，点击可查看或调整',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('编辑'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _line),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FC),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '月税前工资',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  formatCents(inputs.grossMonthlySalaryCents),
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ParameterChip(
                      label: '专项附加扣除',
                      value:
                          '${formatCents(inputs.specialAdditionalDeductionCents)} / 月',
                    ),
                    _ParameterChip(
                      label: '公积金比例',
                      value: '${formatRate(inputs.housingFundRateBps)} · 单位/个人',
                    ),
                    _ParameterChip(
                      label: '工伤费率',
                      value: '${formatRate(inputs.workInjuryRateBps)} · 单位承担',
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                _ParameterLine(
                  label: '社保基数（$socialMode）',
                  value: formatCents(inputs.socialBaseCents),
                ),
                const SizedBox(height: 5),
                _ParameterLine(
                  label: '公积金基数（$housingMode）',
                  value: formatCents(inputs.housingFundBaseCents),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
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
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
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
      ),
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
    final int cost = _annualView
        ? result.annualEmployerCostCents
        : month.employerTotalCostCents;
    final int cash = _annualView
        ? result.annualNetCashCents
        : month.netCashCents;
    final int benefitA = _annualView
        ? result.annualBenefitACents
        : month.benefitACents;
    final int benefitB = _annualView
        ? result.annualBenefitBCents
        : month.benefitBCents;
    final int bilateralHousingFund = _annualView
        ? result.annualEmployerHousingFundCents +
              result.annualEmployeeHousingFundCents
        : month.employerHousingFundCents + month.employeeHousingFundCents;
    final int employeeMedical = _annualView
        ? result.annualEmployeeMedicalCents
        : month.employeeMedicalCents;
    final int employeePension = _annualView
        ? result.annualEmployeePensionCents
        : month.employeePensionCents;
    final int tax = _annualView ? result.annualTaxCents : month.monthlyTaxCents;
    final String taxNote = _annualView
        ? '全年应税收入  ${formatCents(result.annualTaxableIncomeCents)}'
        : '累计应税收入  ${formatCents(month.cumulativeTaxableIncomeCents)} · ${formatRate(month.taxBracketRateBps)} 档';

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
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 12;
            final double cardWidth = constraints.maxWidth >= 340
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: _annualView ? '全年单位成本' : '单位月成本',
                    value: formatCents(cost),
                    icon: Icons.apartment_rounded,
                    tone: _MetricTone.navy,
                    helper: '税前工资 + 单位缴费',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: _annualView ? '全年税后现金' : '税后现金',
                    value: formatCents(cash),
                    icon: Icons.account_balance_wallet_rounded,
                    tone: _MetricTone.teal,
                    helper: '已扣个人缴费与预扣个税',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: _annualView ? '全年综合到手' : '综合到手',
                    value: formatCents(benefitA),
                    icon: Icons.savings_rounded,
                    tone: _MetricTone.white,
                    helper: '税后现金 + 双边公积金 + 个人医保',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: _annualView ? '全年综合到手 + 养老' : '综合到手 + 养老',
                    value: formatCents(benefitB),
                    icon: Icons.trending_up_rounded,
                    tone: _MetricTone.blue,
                    helper: '综合到手 + 个人养老账户入账',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 14, 17, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DetailGroup(
                  title: '综合到手组成',
                  rows: <_DetailLine>[
                    _DetailLine(
                      _annualView ? '税后现金（全年）' : '税后现金（$_month 月）',
                      cash,
                    ),
                    _DetailLine('双边公积金入账', bilateralHousingFund),
                    _DetailLine('个人医保账户入账', employeeMedical),
                    _DetailLine('综合到手', benefitA, strong: true),
                  ],
                ),
                const SizedBox(height: 10),
                _DetailGroup(
                  title: '养老账户（仅计入“综合到手 + 养老”）',
                  rows: <_DetailLine>[
                    _DetailLine('个人养老账户入账', employeePension),
                    _DetailLine('综合到手 + 养老', benefitB, strong: true),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  '个人失业保险和大病统筹属于现金扣款，已在计算依据的个人扣款项列出，不会加进综合到手。账户入账不等于可立即支取。',
                  style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 11),
        _taxStrip(tax, _annualView ? '全年累计预扣个税' : '本月预扣个税', taxNote),
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
        ? '全年预览 · 共 12 个月，跨税档月份会标记'
        : '$_month 月预览 · ${formatRate(month.taxBracketRateBps)} 档 · 税后现金 ${formatCents(month.netCashCents)}';

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
            '月度拆解',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            preview,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          children: <Widget>[
            for (int i = 0; i < result.months.length; i++)
              _MonthRow(
                month: result.months[i],
                previous: i == 0 ? null : result.months[i - 1],
                selected: !_annualView && _month == i + 1,
                onTap: () {
                  setState(() {
                    _annualView = false;
                    _month = i + 1;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _calculationDetails(
    CalculatorInputs inputs,
    CalculationResult result,
  ) {
    final MonthlyCalculationResult month = result.months[_month - 1];
    final bool annual = _annualView;
    int amount(int annualAmount, int monthAmount) =>
        annual ? annualAmount : monthAmount;
    int sum(int Function(MonthlyCalculationResult) selector) =>
        result.months.fold<int>(0, (int total, MonthlyCalculationResult item) {
          return total + selector(item);
        });

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
            child: const Icon(Icons.functions_rounded, color: _teal, size: 19),
          ),
          title: const Text(
            '计算依据',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${annual ? '全年合计' : '$_month 月'} · 个人扣款、5,000 元基本减除、附加扣除与累计预扣税',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          children: <Widget>[
            _DetailGroup(
              title: '收入与个税',
              rows: <_DetailLine>[
                _DetailLine(
                  '税前工资',
                  amount(month.salaryCents * 12, month.salaryCents),
                ),
                _DetailLine(
                  '社保基数',
                  amount(month.socialBaseCents * 12, month.socialBaseCents),
                ),
                _DetailLine(
                  inputs.housingFundBaseMode ==
                          HousingFundBaseMode.followSocialBase
                      ? '月公积金基数 · 跟随社保'
                      : '月公积金基数 · 自定义',
                  amount(
                    inputs.housingFundBaseCents,
                    inputs.housingFundBaseCents,
                  ),
                ),
                _DetailLine(
                  '基本减除费用',
                  amount(basicDeductionCents * 12, basicDeductionCents),
                ),
                _DetailLine(
                  '专项附加扣除',
                  amount(
                    inputs.specialAdditionalDeductionCents * 12,
                    inputs.specialAdditionalDeductionCents,
                  ),
                ),
                _DetailLine(
                  '新增应纳税所得额',
                  amount(
                    result.annualTaxableIncomeCents,
                    month.taxableIncomeIncrementCents,
                  ),
                ),
                _DetailLine(
                  '累计应纳税所得额',
                  amount(
                    result.annualTaxableIncomeCents,
                    month.cumulativeTaxableIncomeCents,
                  ),
                ),
                _DetailLine(
                  '本期预扣个税',
                  amount(result.annualTaxCents, month.monthlyTaxCents),
                ),
                _DetailLine(
                  '适用预扣率',
                  null,
                  trailing: annual
                      ? '逐月累计'
                      : formatRate(month.taxBracketRateBps),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _DetailGroup(
              title: '个人扣款（已从现金扣除）',
              rows: <_DetailLine>[
                _DetailLine(
                  '个人养老保险 · ${formatRate(employeePensionRateBps)}',
                  amount(
                    result.annualEmployeePensionCents,
                    month.employeePensionCents,
                  ),
                ),
                _DetailLine(
                  '个人医疗保险 · ${formatRate(employeeMedicalRateBps)}',
                  amount(
                    result.annualEmployeeMedicalCents,
                    month.employeeMedicalCents,
                  ),
                ),
                _DetailLine(
                  '个人失业保险 · ${formatRate(employeeUnemploymentRateBps)}',
                  amount(
                    sum((m) => m.employeeUnemploymentCents),
                    month.employeeUnemploymentCents,
                  ),
                ),
                _DetailLine(
                  '个人公积金 · ${formatRate(inputs.housingFundRateBps)}',
                  amount(
                    result.annualEmployeeHousingFundCents,
                    month.employeeHousingFundCents,
                  ),
                ),
                _DetailLine(
                  '个人大病统筹（固定）',
                  amount(
                    result.annualCriticalIllnessCents,
                    month.criticalIllnessCents,
                  ),
                ),
                _DetailLine(
                  '个人扣款合计',
                  amount(
                    sum((m) => m.personalDeductionTotalCents),
                    month.personalDeductionTotalCents,
                  ),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 15),
            _DetailGroup(
              title: '单位承担',
              rows: <_DetailLine>[
                _DetailLine(
                  '单位养老保险 · ${formatRate(employerPensionRateBps)}',
                  amount(
                    sum((m) => m.employerPensionCents),
                    month.employerPensionCents,
                  ),
                ),
                _DetailLine(
                  '单位医疗保险 · ${formatRate(employerMedicalRateBps)}',
                  amount(
                    sum((m) => m.employerMedicalCents),
                    month.employerMedicalCents,
                  ),
                ),
                _DetailLine(
                  '单位失业保险 · ${formatRate(employerUnemploymentRateBps)}',
                  amount(
                    sum((m) => m.employerUnemploymentCents),
                    month.employerUnemploymentCents,
                  ),
                ),
                _DetailLine(
                  '单位工伤保险 · ${formatRate(inputs.workInjuryRateBps)}',
                  amount(
                    sum((m) => m.employerWorkInjuryCents),
                    month.employerWorkInjuryCents,
                  ),
                ),
                _DetailLine(
                  '单位公积金 · ${formatRate(inputs.housingFundRateBps)}',
                  amount(
                    result.annualEmployerHousingFundCents,
                    month.employerHousingFundCents,
                  ),
                ),
                _DetailLine(
                  '单位总成本',
                  amount(
                    result.annualEmployerCostCents,
                    month.employerTotalCostCents,
                  ),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 15),
            _DetailGroup(
              title: '综合到手组成',
              rows: <_DetailLine>[
                _DetailLine(
                  '税后现金',
                  amount(result.annualNetCashCents, month.netCashCents),
                ),
                _DetailLine(
                  '双边公积金 · 基数 ${formatCents(inputs.housingFundBaseCents)}',
                  amount(
                    result.annualEmployeeHousingFundCents +
                        result.annualEmployerHousingFundCents,
                    month.employeeHousingFundCents +
                        month.employerHousingFundCents,
                  ),
                ),
                _DetailLine(
                  '个人医保账户入账',
                  amount(
                    result.annualEmployeeMedicalCents,
                    month.employeeMedicalCents,
                  ),
                ),
                _DetailLine(
                  '综合到手',
                  amount(result.annualBenefitACents, month.benefitACents),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 15),
            _DetailGroup(
              title: '养老账户（仅计入“综合到手 + 养老”）',
              rows: <_DetailLine>[
                _DetailLine(
                  '个人养老账户入账 · 个人缴费 8%',
                  amount(
                    result.annualEmployeePensionCents,
                    month.employeePensionCents,
                  ),
                ),
                _DetailLine(
                  '综合到手 + 养老',
                  amount(result.annualBenefitBCents, month.benefitBCents),
                  strong: true,
                ),
              ],
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

class _ParameterChip extends StatelessWidget {
  const _ParameterChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(11),
    ),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10.5),
        children: <InlineSpan>[
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: _muted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _ParameterLine extends StatelessWidget {
  const _ParameterLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      ),
      Text(
        value,
        style: const TextStyle(
          color: _navy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
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

enum _MetricTone { navy, teal, white, blue }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final _MetricTone tone;
  final String helper;

  @override
  Widget build(BuildContext context) {
    Color background = Colors.white;
    Color foreground = _navy;
    Color secondary = _muted;
    if (tone == _MetricTone.navy) {
      background = _navy;
      foreground = Colors.white;
      secondary = Colors.white.withValues(alpha: 0.72);
    } else if (tone == _MetricTone.teal) {
      background = _teal;
      foreground = Colors.white;
      secondary = Colors.white.withValues(alpha: 0.75);
    } else if (tone == _MetricTone.blue) {
      background = const Color(0xFFEAF1FA);
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: tone == _MetricTone.white ? Border.all(color: _line) : null,
        boxShadow: tone == _MetricTone.navy || tone == _MetricTone.teal
            ? <BoxShadow>[
                BoxShadow(
                  color: background.withValues(alpha: 0.13),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: secondary, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondary, fontSize: 9.2),
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.previous,
    required this.selected,
    required this.onTap,
  });

  final MonthlyCalculationResult month;
  final MonthlyCalculationResult? previous;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool crossed =
        previous != null &&
        month.taxBracketRateBps > previous!.taxBracketRateBps;
    final String monthLabel = month.month.toString();
    final String rateLabel = formatRate(month.taxBracketRateBps);
    final String bracketLabel = crossed ? '跨档 $rateLabel' : '$rateLabel 档';
    final String taxLabel = formatCents(month.monthlyTaxCents);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF7F4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFFB8E2D9)
                  : const Color(0xFFF0F3F6),
            ),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 38,
                    child: Text(
                      '$monthLabel月',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: crossed
                          ? const Color(0xFFFFEED6)
                          : const Color(0xFFEAF0F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bracketLabel,
                      style: TextStyle(
                        color: crossed ? const Color(0xFF9C6419) : _muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '个税  $taxLabel',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniAmount(
                      label: '税后现金',
                      value: formatCents(month.netCashCents),
                    ),
                  ),
                  Expanded(
                    child: _MiniAmount(
                      label: '综合到手',
                      value: formatCents(month.benefitACents),
                    ),
                  ),
                  Expanded(
                    child: _MiniAmount(
                      label: '综合到手 + 养老',
                      value: formatCents(month.benefitBCents),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
        const SizedBox(height: 2),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: _navy,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.rows});

  final String title;
  final List<_DetailLine> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: _teal,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        for (final _DetailLine row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: row.strong ? _navy : _muted,
                      fontSize: 11.5,
                      fontWeight: row.strong
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (row.trailing != null) ...<Widget>[
                  Text(
                    row.trailing!,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (row.amount != null)
                  Text(
                    formatCents(row.amount!),
                    style: TextStyle(
                      color: row.strong ? _teal : _navy,
                      fontSize: 11.5,
                      fontWeight: row.strong
                          ? FontWeight.w800
                          : FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailLine {
  const _DetailLine(
    this.label,
    this.amount, {
    this.trailing,
    this.strong = false,
  });

  final String label;
  final int? amount;
  final String? trailing;
  final bool strong;
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x070D2233),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
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

Widget _taxStrip(int tax, String title, String note) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFFC58128),
            size: 17,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          formatCents(tax),
          style: const TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
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
