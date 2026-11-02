import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../calculation/calculation_engine.dart';
import '../../calculation/calculator_inputs.dart';
import '../../calculation/money_format.dart';
import '../../calculation/saved_calculation.dart';

const Color _shareNavy = Color(0xFF18324B);
const Color _shareTeal = Color(0xFF1D9A8A);
const Color _shareMuted = Color(0xFF718195);
const Color _shareLine = Color(0xFFE7EDF3);
const Color _sharePage = Color(0xFFF3F6FA);

bool _isCapturingShareImage = false;

class SalaryShareSnapshot {
  const SalaryShareSnapshot({
    required this.inputs,
    required this.months,
    required this.annualEmployerCostCents,
    required this.annualNetCashCents,
    required this.annualBenefitACents,
    required this.annualBenefitBCents,
    required this.annualTaxableIncomeCents,
    required this.annualTaxCents,
    required this.rulesVersion,
    required this.isSavedSnapshot,
    this.savedAt,
  });

  factory SalaryShareSnapshot.current({
    required CalculatorInputs inputs,
    required CalculationResult result,
  }) => SalaryShareSnapshot(
    inputs: inputs,
    months: result.months,
    annualEmployerCostCents: result.annualEmployerCostCents,
    annualNetCashCents: result.annualNetCashCents,
    annualBenefitACents: result.annualBenefitACents,
    annualBenefitBCents: result.annualBenefitBCents,
    annualTaxableIncomeCents: result.annualTaxableIncomeCents,
    annualTaxCents: result.annualTaxCents,
    rulesVersion: result.rulesVersion,
    isSavedSnapshot: false,
  );

  factory SalaryShareSnapshot.saved(SavedCalculation calculation) =>
      SalaryShareSnapshot(
        inputs: calculation.inputs,
        months: calculation.months,
        annualEmployerCostCents: calculation.annualEmployerCostCents,
        annualNetCashCents: calculation.annualNetCashCents,
        annualBenefitACents: calculation.annualBenefitACents,
        annualBenefitBCents: calculation.annualBenefitBCents,
        annualTaxableIncomeCents: calculation.annualTaxableIncomeCents,
        annualTaxCents: calculation.annualTaxCents,
        rulesVersion: calculation.rulesVersion,
        isSavedSnapshot: true,
        savedAt: calculation.savedAt,
      );

  final CalculatorInputs inputs;
  final List<MonthlyCalculationResult> months;
  final int annualEmployerCostCents;
  final int annualNetCashCents;
  final int annualBenefitACents;
  final int annualBenefitBCents;
  final int annualTaxableIncomeCents;
  final int annualTaxCents;
  final String rulesVersion;
  final bool isSavedSnapshot;
  final DateTime? savedAt;

  int get annualPersonalDeductionsCents => months.fold<int>(
    0,
    (int total, MonthlyCalculationResult month) =>
        total + month.personalDeductionTotalCents,
  );
}

