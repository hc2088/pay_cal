import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calculation/calculator_inputs.dart';
import 'data/calculator_settings_repository.dart';
import 'features/calculator/calculator_providers.dart';
import 'features/calculator/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final CalculatorSettingsRepository repository =
      CalculatorSettingsRepository();
  final CalculatorInputs initialInputs = await repository.load();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        initialInputsProvider.overrideWithValue(initialInputs),
      ],
      child: const SalaryCalculatorApp(),
    ),
  );
}

class SalaryCalculatorApp extends StatelessWidget {
  const SalaryCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF18324B);
    const Color teal = Color(0xFF1D9A8A);

    return MaterialApp(
      title: '薪酬测算',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F6FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: navy,
          secondary: teal,
          surface: Colors.white,
        ),
        fontFamily: 'PingFang SC',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: navy,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(color: navy, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: navy, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: Color(0xFF4A5D70), height: 1.45),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4EAF0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4EAF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: teal, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD45151)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD45151), width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE7EDF3)),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerColor: const Color(0xFFE8EDF2),
      ),
      home: const CalculatorScreen(),
    );
  }
}
