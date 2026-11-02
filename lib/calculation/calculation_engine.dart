import 'calculator_inputs.dart';

const int basicDeductionCents = 500000;
const int criticalIllnessCents = 300;
const int employerPensionRateBps = 1600;
const int employerMedicalRateBps = 980;
const int employerUnemploymentRateBps = 50;
const int employeePensionRateBps = 800;
const int employeeMedicalRateBps = 200;
const int employeeUnemploymentRateBps = 50;

class TaxBracket {
  const TaxBracket({
    required this.upperBoundCents,
    required this.rateBps,
    required this.quickDeductionCents,
  });

  final int? upperBoundCents;
  final int rateBps;
  final int quickDeductionCents;
}

const List<TaxBracket> cumulativeTaxBrackets = <TaxBracket>[
  TaxBracket(upperBoundCents: 3600000, rateBps: 300, quickDeductionCents: 0),
  TaxBracket(
    upperBoundCents: 14400000,
    rateBps: 1000,
    quickDeductionCents: 252000,
  ),
  TaxBracket(
    upperBoundCents: 30000000,
    rateBps: 2000,
    quickDeductionCents: 1692000,
  ),
  TaxBracket(
    upperBoundCents: 42000000,
    rateBps: 2500,
    quickDeductionCents: 3192000,
  ),
  TaxBracket(
    upperBoundCents: 66000000,
    rateBps: 3000,
    quickDeductionCents: 5292000,
  ),
  TaxBracket(
    upperBoundCents: 96000000,
    rateBps: 3500,
    quickDeductionCents: 8592000,
  ),
  TaxBracket(
    upperBoundCents: null,
    rateBps: 4500,
    quickDeductionCents: 18192000,
  ),
];

class MonthlyCalculationResult {
  const MonthlyCalculationResult({
    required this.month,
    required this.salaryCents,
    required this.socialBaseCents,
    required this.employerPensionCents,
    required this.employerMedicalCents,
    required this.employerUnemploymentCents,
    required this.employerWorkInjuryCents,
    required this.employerHousingFundCents,
    required this.employeePensionCents,
    required this.employeeMedicalCents,
    required this.employeeUnemploymentCents,
    required this.employeeHousingFundCents,
    required this.criticalIllnessCents,
    required this.personalDeductionTotalCents,
    required this.taxableIncomeIncrementCents,
    required this.cumulativeTaxableIncomeCents,
    required this.taxBracketRateBps,
    required this.quickDeductionCents,
    required this.cumulativeTaxDueCents,
    required this.monthlyTaxCents,
    required this.netCashCents,
    required this.benefitACents,
    required this.benefitBCents,
    required this.employerTotalCostCents,
  });

  final int month;
  final int salaryCents;
  final int socialBaseCents;
  final int employerPensionCents;
  final int employerMedicalCents;
  final int employerUnemploymentCents;
  final int employerWorkInjuryCents;
  final int employerHousingFundCents;
  final int employeePensionCents;
  final int employeeMedicalCents;
  final int employeeUnemploymentCents;
  final int employeeHousingFundCents;
  final int criticalIllnessCents;
  final int personalDeductionTotalCents;
  final int taxableIncomeIncrementCents;
  final int cumulativeTaxableIncomeCents;
  final int taxBracketRateBps;
  final int quickDeductionCents;
  final int cumulativeTaxDueCents;
  final int monthlyTaxCents;
  final int netCashCents;
  final int benefitACents;
  final int benefitBCents;
  final int employerTotalCostCents;

  int get employerSocialTotalCents =>
      employerPensionCents +
      employerMedicalCents +
      employerUnemploymentCents +
      employerWorkInjuryCents;

  int get employeeSocialTotalCents =>
      employeePensionCents + employeeMedicalCents + employeeUnemploymentCents;

  Map<String, Object?> toJson() => <String, Object?>{
    'month': month,
    'salaryCents': salaryCents,
    'socialBaseCents': socialBaseCents,
    'employerPensionCents': employerPensionCents,
    'employerMedicalCents': employerMedicalCents,
    'employerUnemploymentCents': employerUnemploymentCents,
    'employerWorkInjuryCents': employerWorkInjuryCents,
    'employerHousingFundCents': employerHousingFundCents,
    'employeePensionCents': employeePensionCents,
    'employeeMedicalCents': employeeMedicalCents,
    'employeeUnemploymentCents': employeeUnemploymentCents,
    'employeeHousingFundCents': employeeHousingFundCents,
    'criticalIllnessCents': criticalIllnessCents,
    'personalDeductionTotalCents': personalDeductionTotalCents,
    'taxableIncomeIncrementCents': taxableIncomeIncrementCents,
    'cumulativeTaxableIncomeCents': cumulativeTaxableIncomeCents,
    'taxBracketRateBps': taxBracketRateBps,
    'quickDeductionCents': quickDeductionCents,
    'cumulativeTaxDueCents': cumulativeTaxDueCents,
    'monthlyTaxCents': monthlyTaxCents,
    'netCashCents': netCashCents,
    'benefitACents': benefitACents,
    'benefitBCents': benefitBCents,
    'employerTotalCostCents': employerTotalCostCents,
  };

