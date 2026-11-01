import 'calculator_inputs.dart';
import 'calculation_engine.dart';

int _savedCalculationIdSequence = 0;

class SavedCalculation {
  const SavedCalculation({
    required this.id,
    required this.savedAt,
    required this.inputs,
    required this.rulesVersion,
    required this.annualEmployerCostCents,
    required this.annualNetCashCents,
    required this.annualBenefitACents,
    required this.annualBenefitBCents,
    required this.annualTaxableIncomeCents,
    required this.annualTaxCents,
    required this.annualEmployerHousingFundCents,
    required this.annualEmployeeHousingFundCents,
  });

  factory SavedCalculation.capture({
    required CalculatorInputs inputs,
    required CalculationResult result,
    DateTime? savedAt,
  }) {
    final DateTime timestamp = savedAt ?? DateTime.now();
    return SavedCalculation(
      id: '${timestamp.microsecondsSinceEpoch}-${_savedCalculationIdSequence++}',
      savedAt: timestamp,
      inputs: inputs,
      rulesVersion: result.rulesVersion,
      annualEmployerCostCents: result.annualEmployerCostCents,
      annualNetCashCents: result.annualNetCashCents,
      annualBenefitACents: result.annualBenefitACents,
      annualBenefitBCents: result.annualBenefitBCents,
      annualTaxableIncomeCents: result.annualTaxableIncomeCents,
      annualTaxCents: result.annualTaxCents,
      annualEmployerHousingFundCents: result.annualEmployerHousingFundCents,
      annualEmployeeHousingFundCents: result.annualEmployeeHousingFundCents,
    );
  }

  final String id;
  final DateTime savedAt;
  final CalculatorInputs inputs;
  final String rulesVersion;
  final int annualEmployerCostCents;
  final int annualNetCashCents;
  final int annualBenefitACents;
  final int annualBenefitBCents;
  final int annualTaxableIncomeCents;
  final int annualTaxCents;
  final int annualEmployerHousingFundCents;
  final int annualEmployeeHousingFundCents;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'savedAt': savedAt.toIso8601String(),
      'inputs': inputs.toJson(),
      'rulesVersion': rulesVersion,
      'annualEmployerCostCents': annualEmployerCostCents,
      'annualNetCashCents': annualNetCashCents,
      'annualBenefitACents': annualBenefitACents,
      'annualBenefitBCents': annualBenefitBCents,
      'annualTaxableIncomeCents': annualTaxableIncomeCents,
      'annualTaxCents': annualTaxCents,
      'annualEmployerHousingFundCents': annualEmployerHousingFundCents,
      'annualEmployeeHousingFundCents': annualEmployeeHousingFundCents,
    };
  }

  factory SavedCalculation.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported saved calculation version');
    }
    final Object? rawInputs = json['inputs'];
    if (rawInputs is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved calculation inputs');
    }

    final String? id = json['id'] as String?;
    final String? savedAtRaw = json['savedAt'] as String?;
    final DateTime? savedAt = savedAtRaw == null
        ? null
        : DateTime.tryParse(savedAtRaw);
    final String? rulesVersion = json['rulesVersion'] as String?;
    final Map<String, int> totals = <String, int>{
      'annualEmployerCostCents': _readNonnegativeInt(
        json,
        'annualEmployerCostCents',
      ),
      'annualNetCashCents': _readNonnegativeInt(json, 'annualNetCashCents'),
      'annualBenefitACents': _readNonnegativeInt(json, 'annualBenefitACents'),
      'annualBenefitBCents': _readNonnegativeInt(json, 'annualBenefitBCents'),
      'annualTaxableIncomeCents': _readNonnegativeInt(
        json,
        'annualTaxableIncomeCents',
      ),
      'annualTaxCents': _readNonnegativeInt(json, 'annualTaxCents'),
      'annualEmployerHousingFundCents': _readNonnegativeInt(
        json,
        'annualEmployerHousingFundCents',
      ),
      'annualEmployeeHousingFundCents': _readNonnegativeInt(
        json,
        'annualEmployeeHousingFundCents',
      ),
    };

    if (id == null || savedAt == null || rulesVersion == null) {
      throw const FormatException('Invalid saved calculation metadata');
    }

    return SavedCalculation(
      id: id,
      savedAt: savedAt,
      inputs: CalculatorInputs.fromJson(rawInputs),
      rulesVersion: rulesVersion,
      annualEmployerCostCents: totals['annualEmployerCostCents']!,
      annualNetCashCents: totals['annualNetCashCents']!,
      annualBenefitACents: totals['annualBenefitACents']!,
      annualBenefitBCents: totals['annualBenefitBCents']!,
      annualTaxableIncomeCents: totals['annualTaxableIncomeCents']!,
      annualTaxCents: totals['annualTaxCents']!,
      annualEmployerHousingFundCents: totals['annualEmployerHousingFundCents']!,
      annualEmployeeHousingFundCents: totals['annualEmployeeHousingFundCents']!,
    );
  }

  static int _readNonnegativeInt(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! int || value < 0) {
      throw FormatException('Invalid saved calculation value: $key');
    }
    return value;
  }
}