Future<void> shareSalarySnapshot(
  BuildContext context,
  SalaryShareSnapshot snapshot,
) async {
  if (_isCapturingShareImage) {
    return;
  }
  _isCapturingShareImage = true;
  FocusManager.instance.primaryFocus?.unfocus();

  try {
    // Keep the exported card within the device's usable width. The old fixed
    // 420px card could be wider than the capture surface on smaller phones.
    final double cardWidth = math.min(
      420,
      MediaQuery.sizeOf(context).width - 24,
    );
    final Uint8List imageBytes = await ScreenshotController()
        .captureFromLongWidget(
          InheritedTheme.captureAll(
            context,
            Directionality(
              textDirection: Directionality.of(context),
              child: Material(
                color: _sharePage,
                child: DefaultTextStyle.merge(
                  // The app theme names PingFang SC globally, which Android
                  // does not provide. Give the detached capture tree a native
                  // font family so complex bold CJK glyphs use one fallback.
                  style: TextStyle(
                    fontFamily: Platform.isIOS ? 'PingFang SC' : 'sans-serif',
                  ),
                  child: _SalaryShareCard(snapshot: snapshot, width: cardWidth),
                ),
              ),
            ),
          ),
          context: context,
          delay: const Duration(milliseconds: 250),
          pixelRatio: 2,
          // Keep the render surface and the card on the same exact width.
          constraints: BoxConstraints.tightFor(width: cardWidth),
        );
    if (imageBytes.isEmpty) {
      throw StateError('Screenshot image was empty');
    }

    final File imageFile = File(
      '${Directory.systemTemp.path}/pay_cal_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await imageFile.writeAsBytes(imageBytes, flush: true);

    final RenderObject? renderObject = context.mounted
        ? context.findRenderObject()
        : null;
    final Rect? sharePositionOrigin =
        renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;

    try {
      await Share.shareXFiles(<XFile>[
        XFile(imageFile.path, mimeType: 'image/png'),
      ], sharePositionOrigin: sharePositionOrigin);
    } catch (_) {
      if (!Platform.isAndroid) {
        rethrow;
      }
      final bool hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        throw StateError('Gallery permission was denied');
      }
      await Gal.putImage(imageFile.path, album: '薪酬测算');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('系统分享暂不可用，截图已保存到相册。')));
      }
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('截图生成或分享失败，请稍后重试。')));
    }
  } finally {
    _isCapturingShareImage = false;
  }
}

class _SalaryShareCard extends StatelessWidget {
  const _SalaryShareCard({required this.snapshot, required this.width});

  final SalaryShareSnapshot snapshot;
  final double width;

