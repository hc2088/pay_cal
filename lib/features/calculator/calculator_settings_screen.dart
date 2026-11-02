import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/calculation_engine.dart';
import '../../calculation/money_format.dart';
import 'calculator_providers.dart';
import 'rule_preview_dialog.dart';

const Color _navy = Color(0xFF18324B);
const Color _teal = Color(0xFF1D9A8A);
const Color _muted = Color(0xFF718195);
const Color _line = Color(0xFFE7EDF3);

class CalculatorSettingsScreen extends ConsumerStatefulWidget {
  const CalculatorSettingsScreen({super.key});

  @override
  ConsumerState<CalculatorSettingsScreen> createState() =>
      _CalculatorSettingsScreenState();
}

class _CalculatorSettingsScreenState
    extends ConsumerState<CalculatorSettingsScreen> {
  late final TextEditingController _salary;
  late final TextEditingController _deduction;
  late final TextEditingController _socialBase;
  late final TextEditingController _housingBase;
  late final TextEditingController _housingRate;
  late final TextEditingController _workInjuryRate;
  final Map<String, String?> _errors = <String, String?>{};

  @override
  void initState() {
    super.initState();
    final CalculatorInputs inputs = ref.read(calculatorInputsProvider);
    _salary = TextEditingController(
      text: formatEditableCents(inputs.grossMonthlySalaryCents),
    );
    _deduction = TextEditingController(
      text: formatEditableCents(inputs.specialAdditionalDeductionCents),
    );
    _socialBase = TextEditingController(
      text: formatEditableCents(inputs.socialBaseCents),
    );
    _housingBase = TextEditingController(
      text: formatEditableCents(inputs.housingFundBaseCents),
    );
    _housingRate = TextEditingController(
      text: formatEditableCents(inputs.housingFundRateBps),
    );
    _workInjuryRate = TextEditingController(
      text: formatEditableCents(inputs.workInjuryRateBps),
    );
  }

  @override
  void dispose() {
    _salary.dispose();
    _deduction.dispose();
    _socialBase.dispose();
    _housingBase.dispose();
    _housingRate.dispose();
    _workInjuryRate.dispose();
    super.dispose();
  }

  void _setAmount(String key, String raw, void Function(int) onValid) {
    final int? cents = parseAmountCents(raw);
    String? error;
    if (cents == null) {
      error = raw.trim().isEmpty ? '请输入金额' : '最多输入两位小数';
    } else if (cents > maxInputCents) {
      error = '金额不能超过 999,999,999.99 元';
    }
    setState(() => _errors[key] = error);
    if (error == null && cents != null) onValid(cents);
  }

  void _setRate(String key, String raw, void Function(int) onValid) {
    final int? rate = parseRateBasisPoints(raw);
    String? error;
    if (rate == null) {
      error = raw.trim().isEmpty ? '请输入比例' : '最多输入两位小数';
    } else if (rate > 10000) {
      error = '比例需在 0%–100% 之间';
    }
    setState(() => _errors[key] = error);
    if (error == null && rate != null) onValid(rate);
  }

  void _showRule(String title, String path) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(showRulePreviewDialog(context, title: title, assetPath: path));
  }

  Future<void> _restoreDefaults() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('恢复默认参数？'),
        content: const Text('工资、扣除额、缴费比例及社保、公积金基数设置将恢复初始值。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final CalculatorInputs defaults = CalculatorInputs.defaults();
    ref.read(calculatorInputsProvider.notifier).restoreDefaults();
    _salary.text = formatEditableCents(defaults.grossMonthlySalaryCents);
    _deduction.text = formatEditableCents(
      defaults.specialAdditionalDeductionCents,
    );
    _socialBase.text = formatEditableCents(defaults.socialBaseCents);
    _housingBase.text = formatEditableCents(defaults.housingFundBaseCents);
    _housingRate.text = formatEditableCents(defaults.housingFundRateBps);
    _workInjuryRate.text = formatEditableCents(defaults.workInjuryRateBps);
    setState(_errors.clear);
  }

  void _customSocial() {
    final CalculatorInputs inputs = ref.read(calculatorInputsProvider);
    _socialBase.text = formatEditableCents(inputs.socialBaseCents);
    ref
        .read(calculatorInputsProvider.notifier)
        .setCustomSocialBase(inputs.socialBaseCents);
    setState(() => _errors.remove('social'));
  }

  void _followSalary() {
    ref.read(calculatorInputsProvider.notifier).followSalaryForSocialBase();
    setState(() => _errors.remove('social'));
  }

  void _customHousing() {
    final CalculatorInputs inputs = ref.read(calculatorInputsProvider);
    _housingBase.text = formatEditableCents(inputs.housingFundBaseCents);
    ref
        .read(calculatorInputsProvider.notifier)
        .setCustomHousingFundBase(inputs.housingFundBaseCents);
    setState(() => _errors.remove('housingBase'));
  }

  void _followSocial() {
    ref
        .read(calculatorInputsProvider.notifier)
        .followSocialBaseForHousingFund();
    setState(() => _errors.remove('housingBase'));
  }

  @override
  Widget build(BuildContext context) {
    final CalculatorInputs inputs = ref.watch(calculatorInputsProvider);
    final CalculatorInputsController settings = ref.read(
      calculatorInputsProvider.notifier,
    );
    final bool customSocial = inputs.socialBaseMode == SocialBaseMode.custom;
    final bool customHousing =
        inputs.housingFundBaseMode == HousingFundBaseMode.custom;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('测算参数'),
        actions: <Widget>[
          IconButton(
            tooltip: '恢复默认参数',
            onPressed: _restoreDefaults,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: <Widget>[
            const _IntroCard(),
            const SizedBox(height: 12),
            _SettingsCard(
              title: '本次测算参数',
              subtitle: '修改后首页结果会即时更新并自动保存',
              children: <Widget>[
                _SettingsField(
                  title: '月税前工资',
                  helper: '按固定月薪测算全年',
                  controller: _salary,
                  error: _errors['salary'],
                  prefix: '¥',
                  onChanged: (String value) =>
                      _setAmount('salary', value, settings.setSalary),
                ),
                const SizedBox(height: 10),
                _SettingsField(
                  title: '专项附加扣除',
                  helper: '按月填写，参与累计预扣应纳税所得额计算',
                  controller: _deduction,
                  error: _errors['deduction'],
                  prefix: '¥',
                  info: () => _showRule(
                    '专项附加扣除规则',
                    'doc/rules/special_additional_deductions.md',
                  ),
                  onChanged: (String value) => _setAmount(
                    'deduction',
                    value,
                    settings.setSpecialDeduction,
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsField(
                  title: '公积金比例',
                  helper: '单位和个人各缴一份',
                  controller: _housingRate,
                  error: _errors['housingRate'],
                  suffix: '%',
                  info: () =>
                      _showRule('住房公积金比例规则', 'doc/rules/housing_fund_rate.md'),
                  onChanged: (String value) => _setRate(
                    'housingRate',
                    value,
                    settings.setHousingFundRate,
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsField(
                  title: '工伤保险费率（单位承担）',
                  helper: '默认 0.2%，根据方案或当地标准调整',
                  controller: _workInjuryRate,
                  error: _errors['workInjuryRate'],
                  suffix: '%',
                  info: () =>
                      _showRule('工伤保险费率规则', 'doc/rules/work_injury_rate.md'),
                  onChanged: (String value) => _setRate(
                    'workInjuryRate',
                    value,
                    settings.setWorkInjuryRate,
                  ),
                ),
                const SizedBox(height: 10),
                _BaseSetting(
                  title: '社保缴费基数',
                  helper: '养老、医疗、失业和工伤共用',
                  currentValue: formatCents(inputs.socialBaseCents),
                  custom: customSocial,
                  followLabel: '跟随工资',
                  customLabel: '自定义',
                  onFollow: _followSalary,
                  onCustom: _customSocial,
                  customField: customSocial
                      ? _SettingsField(
                          title: '自定义社保基数',
                          helper: '首版不自动套用地区上下限',
                          controller: _socialBase,
                          error: _errors['social'],
                          prefix: '¥',
                          onChanged: (String value) => _setAmount(
                            'social',
                            value,
                            settings.setCustomSocialBase,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                _BaseSetting(
                  title: '住房公积金基数',
                  helper: '可独立于社保缴费基数设置',
                  currentValue: formatCents(inputs.housingFundBaseCents),
                  custom: customHousing,
                  followLabel: '跟随社保',
                  customLabel: '自定义',
                  onFollow: _followSocial,
                  onCustom: _customHousing,
                  customField: customHousing
                      ? _SettingsField(
                          title: '自定义公积金基数',
                          helper: '按该基数计算单位和个人缴存额',
                          controller: _housingBase,
                          error: _errors['housingBase'],
                          prefix: '¥',
                          onChanged: (String value) => _setAmount(
                            'housingBase',
                            value,
                            settings.setCustomHousingFundBase,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: '固定缴费比例',
              subtitle: '按本测算模型预设展示，不支持修改',
              children: <Widget>[
                const _RateSection(
                  title: '单位承担',
                  rows: <_RateData>[
                    _RateData('养老保险', employerPensionRateBps),
                    _RateData('医疗保险', employerMedicalRateBps),
                    _RateData('失业保险', employerUnemploymentRateBps),
                  ],
                ),
                const SizedBox(height: 12),
                const _RateSection(
                  title: '个人承担',
                  rows: <_RateData>[
                    _RateData('养老保险', employeePensionRateBps),
                    _RateData('医疗保险', employeeMedicalRateBps),
                    _RateData('失业保险', employeeUnemploymentRateBps),
                  ],
                ),
                const SizedBox(height: 9),
                const _ReadOnlyRow(
                  label: '个人大病统筹',
                  value: '¥3.00 / 月',
                  helper: '计入个人扣款，不计入综合权益',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '实际社保费率、缴费基数上下限和缴存规则以参保地政策及工资单为准。',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2FB),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.tune_rounded, color: _teal, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '在这里编辑薪资方案和缴费基数。固定社保比例与大病统筹金额会列在下方，便于核对计算口径。',
            style: TextStyle(color: _navy, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 13),
        ...children,
      ],
    ),
  );
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.title,
    required this.helper,
    required this.controller,
    required this.onChanged,
    this.error,
    this.prefix,
    this.suffix,
    this.info,
  });

  final String title;
  final String helper;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? error;
  final String? prefix;
  final String? suffix;
  final VoidCallback? info;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (info != null)
              IconButton(
                tooltip: '查看规则',
                onPressed: info,
                icon: const Icon(Icons.info_outline_rounded),
                color: _teal,
                iconSize: 18,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
              ),
          ],
        ),
        Text(helper, style: const TextStyle(color: _muted, fontSize: 10.5)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            LengthLimitingTextInputFormatter(14),
          ],
          style: const TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            prefixText: prefix,
            suffixText: suffix,
            errorText: error,
            isDense: true,
            prefixStyle: const TextStyle(color: _muted),
            suffixStyle: const TextStyle(color: _muted),
          ),
        ),
      ],
    ),
  );
}

class _BaseSetting extends StatelessWidget {
  const _BaseSetting({
    required this.title,
    required this.helper,
    required this.currentValue,
    required this.custom,
    required this.followLabel,
    required this.customLabel,
    required this.onFollow,
    required this.onCustom,
    this.customField,
  });

  final String title;
  final String helper;
  final String currentValue;
  final bool custom;
  final String followLabel;
  final String customLabel;
  final VoidCallback onFollow;
  final VoidCallback onCustom;
  final Widget? customField;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    helper,
                    style: const TextStyle(color: _muted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            _ModeButton(label: followLabel, selected: !custom, onTap: onFollow),
            const SizedBox(width: 6),
            _ModeButton(label: customLabel, selected: custom, onTap: onCustom),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          '当前基数 $currentValue',
          style: const TextStyle(
            color: _teal,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (customField != null) ...<Widget>[
          const SizedBox(height: 9),
          customField!,
        ],
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _navy : Colors.white,
        border: Border.all(color: selected ? _navy : _line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _RateSection extends StatelessWidget {
  const _RateSection({required this.title, required this.rows});

  final String title;
  final List<_RateData> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title,
        style: const TextStyle(
          color: _navy,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      for (final _RateData row in rows)
        _ReadOnlyRow(label: row.label, value: formatRate(row.rateBps)),
    ],
  );
}

class _RateData {
  const _RateData(this.label, this.rateBps);

  final String label;
  final int rateBps;
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value, this.helper});

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
              if (helper != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  helper!,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: _navy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
