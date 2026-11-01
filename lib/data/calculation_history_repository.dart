import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../calculation/saved_calculation.dart';

class CalculationHistoryRepository {
  static const String _storageKey = 'salary_calculator.history.v1';

  Future<List<SavedCalculation>> load() async {
    late final List<String> encodedItems;
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      encodedItems = preferences.getStringList(_storageKey) ?? const <String>[];
    } catch (_) {
      return const <SavedCalculation>[];
    }
    final List<SavedCalculation> calculations = <SavedCalculation>[];

    for (final String raw in encodedItems) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          calculations.add(SavedCalculation.fromJson(decoded));
        }
      } catch (_) {
        // Ignore an invalid item while keeping the rest of the history usable.
      }
    }

    calculations.sort(
      (SavedCalculation left, SavedCalculation right) =>
          right.savedAt.compareTo(left.savedAt),
    );
    return List<SavedCalculation>.unmodifiable(calculations);
  }

  Future<void> save(List<SavedCalculation> calculations) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool stored = await preferences.setStringList(
      _storageKey,
      calculations
          .map(
            (SavedCalculation calculation) => jsonEncode(calculation.toJson()),
          )
          .toList(growable: false),
    );
    if (!stored) {
      throw StateError('Unable to persist calculation history');
    }
  }
}