  @override
  Widget build(BuildContext context) {
    final CalculatorInputs inputs = snapshot.inputs;
    final bool customSocialBase =
        inputs.socialBaseMode == SocialBaseMode.custom;
    final bool customHousingBase =
        inputs.housingFundBaseMode == HousingFundBaseMode.custom;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      color: _sharePage,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _brandHeader(snapshot),
          const SizedBox(height: 15),
          _ShareSection(
            title: '当前薪资方案',
            subtitle: '保留影响测算结果的主要参数',
            child: Column(
              children: <Widget>[
                _ShareKeyValue(
                  '月税前工资',
                  formatCents(inputs.grossMonthlySalaryCents),
                  emphasized: true,
                ),
                _ShareKeyValue(
                  '专项附加扣除',
                  '${formatCents(inputs.specialAdditionalDeductionCents)} / 月',
                ),
                _ShareKeyValue(
                  '社保缴费基数',
                  '${customSocialBase ? '自定义' : '跟随工资'} · ${formatCents(inputs.socialBaseCents)}',
                ),
                _ShareKeyValue(
                  '住房公积金基数',
                  '${customHousingBase ? '自定义' : '跟随社保'} · ${formatCents(inputs.housingFundBaseCents)}',
                ),
                _ShareKeyValue(
                  '公积金比例（单位/个人）',
                  formatRate(inputs.housingFundRateBps),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ShareSection(
            title: '全年测算结果',
            subtitle: '按当前方案测算 12 个月',
            child: Column(
              children: <Widget>[
                _ShareMetricRow(
                  first: _MetricData(
                    '全年单位成本',
                    snapshot.annualEmployerCostCents,
                    tone: _MetricColor.navy,
                  ),
                  second: _MetricData(
                    '全年税后工资',
                    snapshot.annualNetCashCents,
                    tone: _MetricColor.teal,
                  ),
                ),
                const SizedBox(height: 8),
                _ShareMetricRow(
                  first: _MetricData('全年综合到手', snapshot.annualBenefitACents),
                  second: _MetricData(
                    '综合到手 + 养老',
                    snapshot.annualBenefitBCents,
                  ),
                ),
                const SizedBox(height: 7),
                _ShareKeyValue('全年预扣个税', formatCents(snapshot.annualTaxCents)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ShareSection(
            title: '逐月收入明细',
            subtitle: '单位：元 · 税前工资、个人扣款、个税与税后工资',
            child: _ShareMonthlyTable(months: snapshot.months),
          ),
          const SizedBox(height: 9),
          const Text(
            '综合到手含税后工资、双边公积金和个人医保账户入账。结果为估算，请以实际工资单为准。',
            style: TextStyle(color: _shareMuted, fontSize: 8.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader(SalaryShareSnapshot snapshot) {
    final String label = snapshot.isSavedSnapshot ? '历史测算快照' : '当前测算方案';
    final DateTime? savedAt = snapshot.savedAt;
    final String? savedTimestamp = savedAt == null
        ? null
        : '${savedAt.year}-${savedAt.month.toString().padLeft(2, '0')}-${savedAt.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _shareNavy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '薪酬测算',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                savedTimestamp == null ? label : '$label · $savedTimestamp',
                style: const TextStyle(color: Color(0xFFD0DCE7), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareSection extends StatelessWidget {
  const _ShareSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _shareLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: _shareNavy,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: _shareMuted, fontSize: 10),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _ShareKeyValue extends StatelessWidget {
  const _ShareKeyValue(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: <Widget>[
        Expanded(
          flex: 44,
          child: Text(
            label,
            style: TextStyle(
              color: emphasized ? _shareNavy : _shareMuted,
              fontSize: emphasized ? 12 : 10.5,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 56,
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: TextStyle(
              color: emphasized ? _shareTeal : _shareNavy,
              fontSize: emphasized ? 14 : 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricData {
  const _MetricData(
    this.label,
    this.amountCents, {
    this.tone = _MetricColor.navy,
  });

  final String label;
  final int amountCents;
  final _MetricColor tone;
}

enum _MetricColor { navy, teal }

class _ShareMetricRow extends StatelessWidget {
  const _ShareMetricRow({required this.first, required this.second});

  final _MetricData first;
  final _MetricData second;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: _ShareMetric(data: first)),
      const SizedBox(width: 10),
      Expanded(child: _ShareMetric(data: second)),
    ],
  );
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final Color color = data.tone == _MetricColor.teal
        ? _shareTeal
        : _shareNavy;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: data.tone == _MetricColor.navy
            ? const Color(0xFFF4F7FA)
            : const Color(0xFFF0FAF8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.label,
            maxLines: 2,
            softWrap: true,
            style: const TextStyle(color: _shareMuted, fontSize: 9),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCents(data.amountCents),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareMonthlyTable extends StatelessWidget {
  const _ShareMonthlyTable({required this.months});

  final List<MonthlyCalculationResult> months;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _row(
        month: '月',
        salary: '税前',
        deductions: '个人扣款',
        tax: '个税',
        netCash: '税后工资',
        isHeader: true,
      ),
      for (int index = 0; index < months.length; index++)
        _row(
          month: '${months[index].month.toString().padLeft(2, '0')}月',
          salary: formatCents(months[index].salaryCents, withSymbol: false),
          deductions: formatCents(
            months[index].personalDeductionTotalCents,
            withSymbol: false,
          ),
          tax: formatCents(months[index].monthlyTaxCents, withSymbol: false),
          netCash: formatCents(months[index].netCashCents, withSymbol: false),
          isAlternate: index.isOdd,
        ),
    ],
  );

  Widget _row({
    required String month,
    required String salary,
    required String deductions,
    required String tax,
    required String netCash,
    bool isHeader = false,
    bool isAlternate = false,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    decoration: BoxDecoration(
      color: isHeader
          ? const Color(0xFFEAF1F7)
          : isAlternate
          ? const Color(0xFFF6F8FB)
          : Colors.white,
      borderRadius: isHeader ? BorderRadius.circular(7) : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _cell(month, flex: 10, isHeader: isHeader, alignStart: true),
        _cell(salary, flex: 21, isHeader: isHeader),
        _cell(deductions, flex: 24, isHeader: isHeader),
        _cell(tax, flex: 17, isHeader: isHeader),
        _cell(netCash, flex: 28, isHeader: isHeader),
      ],
    ),
  );

  Widget _cell(
    String value, {
    required int flex,
    required bool isHeader,
    bool alignStart = false,
  }) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        value,
        textAlign: alignStart ? TextAlign.start : TextAlign.end,
        softWrap: true,
        style: TextStyle(
          color: isHeader ? _shareMuted : _shareNavy,
          fontSize: isHeader ? 8 : 8.5,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
          height: 1.15,
        ),
      ),
    ),
  );
}
