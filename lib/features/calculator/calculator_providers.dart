import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calculation/calculator_inputs.dart';
import '../../calculation/calculation_engine.dart';
import '../../calculation/saved_calculation.dart';
import '../../data/calculation_history_repository.dart';
import '../../data/calculator_settings_repository.dart';

final settingsRepositoryProvider = Provider<CalculatorSettingsRepository>((
  ref,
) {
  return CalculatorSettingsRepository();
});

final initialInputsProvider = Provider<CalculatorInputs>((ref) {
  return CalculatorInputs.defaults();
});

final calculationHistoryRepositoryProvider =
    Provider<CalculationHistoryRepository>((ref) {
      return CalculationHistoryRepository();
    });

final initialCalculationHistoryProvider = Provider<List<SavedCalculation>>((
  ref,
) {
  return const <SavedCalculation>[];
});

final calculationHistoryProvider =
    StateNotifierProvider<CalculationHistoryController, List<SavedCalculation>>(
      (ref) {
        return CalculationHistoryController(
          ref.watch(initialCalculationHistoryProvider),
          ref.watch(calculationHistoryRepositoryProvider),
        );
      },
    );

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
  CalculatorInputsController(CalculatorInputs initial, this._repository)
    : super(initial);

  final CalculatorSettingsRepository _repository;
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

  void setWorkInjuryRate(int basisPoints) {
    _replace(state.withWorkInjuryRate(basisPoints));
  }

  void setCustomSocialBase(int cents) {
    _replace(state.withCustomSocialBase(cents));
  }

  void followSalaryForSocialBase() {
    _replace(state.followSalaryForSocialBase());
  }

  void setCustomHousingFundBase(int cents) {
    _replace(state.withCustomHousingFundBase(cents));
  }

  void followSocialBaseForHousingFund() {
    _replace(state.followSocialBaseForHousingFund());
  }

  void restoreDefaults() {
    _replace(CalculatorInputs.defaults());
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

class CalculationHistoryController
    extends StateNotifier<List<SavedCalculation>> {
  CalculationHistoryController(List<SavedCalculation> initial, this._repository)
    : super(List<SavedCalculation>.unmodifiable(initial));

  final CalculationHistoryRepository _repository;

  Future<SavedCalculation> saveCalculation(
    CalculatorInputs inputs,
    CalculationResult result,
  ) async {
    final SavedCalculation saved = SavedCalculation.capture(
      inputs: inputs,
      result: result,
    );
    final List<SavedCalculation> previous = state;
    final List<SavedCalculation> next = List<SavedCalculation>.unmodifiable(
      <SavedCalculation>[saved, ...previous],
    );
    state = next;
    try {
      await _repository.save(next);
      return saved;
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final List<SavedCalculation> previous = state;
    final List<SavedCalculation> next = List<SavedCalculation>.unmodifiable(
      previous
          .where((SavedCalculation calculation) => calculation.id != id)
          .toList(growable: false),
    );
    state = next;
    try {
      await _repository.save(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    final List<SavedCalculation> previous = state;
    state = const <SavedCalculation>[];
    try {
      await _repository.save(state);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
