enum SocialBaseMode { followSalary, custom }

const int maxInputCents = 99999999999;
const int defaultWorkInjuryRateBps = 20;

class CalculatorInputs {
  const CalculatorInputs({
    required this.grossMonthlySalaryCents,
    required this.specialAdditionalDeductionCents,
    required this.socialBaseMode,
    required this.customSocialBaseCents,
    required this.housingFundRateBps,
    required this.workInjuryRateBps,
  });

  factory CalculatorInputs.defaults() {
    return const CalculatorInputs(
      grossMonthlySalaryCents: 3300000,
      specialAdditionalDeductionCents: 500000,
      socialBaseMode: SocialBaseMode.followSalary,
      customSocialBaseCents: null,
      housingFundRateBps: 1200,
      workInjuryRateBps: defaultWorkInjuryRateBps,
    );
  }

  final int grossMonthlySalaryCents;
  final int specialAdditionalDeductionCents;
  final SocialBaseMode socialBaseMode;
  final int? customSocialBaseCents;
  final int housingFundRateBps;
  final int workInjuryRateBps;

  int get socialBaseCents => socialBaseMode == SocialBaseMode.followSalary
      ? grossMonthlySalaryCents
      : customSocialBaseCents ?? grossMonthlySalaryCents;

  CalculatorInputs withSalary(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: value,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  CalculatorInputs withSpecialDeduction(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: value,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  CalculatorInputs withHousingFundRate(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundRateBps: value,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  CalculatorInputs withWorkInjuryRate(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: value,
    );
  }

  CalculatorInputs withCustomSocialBase(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: SocialBaseMode.custom,
      customSocialBaseCents: value,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  CalculatorInputs followSalaryForSocialBase() {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: SocialBaseMode.followSalary,
      customSocialBaseCents: null,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 2,
      'grossMonthlySalaryCents': grossMonthlySalaryCents,
      'specialAdditionalDeductionCents': specialAdditionalDeductionCents,
      'socialBaseMode': socialBaseMode.name,
      'customSocialBaseCents': customSocialBaseCents,
      'housingFundRateBps': housingFundRateBps,
      'workInjuryRateBps': workInjuryRateBps,
    };
  }

  factory CalculatorInputs.fromJson(Map<String, dynamic> json) {
    final int schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException('Unsupported settings version');
    }

    final modeName = json['socialBaseMode'] as String?;
    final mode = modeName == 'custom'
        ? SocialBaseMode.custom
        : SocialBaseMode.followSalary;
    final salary = json['grossMonthlySalaryCents'] as int;
    final deduction = json['specialAdditionalDeductionCents'] as int;
    final rate = json['housingFundRateBps'] as int;
    final workInjuryRate =
        json['workInjuryRateBps'] as int? ?? defaultWorkInjuryRateBps;
    final customBase = json['customSocialBaseCents'] as int?;

    if (!_validMoney(salary) ||
        !_validMoney(deduction) ||
        rate < 0 ||
        rate > 10000 ||
        workInjuryRate < 0 ||
        workInjuryRate > 10000 ||
        (customBase != null && !_validMoney(customBase)) ||
        (mode == SocialBaseMode.custom && customBase == null)) {
      throw const FormatException('Invalid calculator settings');
    }

    return CalculatorInputs(
      grossMonthlySalaryCents: salary,
      specialAdditionalDeductionCents: deduction,
      socialBaseMode: mode,
      customSocialBaseCents: customBase,
      housingFundRateBps: rate,
      workInjuryRateBps: workInjuryRate,
    );
  }

  static bool _validMoney(int cents) => cents >= 0 && cents <= maxInputCents;
}
