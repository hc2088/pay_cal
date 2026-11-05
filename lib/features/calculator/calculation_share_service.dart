import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../calculation/calculation_engine.dart';
import '../../calculation/calculator_inputs.dart';
import '../../calculation/saved_calculation.dart';
import 'income_breakdown_widgets.dart';
import 'salary_scheme_panel.dart';

const Color _shareNavy = Color(0xFF18324B);
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
                  // The app theme uses PingFang SC, which Android does not
                  // provide, so use each platform's available system family.
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
    final IncomeTotals totals = IncomeTotals.fromMonths(snapshot.months);
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
          SalarySchemePanel(
            inputs: inputs,
            title: '当前薪资方案',
            subtitle: '金额单位：元 · 展示当前缴费基数和单位、个人比例',
            compact: true,
          ),
          const SizedBox(height: 12),
          _ShareSection(
            title: '全年测算结果',
            subtitle: '按当前方案测算 12 个月 · 金额单位：元',
            child: IncomeOverviewPanel(
              totals: totals,
              annual: true,
              showHeading: false,
              compact: true,
            ),
          ),
          const SizedBox(height: 12),
          _ShareSection(
            title: '逐月收入明细',
            subtitle: '单位：元 · 税前工资、单位五险一金、单位总成本、税后总收入、扣税',
            child: MonthlyIncomeTable(
              months: snapshot.months,
              showHeading: false,
              compact: true,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            '结果为估算，请以实际工资单为准。',
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
              Text(
                '薪酬测算',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: Platform.isIOS
                      ? FontWeight.w700
                      : FontWeight.w800,
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
          style: TextStyle(
            color: _shareNavy,
            fontSize: 14,
            fontWeight: Platform.isIOS ? FontWeight.w700 : FontWeight.w800,
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
