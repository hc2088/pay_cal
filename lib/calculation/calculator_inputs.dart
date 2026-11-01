enum SocialBaseMode { followSalary, custom }

enum HousingFundBaseMode { followSocialBase, custom }

const int maxInputCents = 99999999999;
const int defaultWorkInjuryRateBps = 20;

class CalculatorInputs {
  const CalculatorInputs({
    required this.grossMonthlySalaryCents,
    required this.specialAdditionalDeductionCents,
    required this.socialBaseMode,
    required this.customSocialBaseCents,
    required this.housingFundBaseMode,
    required this.customHousingFundBaseCents,
    required this.housingFundRateBps,
    required this.workInjuryRateBps,
  });

  factory CalculatorInputs.defaults() {
    return const CalculatorInputs(
      grossMonthlySalaryCents: 3500000,
      specialAdditionalDeductionCents: 500000,
      socialBaseMode: SocialBaseMode.followSalary,
      customSocialBaseCents: null,
      housingFundBaseMode: HousingFundBaseMode.followSocialBase,
      customHousingFundBaseCents: null,
      housingFundRateBps: 1200,
      workInjuryRateBps: defaultWorkInjuryRateBps,
    );
  }

  final int grossMonthlySalaryCents;
  final int specialAdditionalDeductionCents;
  final SocialBaseMode socialBaseMode;
  final int? customSocialBaseCents;
  final HousingFundBaseMode housingFundBaseMode;
  final int? customHousingFundBaseCents;
  final int housingFundRateBps;
  final int workInjuryRateBps;

  int get socialBaseCents => socialBaseMode == SocialBaseMode.followSalary
      ? grossMonthlySalaryCents
      : customSocialBaseCents ?? grossMonthlySalaryCents;

  int get housingFundBaseCents =>
      housingFundBaseMode == HousingFundBaseMode.followSocialBase
      ? socialBaseCents
      : customHousingFundBaseCents ?? socialBaseCents;

  CalculatorInputs withSalary(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: value,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundBaseMode: housingFundBaseMode,
      customHousingFundBaseCents: customHousingFundBaseCents,
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
      housingFundBaseMode: housingFundBaseMode,
      customHousingFundBaseCents: customHousingFundBaseCents,
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
      housingFundBaseMode: housingFundBaseMode,
      customHousingFundBaseCents: customHousingFundBaseCents,
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
      housingFundBaseMode: housingFundBaseMode,
      customHousingFundBaseCents: customHousingFundBaseCents,
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
      housingFundBaseMode: housingFundBaseMode,
      customHousingFundBaseCents: customHousingFundBaseCents,
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
      housingFundBaseMode: housingFundBaseMode,
      customHousingFundBaseCents: customHousingFundBaseCents,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  CalculatorInputs withCustomHousingFundBase(int value) {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundBaseMode: HousingFundBaseMode.custom,
      customHousingFundBaseCents: value,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  CalculatorInputs followSocialBaseForHousingFund() {
    return CalculatorInputs(
      grossMonthlySalaryCents: grossMonthlySalaryCents,
      specialAdditionalDeductionCents: specialAdditionalDeductionCents,
      socialBaseMode: socialBaseMode,
      customSocialBaseCents: customSocialBaseCents,
      housingFundBaseMode: HousingFundBaseMode.followSocialBase,
      customHousingFundBaseCents: null,
      housingFundRateBps: housingFundRateBps,
      workInjuryRateBps: workInjuryRateBps,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 3,
      'grossMonthlySalaryCents': grossMonthlySalaryCents,
      'specialAdditionalDeductionCents': specialAdditionalDeductionCents,
      'socialBaseMode': socialBaseMode.name,
      'customSocialBaseCents': customSocialBaseCents,
      'housingFundBaseMode': housingFundBaseMode.name,
      'customHousingFundBaseCents': customHousingFundBaseCents,
      'housingFundRateBps': housingFundRateBps,
      'workInjuryRateBps': workInjuryRateBps,
    };
  }

  factory CalculatorInputs.fromJson(Map<String, dynamic> json) {
    final int schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion != 1 && schemaVersion != 2 && schemaVersion != 3) {
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
    final housingModeName = json['housingFundBaseMode'] as String?;
    final housingMode = housingModeName == 'custom'
        ? HousingFundBaseMode.custom
        : HousingFundBaseMode.followSocialBase;
    final customHousingBase = json['customHousingFundBaseCents'] as int?;

    if (!_validMoney(salary) ||
        !_validMoney(deduction) ||
        rate < 0 ||
        rate > 10000 ||
        workInjuryRate < 0 ||
        workInjuryRate > 10000 ||
        (customBase != null && !_validMoney(customBase)) ||
        (mode == SocialBaseMode.custom && customBase == null) ||
        (customHousingBase != null && !_validMoney(customHousingBase)) ||
        (housingMode == HousingFundBaseMode.custom &&
            customHousingBase == null)) {
      throw const FormatException('Invalid calculator settings');
    }

    return CalculatorInputs(
      grossMonthlySalaryCents: salary,
      specialAdditionalDeductionCents: deduction,
      socialBaseMode: mode,
      customSocialBaseCents: customBase,
      housingFundBaseMode: housingMode,
      customHousingFundBaseCents: customHousingBase,
      housingFundRateBps: rate,
      workInjuryRateBps: workInjuryRate,
    );
  }

  static bool _validMoney(int cents) => cents >= 0 && cents <= maxInputCents;
}
