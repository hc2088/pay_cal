import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/payroll_engine.dart';
import '../../domain/payroll_models.dart';
import 'payroll_widgets.dart';

class ContributionsScreen extends StatefulWidget {
  const ContributionsScreen({super.key, required this.initial});
  final PayrollDraft initial;
  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  late PayrollDraft draft = widget.initial;
  final values = <String, Map<String, String>>{};
  final units = <String, int>{};
  static const rateFields = {'employeeRate', 'employerRate'};
  static const fields = {
    'employeeRate': '个人比例',
    'employerRate': '单位比例',
    'employeeFixed': '个人固定费用',
    'employerFixed': '单位固定费用',
    'actualBase': '本项实际基数',
    'minBase': '自定义基数下限',
    'maxBase': '自定义基数上限',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    values.clear();
    units.clear();
    for (final r in draft.effectiveItems) {
      final j = r.toJson();
      values[r.kind] = {
        for (final f in fields.keys)
          f: j[f] == null
              ? ''
              : decimalText(j[f] as int, rateFields.contains(f) ? 4 : 2),
      };
      units[r.kind] = r.roundingUnit;
    }
  }

  void _restoreField(String kind, String field) {
    final value =
        draft.city.items.firstWhere((e) => e.kind == kind).toJson()[field]
            as int?;
    setState(
      () => values[kind]![field] = value == null
          ? ''
          : decimalText(value, rateFields.contains(field) ? 4 : 2),
    );
  }

  void _restoreDefaults() {
    setState(() {
      draft = draft.resetContributions();
      _load();
    });
  }

  void _save() {
    try {
      final overrides = <String, Contribution>{};
      for (final base in draft.city.items) {
        final row = values[base.kind]!;
        int? read(String field, {bool optional = false}) {
          final raw = row[field]!;
          if (optional && raw.trim().isEmpty) return null;
          final v = parseDecimal(
            raw,
            rateFields.contains(field) ? 4 : 2,
            max: rateFields.contains(field) ? rateScale : moneyLimit,
          );
          if (v == null) {
            throw PayrollException('${base.label}：请填写有效的${fields[field]}');
          }
          return v;
        }

        // Missing reference fields may remain blank while editing other settings;
        // the engine blocks calculation until they are explicitly supplied.
        final next = Contribution(
          kind: base.kind,
          minBase: read('minBase', optional: true),
          maxBase: read('maxBase', optional: true),
          employeeRate: read('employeeRate', optional: true),
          employerRate: read('employerRate', optional: true),
          employeeFixed: read('employeeFixed')!,
          employerFixed: read('employerFixed')!,
          actualBase: read('actualBase', optional: true),
          roundingUnit: units[base.kind]!,
          defaultRateMax: base.defaultRateMax,
        );
        if (next.minBase != null &&
            next.maxBase != null &&
            next.minBase! > next.maxBase!) {
          throw PayrollException('${base.label}下限不能超过上限');
        }
        if (jsonEncode(next.toJson()) != jsonEncode(base.toJson())) {
          overrides[base.kind] = next.copyWith(overridden: true);
        }
      }
      for (final entry in {
        '社保参考基数': draft.socialBase,
        '公积金参考基数': draft.housingBase,
        '月税前扣除额': draft.deductible,
        '单位应税福利': draft.taxableBenefit,
      }.entries) {
        if (entry.value.isNotEmpty) {
          PayrollEngine.amount(entry.value, entry.key);
        }
      }
      Navigator.pop(
        context,
        draft.copyWith(overrides: overrides, estimateConfirmed: false),
      );
    } catch (e) {
      showMessage(context, e.toString());
    }
  }