  factory MonthlyCalculationResult.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final Object? value = json[key];
      if (value is! int || value < 0) {
        throw FormatException('Invalid saved monthly result value: $key');
      }
      return value;
    }

    final int month = read('month');
    final int taxBracketRateBps = read('taxBracketRateBps');
    if (month < 1 || month > 12 || taxBracketRateBps > 10000) {
      throw const FormatException('Invalid saved monthly result');
    }
    return MonthlyCalculationResult(
      month: month,
      salaryCents: read('salaryCents'),
      socialBaseCents: read('socialBaseCents'),
      employerPensionCents: read('employerPensionCents'),
      employerMedicalCents: read('employerMedicalCents'),
      employerUnemploymentCents: read('employerUnemploymentCents'),
      employerWorkInjuryCents: read('employerWorkInjuryCents'),
      employerHousingFundCents: read('employerHousingFundCents'),
      employeePensionCents: read('employeePensionCents'),
      employeeMedicalCents: read('employeeMedicalCents'),
      employeeUnemploymentCents: read('employeeUnemploymentCents'),
      employeeHousingFundCents: read('employeeHousingFundCents'),
      criticalIllnessCents: read('criticalIllnessCents'),
      personalDeductionTotalCents: read('personalDeductionTotalCents'),
      taxableIncomeIncrementCents: read('taxableIncomeIncrementCents'),
      cumulativeTaxableIncomeCents: read('cumulativeTaxableIncomeCents'),
      taxBracketRateBps: taxBracketRateBps,
      quickDeductionCents: read('quickDeductionCents'),
      cumulativeTaxDueCents: read('cumulativeTaxDueCents'),
      monthlyTaxCents: read('monthlyTaxCents'),
      netCashCents: read('netCashCents'),
      benefitACents: read('benefitACents'),
      benefitBCents: read('benefitBCents'),
      employerTotalCostCents: read('employerTotalCostCents'),
    );
  }
}

class CalculationResult {
  const CalculationResult({required this.months, required this.rulesVersion});

  final List<MonthlyCalculationResult> months;
  final String rulesVersion;

  int get annualTaxableIncomeCents =>
      months.fold(0, (sum, value) => sum + value.taxableIncomeIncrementCents);
  int get annualTaxCents =>
      months.fold(0, (sum, value) => sum + value.monthlyTaxCents);
  int get annualNetCashCents =>
      months.fold(0, (sum, value) => sum + value.netCashCents);
  int get annualBenefitACents =>
      months.fold(0, (sum, value) => sum + value.benefitACents);
  int get annualBenefitBCents =>
      months.fold(0, (sum, value) => sum + value.benefitBCents);
  int get annualEmployerCostCents =>
      months.fold(0, (sum, value) => sum + value.employerTotalCostCents);
  int get annualEmployerSocialCents =>
      months.fold(0, (sum, value) => sum + value.employerSocialTotalCents);
  int get annualEmployerHousingFundCents =>
      months.fold(0, (sum, value) => sum + value.employerHousingFundCents);
  int get annualEmployeeSocialCents =>
      months.fold(0, (sum, value) => sum + value.employeeSocialTotalCents);
  int get annualEmployeeHousingFundCents =>
      months.fold(0, (sum, value) => sum + value.employeeHousingFundCents);
  int get annualEmployeePensionCents =>
      months.fold(0, (sum, value) => sum + value.employeePensionCents);
  int get annualEmployeeMedicalCents =>
      months.fold(0, (sum, value) => sum + value.employeeMedicalCents);
  int get annualCriticalIllnessCents =>
      months.fold(0, (sum, value) => sum + value.criticalIllnessCents);
}

class CalculationEngine {
  static const String rulesVersion = 'reference-doc-v1';

