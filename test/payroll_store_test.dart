import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pay_cal/calculation/calculator_inputs.dart';
import 'package:pay_cal/calculation/calculation_engine.dart';
import 'package:pay_cal/calculation/saved_calculation.dart';
import 'package:pay_cal/application/payroll_controller.dart';
import 'package:pay_cal/data/payroll_store.dart';
import 'package:pay_cal/data/city_catalog.dart';
import 'package:pay_cal/domain/payroll_engine.dart';
import 'fixtures/payroll_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late PayrollStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await PayrollStore.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });
  tearDown(() async {
    await store.db.close();
  });
  test(
    'national catalog loads with Beijing default, pinyin search and reference-only status',
    () async {
      final catalog = await CityCatalog.load();
      expect(catalog.cities, hasLength(337));
      expect(catalog.beijing.name, '北京');
      expect(catalog.search('shanghai').any((c) => c.name == '上海'), true);
      expect(catalog.search('bj').any((c) => c.id == 'bj'), true);
      expect(catalog.cities.every((c) => c.periods.isEmpty), true);
      expect(
        catalog.byId('sz').items.firstWhere((i) => i.kind == 'inj').minBase,
        null,
      );
    },
  );
  test(
    'migration is idempotent, preserves amounts and quarantines corrupt rows',
    () async {
      final input = CalculatorInputs.defaults(),
          saved = SavedCalculation.capture(
            inputs: CalculatorInputs.defaults(),
            result: CalculationEngine.calculate(CalculatorInputs.defaults()),
          );
      final old = saved.toJson(),
          v1 = {...old, 'schemaVersion': 1}..remove('months');
      SharedPreferences.setMockInitialValues({
        PayrollStore.oldInputsKey: jsonEncode(input.toJson()),
        PayrollStore.oldHistoryKey: [jsonEncode(old), 'broken', jsonEncode(v1)],
      });
      final prefs = await SharedPreferences.getInstance();
      await store.migrate(prefs);
      await store.migrate(prefs);
      final plans = await store.plans();
      expect(plans, hasLength(2));
      expect(plans.first.value('net'), saved.annualNetCashCents);
      expect(await store.quarantineCount(), 1);
      expect(await store.db.query('raw_backup'), hasLength(4));
      expect(SavedCalculation.fromJson(v1).months, isEmpty);
      final draft = await store.loadDraft();
      expect(draft!.city.id, 'legacy');
      expect(draft.salary, '35000');
      expect(draft.estimateConfirmed, false);
      expect(prefs.getString(PayrollStore.oldInputsKey), isNotNull);
    },
  );
  test('migration rolls back if a database write fails', () async {
    SharedPreferences.setMockInitialValues({
      PayrollStore.oldInputsKey: jsonEncode(
        CalculatorInputs.defaults().toJson(),
      ),
    });
    await store.db.execute(
      "CREATE TRIGGER fail_migration BEFORE INSERT ON meta BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      store.migrate(await SharedPreferences.getInstance()),
      throwsA(anything),
    );
    expect(await store.db.query('drafts'), isEmpty);
    expect(await store.db.query('raw_backup'), isEmpty);
    await store.db.execute('DROP TRIGGER fail_migration');
    await store.migrate(await SharedPreferences.getInstance());
    expect(await store.loadDraft(), isNotNull);
  });
  test(
    'draft insert failure rolls back rather than quarantining valid input',
    () async {
      SharedPreferences.setMockInitialValues({
        PayrollStore.oldInputsKey: jsonEncode(
          CalculatorInputs.defaults().toJson(),
        ),
      });
      await store.db.execute(
        "CREATE TRIGGER fail_draft BEFORE INSERT ON drafts BEGIN SELECT RAISE(ABORT, 'write failure'); END",
      );
      await expectLater(
        store.migrate(await SharedPreferences.getInstance()),
        throwsA(anything),
      );
      expect(await store.db.query('meta'), isEmpty);
      expect(await store.db.query('raw_backup'), isEmpty);
      expect(await store.db.query('quarantine'), isEmpty);
      await store.db.execute('DROP TRIGGER fail_draft');
      await store.migrate(await SharedPreferences.getInstance());
      expect((await store.loadDraft())!.salary, '35000');
    },
  );
  test(
    'saving twice does not duplicate and rename never recalculates snapshot',
    () async {
      final result = PayrollEngine.calculate(fixture()).single;
      await store.savePlan(result, 'same', '方案 A');
      await store.savePlan(result, 'same', '另一个名');
      expect(await store.plans(), hasLength(1));
      await store.rename('same', '新名称');
      final plan = (await store.plans()).single;
      expect(plan.name, '新名称');
      expect(plan.result!.toJson(), result.toJson());
      await store.deletePlan('same');
      expect(await store.plans(), isEmpty);
    },
  );
  test(
    'first run defaults to Beijing, city overrides isolate and warm starts restore',
    () async {
      final prefs = await SharedPreferences.getInstance(),
          catalog = await CityCatalog.load();
      final c = PayrollController(store: store, catalog: catalog, prefs: prefs);
      await c.initialize();
      expect(c.draft.city.id, 'bj');
      expect(c.draft.salary, isEmpty);
      final hf = c.draft.city.items.last;
      c.update(
        c.draft.copyWith(
          salary: '33000',
          overrides: {'hf': hf.copyWith(employeeRate: 60000)},
        ),
      );
      c.switchCity(catalog.byId('sh'));
      expect(c.draft.overrides, isEmpty);
      expect(c.draft.salary, '33000');
      expect(c.draft.effectiveItems.last.employeeRate, 70000);
      c.switchCity(catalog.beijing);
      expect(c.draft.effectiveItems.last.employeeRate, 120000);
      expect(await c.restoreCityAdjustments(), true);
      expect(c.draft.effectiveItems.last.employeeRate, 60000);
      await c.flush();
      c.dispose();
      final reopened = PayrollController(
        store: store,
        catalog: catalog,
        prefs: prefs,
      );
      await reopened.initialize();
      expect(reopened.draft.salary, '33000');
      expect(reopened.draft.effectiveItems.last.employeeRate, 60000);
      reopened.dispose();
    },
  );
  test(
    'undo city switch preserves the departing city adjustments for restart',
    () async {
      final catalog = await CityCatalog.load();
      final prefs = await SharedPreferences.getInstance();
      final c = PayrollController(store: store, catalog: catalog, prefs: prefs);
      await c.initialize();
      final beijing = c.draft;
      c.switchCity(catalog.byId('sh'));
      c.update(c.draft.copyWith(socialBase: '25000'));
      c.restoreContributions(beijing);
      await c.flush();
      c.dispose();
      final next = PayrollController(
        store: store,
        catalog: catalog,
        prefs: prefs,
      );
      await next.initialize();
      next.switchCity(catalog.byId('sh'));
      expect(await next.restoreCityAdjustments(), true);
      expect(next.draft.socialBase, '25000');
      await next.flush();
      next.dispose();
    },
  );
  test(
    'corrupt input is not silently replaced and clear-all cannot resurrect legacy data',
    () async {
      SharedPreferences.setMockInitialValues({
        PayrollStore.oldInputsKey: 'bad input',
      });
      final prefs = await SharedPreferences.getInstance();
      await store.migrate(prefs);
      await expectLater(store.loadDraft(), throwsFormatException);
      final c = PayrollController(
        store: store,
        catalog: await CityCatalog.load(),
        prefs: prefs,
      );
      await c.recoverWithFreshDraft();
      expect(c.draft.city.id, 'bj');
      expect(await store.quarantineCount(), 1);
      await c.clearAll();
      expect(prefs.getString(PayrollStore.oldInputsKey), null);
      expect(await store.db.query('raw_backup'), isEmpty);
      await store.migrate(prefs);
      expect(await store.plans(), isEmpty);
      expect((await store.loadDraft())!.city.id, 'bj');
      c.dispose();
    },
  );
}