  Widget _field(Contribution base, String field) {
    final original = base.toJson()[field] as int?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountField(
            key: ValueKey('contribution-${base.kind}-$field'),
            label: fields[field]!,
            labelAbove: true,
            value: values[base.kind]![field]!,
            rate: rateFields.contains(field),
            hint: field == 'actualBase' ? '留空跟随参考基数' : '待补充',
            optional: field == 'actualBase',
            onChanged: (v) => setState(() => values[base.kind]![field] = v),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '城市参考：${original == null
                      ? '未提供'
                      : rateFields.contains(field)
                      ? rateText(original)
                      : displayMoney(original)}',
                  style: const TextStyle(fontSize: 12, color: payrollMuted),
                ),
              ),
              TextButton(
                onPressed: () => _restoreField(base.kind, field),
                child: const Text('恢复', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale > 1.4;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: largeText ? kToolbarHeight * textScale : null,
        title: Text('五险一金设置', maxLines: largeText ? 2 : 1),
        actions: [
          if (largeText)
            IconButton(
              tooltip: '恢复默认',
              onPressed: _restoreDefaults,
              icon: const Icon(Icons.restore),
            )
          else
            TextButton(onPressed: _restoreDefaults, child: const Text('恢复默认')),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.all(13),
              child: Text('保存设置'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${draft.city.name} · ${draft.year}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const PolicyNotice(
            text: '按单位实际缴费调整。个人与单位比例分别保存，修改只影响当前方案；返回不保存时放弃本页编辑。',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '缴费基数',
            child: Column(
              children: [
                AmountField(
                  label: '社保参考基数',
                  labelAbove: true,
                  value: draft.socialBase,
                  hint: '留空用当前月薪估算',
                  optional: true,
                  onChanged: (v) =>
                      setState(() => draft = draft.copyWith(socialBase: v)),
                ),
                const SizedBox(height: 16),
                AmountField(
                  label: '公积金参考基数',
                  labelAbove: true,
                  value: draft.housingBase,
                  hint: '留空跟随社保参考基数',
                  optional: true,
                  onChanged: (v) =>
                      setState(() => draft = draft.copyWith(housingBase: v)),
                ),
                const SizedBox(height: 10),
                const Text(
                  '每项按自己的上下限核定。实际核定基数不一定等于当前工资。',
                  style: TextStyle(color: payrollMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (draft.city.tiers.isNotEmpty) ...[
            SectionCard(
              title: '医保档次',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: draft.city.tiers
                    .map(
                      (tier) => ChoiceChip(
                        label: Text(tier['name'] as String),
                        selected: draft.medicalTier == tier['name'],
                        onSelected: (_) => setState(() {
                          draft = draft.copyWith(medicalTier: tier['name']);
                          values['med']!['employeeRate'] = decimalText(
                            tier['employeeRatePpm'] as int,
                            4,
                          );
                          values['med']!['employerRate'] = decimalText(
                            tier['employerRatePpm'] as int,
                            4,
                          );
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final base in draft.city.items) ...[
            Card(
              child: ExpansionTile(
                key: PageStorageKey(
                  '${draft.id}-${draft.city.id}-${base.kind}',
                ),
                initiallyExpanded: !base.complete,
                title: Text(
                  base.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '个人 ${values[base.kind]!['employeeRate']!.isEmpty ? '待补充' : '${values[base.kind]!['employeeRate']}%'}  /  单位 ${values[base.kind]!['employerRate']!.isEmpty ? '待补充' : '${values[base.kind]!['employerRate']}%'}\n参考基数 ${displayMoney(base.minBase)} – ${displayMoney(base.maxBase)}',
                  style: const TextStyle(fontSize: 12, height: 1.7),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                children: [
                  if (base.kind == 'hf')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '默认预选参考上限，请按单位实际比例修改。',
                        style: TextStyle(color: payrollMuted),
                      ),
                    ),
                  _field(base, 'employeeRate'),
                  _field(base, 'employerRate'),
                  _field(base, 'actualBase'),
                  ExpansionTile(
                    key: PageStorageKey('${draft.id}-${base.kind}-advanced'),
                    title: const Text(
                      '高级：基数边界、固定费用与舍入',
                      style: TextStyle(fontSize: 14),
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 12),
                    children: [
                      _field(base, 'minBase'),
                      _field(base, 'maxBase'),
                      _field(base, 'employeeFixed'),
                      _field(base, 'employerFixed'),
                      LabeledField(
                        label: '每方每项缴费舍入',
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(
                            '${base.kind}-rounding-${units[base.kind]}',
                          ),
                          initialValue: units[base.kind],
                          isExpanded: true,
                          itemHeight: null,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('四舍五入到分')),
                            DropdownMenuItem(value: 100, child: Text('四舍五入到元')),
                          ],
                          onChanged: (v) =>
                              setState(() => units[base.kind] = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: '自定义税前扣除口径',
            child: Column(
              children: [
                const Text(
                  '默认按个人实际缴费估算扣除。若修改了基数边界或使用超范围比例，必须填写已确认的可扣除额；单位超标准应税福利也需核对。',
                  style: TextStyle(fontSize: 13, color: payrollMuted),
                ),
                const SizedBox(height: 16),
                AmountField(
                  label: '已确认月税前扣除额',
                  labelAbove: true,
                  value: draft.deductible,
                  hint: '留空按个人实际缴费',
                  optional: true,
                  onChanged: (v) =>
                      setState(() => draft = draft.copyWith(deductible: v)),
                ),
                const SizedBox(height: 16),
                AmountField(
                  label: '单位应税福利 / 月',
                  labelAbove: true,
                  value: draft.taxableBenefit,
                  onChanged: (v) =>
                      setState(() => draft = draft.copyWith(taxableBenefit: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
