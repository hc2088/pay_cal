import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../calculation/calculator_inputs.dart';

class CalculatorSettingsRepository {
  static const String _storageKey = 'salary_calculator.inputs.v1';

  Future<CalculatorInputs> load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? raw = preferences.getString(_storageKey);
      if (raw == null) {
        return CalculatorInputs.defaults();
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return CalculatorInputs.defaults();
      }
      return CalculatorInputs.fromJson(decoded);
    } catch (_) {
      return CalculatorInputs.defaults();
    }
  }

  Future<void> save(CalculatorInputs inputs) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(inputs.toJson()));
  }
}
