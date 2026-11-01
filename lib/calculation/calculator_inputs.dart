enum SocialBaseMode { followSalary, custom }

const int maxInputCents = 99999999999;

class CalculatorInputs {
  const CalculatorInputs({
    required this.grossMonthlySalaryCents,
    required this.specialAdditionalDeductionCents,
    required this.socialBaseMode,
    required this.customSocialBaseCents,
    required this.housingFundRateBps,
  });

  factory CalculatorInputs.defaults() {
    return const CalculatorInputs(
      grossMonthlySalaryCents: 3300000,
      specialAdditionalDeductionCents: 500000,
      socialBaseMode: SocialBaseMode.followSalary,
      customSocialBaseCents: null,
      housingFundRateBps: 1200,
    );
  }

  final int grossMonthlySalaryCents;
  final int specialAdditionalDeductionCents;
  final SocialBaseMode socialBaseMode;
  final int? customSocialBaseCents;
  final int housingFundRateBps;

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
    );
  }

  CalculatorInputs withSpecialDeduction(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: value,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundRateBps: housingFundRateBps,
    );
  }

  CalculatorInputs withHousingFundRate(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundRateBps: value,
    );
  }

  CalculatorInputs withCustomSocialBase(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: SocialBaseMode.custom,
      customSocialBaseCents: value,
      housingFundRateBps: housingFundRateBps,
    );
  }

  CalculatorInputs followSalaryForSocialBase() {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: SocialBaseMode.followSalary,
      customSocialBaseCents: null,
      housingFundRateBps: housingFundRateBps,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'grossMonthlySalaryCents': grossMonthlySalaryCents,
      'specialAdditionalDeductionCents': specialAdditionalDeductionCents,
      'socialBaseMode': socialBaseMode.name,
      'customSocialBaseCents': customSocialBaseCents,
      'housingFundRateBps': housingFundRateBps,
    };
  }

  factory CalculatorInputs.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported settings version');
    }

    final modeName = json['socialBaseMode'] as String?;
    final mode = modeName == 'custom'
        ? SocialBaseMode.custom
        : SocialBaseMode.followSalary;
    final salary = json['grossMonthlySalaryCents'] as int;
    final deduction = json['specialAdditionalDeductionCents'] as int;
    final rate = json['housingFundRateBps'] as int;
    final customBase = json['customSocialBaseCents'] as int?;

    if (!_validMoney(salary) ||
        !_validMoney(deduction) ||
        rate < 0 ||
        rate > 10000 ||
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
    );
  }

  static bool _validMoney(int cents) => cents >= 0 && cents <= maxInputCents;
}