  static CalculationResult calculate(CalculatorInputs inputs) {
    final List<MonthlyCalculationResult> months = <MonthlyCalculationResult>[];
    int cumulativeTaxableIncome = 0;
    int taxAlreadyWithheld = 0;
    final int socialBase = inputs.socialBaseCents;

    for (int month = 1; month <= 12; month++) {
      final int employerPension = _percentage(
        socialBase,
        employerPensionRateBps,
      );
      final int employerMedical = _percentage(
        socialBase,
        employerMedicalRateBps,
      );
      final int employerUnemployment = _percentage(
        socialBase,
        employerUnemploymentRateBps,
      );
      final int employerWorkInjury = _percentage(
        socialBase,
        inputs.workInjuryRateBps,
      );
      final int employerHousingFund = _percentage(
        inputs.housingFundBaseCents,
        inputs.housingFundRateBps,
      );

      final int employeePension = _percentage(
        socialBase,
        employeePensionRateBps,
      );
      final int employeeMedical = _percentage(
        socialBase,
        employeeMedicalRateBps,
      );
      final int employeeUnemployment = _percentage(
        socialBase,
        employeeUnemploymentRateBps,
      );
      final int employeeHousingFund = _percentage(
        inputs.housingFundBaseCents,
        inputs.housingFundRateBps,
      );

      final int personalDeductions =
          employeePension +
          employeeMedical +
          employeeUnemployment +
          employeeHousingFund +
          criticalIllnessCents;
      final int taxableIncome =
          inputs.grossMonthlySalaryCents -
          personalDeductions -
          basicDeductionCents -
          inputs.specialAdditionalDeductionCents;
      final int taxableIncrement = taxableIncome < 0 ? 0 : taxableIncome;
      cumulativeTaxableIncome += taxableIncrement;

      final TaxBracket bracket = _bracketFor(cumulativeTaxableIncome);
      final int calculatedCumulativeTax =
          _percentage(cumulativeTaxableIncome, bracket.rateBps) -
          bracket.quickDeductionCents;
      final int cumulativeTaxDue = calculatedCumulativeTax < 0
          ? 0
          : calculatedCumulativeTax;
      final int taxDifference = cumulativeTaxDue - taxAlreadyWithheld;
      final int monthlyTax = taxDifference < 0 ? 0 : taxDifference;
      taxAlreadyWithheld += monthlyTax;

      final int netCash =
          inputs.grossMonthlySalaryCents - personalDeductions - monthlyTax;
      final int employerCost =
          inputs.grossMonthlySalaryCents +
          employerPension +
          employerMedical +
          employerUnemployment +
          employerWorkInjury +
          employerHousingFund;
      final int benefitA =
          netCash + employerHousingFund + employeeHousingFund + employeeMedical;
      final int benefitB = benefitA + employeePension;

      months.add(
        MonthlyCalculationResult(
          month: month,
          salaryCents: inputs.grossMonthlySalaryCents,
          socialBaseCents: socialBase,
          employerPensionCents: employerPension,
          employerMedicalCents: employerMedical,
          employerUnemploymentCents: employerUnemployment,
          employerWorkInjuryCents: employerWorkInjury,
          employerHousingFundCents: employerHousingFund,
          employeePensionCents: employeePension,
          employeeMedicalCents: employeeMedical,
          employeeUnemploymentCents: employeeUnemployment,
          employeeHousingFundCents: employeeHousingFund,
          criticalIllnessCents: criticalIllnessCents,
          personalDeductionTotalCents: personalDeductions,
          taxableIncomeIncrementCents: taxableIncrement,
          cumulativeTaxableIncomeCents: cumulativeTaxableIncome,
          taxBracketRateBps: bracket.rateBps,
          quickDeductionCents: bracket.quickDeductionCents,
          cumulativeTaxDueCents: cumulativeTaxDue,
          monthlyTaxCents: monthlyTax,
          netCashCents: netCash,
          benefitACents: benefitA,
          benefitBCents: benefitB,
          employerTotalCostCents: employerCost,
        ),
      );
    }

    return CalculationResult(
      months: List<MonthlyCalculationResult>.unmodifiable(months),
      rulesVersion: rulesVersion,
    );
  }

  static TaxBracket _bracketFor(int taxableIncomeCents) {
    for (final TaxBracket bracket in cumulativeTaxBrackets) {
      final int? upperBound = bracket.upperBoundCents;
      if (upperBound == null || taxableIncomeCents <= upperBound) {
        return bracket;
      }
    }
    return cumulativeTaxBrackets.last;
  }

  static int _percentage(int amountCents, int rateBps) {
    return (amountCents * rateBps + 5000) ~/ 10000;
  }
}
