import 'package:flutter/material.dart';

import '../../calculation/calculation_engine.dart';
import '../../calculation/calculator_inputs.dart';
import '../../calculation/money_format.dart';

const Color _schemeNavy = Color(0xFF18324B);
const Color _schemeMuted = Color(0xFF718195);
const Color _schemeLine = Color(0xFFE7EDF3);

class SalarySchemePanel extends StatelessWidget {
  const SalarySchemePanel({
    required this.inputs,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final CalculatorInputs inputs;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String socialMode =
        inputs.socialBaseMode == SocialBaseMode.followSalary ? '跟随工资' : '自定义';
    final String housingMode =
        inputs.housingFundBaseMode == HousingFundBaseMode.followSocialBase
        ? '跟随社保'
        : '自定义';
    final double sidePadding = compact ? 10 : 13;
    final double verticalGap = compact ? 6 : 8;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 13 : 17),
        border: Border.all(color: _schemeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: _schemeNavy,
                        fontSize: compact ? 12 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: _schemeMuted,
                          fontSize: compact ? 8.5 : 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          SizedBox(height: verticalGap),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: sidePadding,
              vertical: compact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '月税前工资',
                    style: TextStyle(
                      color: _schemeMuted,
                      fontSize: compact ? 9 : 10.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatCents(inputs.grossMonthlySalaryCents),
                      style: TextStyle(
                        color: _schemeNavy,
                        fontSize: compact ? 14 : 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: verticalGap),
          _SchemeSettingRow(
            label: '专项附加扣除',
            value: '${formatCents(inputs.specialAdditionalDeductionCents)} / 月',
            compact: compact,
          ),
          _SchemeSettingRow(
            label: '社保缴费基数 · $socialMode',
            value: formatCents(inputs.socialBaseCents),
            compact: compact,
          ),
          _SchemeSettingRow(
            label: '公积金缴存基数 · $housingMode',
            value: formatCents(inputs.housingFundBaseCents),
            compact: compact,
          ),
          SizedBox(height: verticalGap),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: sidePadding,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _schemeLine),
            ),
            child: Column(
              children: <Widget>[
                _RateGridRow(
                  name: '缴费项目',
                  employer: '单位比例',
                  employee: '个人比例',
                  header: true,
                  compact: compact,
                ),
                _RateGridRow(
                  name: '养老保险',
                  employer: formatRate(employerPensionRateBps),
                  employee: formatRate(employeePensionRateBps),
                  compact: compact,
                ),
                _RateGridRow(
                  name: '医疗保险',
                  employer: formatRate(employerMedicalRateBps),
                  employee: formatRate(employeeMedicalRateBps),
                  compact: compact,
                ),
                _RateGridRow(
                  name: '失业保险',
                  employer: formatRate(employerUnemploymentRateBps),
                  employee: formatRate(employeeUnemploymentRateBps),
                  compact: compact,
                ),
                _RateGridRow(
                  name: '工伤保险',
                  employer: formatRate(inputs.workInjuryRateBps),
                  employee: '—',
                  compact: compact,
                ),
                _RateGridRow(
                  name: '住房公积金',
                  employer: formatRate(inputs.housingFundRateBps),
                  employee: formatRate(inputs.housingFundRateBps),
                  compact: compact,
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            '生育保险未单独列项 · 个人大病统筹固定扣款 ${formatCents(criticalIllnessCents)} / 月',
            style: TextStyle(
              color: _schemeMuted,
              fontSize: compact ? 7.5 : 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeSettingRow extends StatelessWidget {
  const _SchemeSettingRow({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: _schemeMuted, fontSize: compact ? 8.5 : 10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: _schemeNavy,
            fontSize: compact ? 8.5 : 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _RateGridRow extends StatelessWidget {
  const _RateGridRow({
    required this.name,
    required this.employer,
    required this.employee,
    required this.compact,
    this.header = false,
  });

  final String name;
  final String employer;
  final String employee;
  final bool compact;
  final bool header;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 2.3 : 3),
    child: Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Text(
            name,
            style: TextStyle(
              color: header ? _schemeMuted : _schemeNavy,
              fontSize: compact ? 8 : 9.5,
              fontWeight: header ? FontWeight.w600 : FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            employer,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: header ? _schemeMuted : _schemeNavy,
              fontSize: compact ? 8 : 9.5,
              fontWeight: header ? FontWeight.w600 : FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            employee,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: header ? _schemeMuted : _schemeNavy,
              fontSize: compact ? 8 : 9.5,
              fontWeight: header ? FontWeight.w600 : FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
