import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_cal/domain/payroll_models.dart';
import 'package:pay_cal/features/payroll/contributions_screen.dart';
import 'package:pay_cal/main.dart';

Future<void> openContributions(
  WidgetTester tester,
  PayrollDraft draft, {
  double textScale = 1,
  ValueChanged<PayrollDraft?>? onSaved,
}) async {
  await tester.pumpWidget(
    SalaryCalculatorApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<PayrollDraft>(
                  MaterialPageRoute(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(textScale)),
                      child: ContributionsScreen(initial: draft),
                    ),
                  ),
                );
                onSaved?.call(result);
              },
              child: const Text('打开设置'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开设置'));
  await tester.pumpAndSettle();
}
