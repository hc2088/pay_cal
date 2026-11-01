import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/calculation_engine.dart';
import '../../data/calculator_settings_repository.dart';

final settingsRepositoryProvider = Provider<CalculatorSettingsRepository>((
  ref,
) {
  return CalculatorSettingsRepository();
});

final initialInputsProvider = Provider<CalculatorInputs>((ref) {
  return CalculatorInputs.defaults();
});

final calculatorInputsProvider =
    StateNotifierProvider<CalculatorInputsController, CalculatorInputs>((ref) {
      return CalculatorInputsController(
        ref.watch(initialInputsProvider),
        ref.watch(settingsRepositoryProvider),
      );
    });

final calculationProvider = Provider<CalculationResult>((ref) {
  return CalculationEngine.calculate(ref.watch(calculatorInputsProvider));
});

class CalculatorInputsController extends StateNotifier<CalculatorInputs> {
  CalculatorInputsController(this._initial, this._repository) : super(_initial);

  final CalculatorSettingsRepository _repository;
  final CalculatorInputs _initial;
  Timer? _saveTimer;

  void setSalary(int cents) {
    _replace(state.withSalary(cents));
  }

  void setSpecialDeduction(int cents) {
    _replace(state.withSpecialDeduction(cents));
  }

  void setHousingFundRate(int basisPoints) {
    _replace(state.withHousingFundRate(basisPoints));
  }

  void setCustomSocialBase(int cents) {
    _replace(state.withCustomSocialBase(cents));
  }

  void followSalaryForSocialBase() {
    _replace(state.followSalaryForSocialBase());
  }

  void restoreDefaults() {
    _replace(_initial);
  }

  void _replace(CalculatorInputs next) {
    state = next;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      _persist(next);
    });
  }

  Future<void> _persist(CalculatorInputs inputs) async {
    try {
      await _repository.save(inputs);
    } catch (_) {
      // Keep the calculator usable if device storage is unavailable.
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
