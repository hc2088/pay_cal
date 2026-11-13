import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../calculation/calculator_inputs.dart';
import '../data/city_catalog.dart';
import '../data/payroll_store.dart';
import '../domain/payroll_engine.dart';
import '../domain/payroll_models.dart';

final payrollControllerProvider = ChangeNotifierProvider<PayrollController>(
  (ref) => throw StateError('Payroll bootstrap required'),
);

class PayrollController extends ChangeNotifier {
  PayrollController({
    required this.store,
    required this.catalog,
    required this.prefs,
  });
  final PayrollStore store;
  final CityCatalog catalog;
  final SharedPreferences prefs;
  late PayrollDraft draft;
  List<PayrollPlan> plans = [];
  List<PayrollResult> results = [];
  final Map<String, PayrollDraft> _cityDrafts = {};
  final Map<PayrollResult, String> _savedResults = {};
  Future<void> _writes = Future.value();
  String? persistenceError;
  int recoveryCount = 0;
  bool busy = false;
  bool _alive = true;
  String? _calculatedInput;
  bool get resultIsStale =>
      _calculatedInput != null && _calculatedInput != draft.encode();
  PayrollDraft fresh() => PayrollDraft(
    id: newId(),
    city: catalog.beijing,
    year: DateTime.now().year,
  );
  void _notify() {
    if (_alive) notifyListeners();
  }

  Future<void> initialize() async {
    await store.migrate(prefs);
    draft = await store.loadDraft() ?? fresh();
    plans = await store.plans();
    recoveryCount = await store.quarantineCount();
    _notify();
  }

  Future<void> recoverWithFreshDraft() async {
    await store.db.transaction((txn) async {
      final old = await txn.query(
        'drafts',
        where: 'id = ?',
        whereArgs: ['active'],
      );
      if (old.isNotEmpty) {
        await txn.insert('raw_backup', {
          'id': 'draft:${newId()}',
          'body': old.single['body'],
        });
      }
    });
    draft = fresh();
    await store.saveDraft(draft);
    plans = await store.plans();
    recoveryCount = await store.quarantineCount();
    _notify();
  }

  void update(PayrollDraft next, {PayrollDraft? previousScope}) {
    draft = next;
    _notify();
    _writes = _writes
        .then((_) => store.saveDraft(next, previousScope: previousScope))
        .then((_) {
          persistenceError = null;
          _notify();
        })
        .catchError((Object error) {
          persistenceError = '草稿尚未保存到设备，请重试。当前编辑仍保留。';
          _notify();
        });
  }

  Future<void> flush() => _writes;
  void retrySave() => update(draft);
  void switchCity(CityReference city) {
    if (city.id == draft.city.id) return;
    final previous = draft;
    _cityDrafts['${previous.id}:${previous.scope}'] = previous;
    update(draft.changeCity(city), previousScope: previous);
  }

  void switchYear(int year) {
    if (year == draft.year) return;
    final previous = draft;
    _cityDrafts['${previous.id}:${previous.scope}'] = previous;
    update(
      draft.resetContributions().copyWith(year: year),
      previousScope: previous,
    );
  }

  Future<bool> restoreCityAdjustments() async {
    final scope = '${draft.id}:${draft.scope}';
    final cached = _cityDrafts[scope] ?? await store.loadDraft('scope:$scope');
    if (cached == null || '${draft.id}:${draft.scope}' != scope) return false;
    restoreContributions(cached);
    return true;
  }

  void restoreContributions(PayrollDraft old) {
    final previous = draft;
    final changedScope = previous.scope != old.scope;
    if (changedScope) {
      _cityDrafts['${previous.id}:${previous.scope}'] = previous;
    }
    update(
      draft.copyWith(
        city: old.city,
        year: old.year,
        socialBase: old.socialBase,
        housingBase: old.housingBase,
        overrides: old.overrides,
        medicalTier: old.medicalTier,
        deductible: old.deductible,
        taxableBenefit: old.taxableBenefit,
        estimateConfirmed: false,
      ),
      previousScope: changedScope ? previous : null,
    );
  }

  List<PayrollResult> calculate() {
    final calculated = PayrollEngine.calculate(draft);
    results = calculated;
    _calculatedInput = draft.encode();
    _notify();
    return calculated;
  }

  Future<void> saveResult(PayrollResult result, String name) async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      final id = _savedResults[result] ?? newId();
      await store.savePlan(result, id, name);
      _savedResults[result] = id;
      plans = await store.plans();
    } finally {
      busy = false;
      _notify();
    }
  }

  bool isSaved(PayrollResult r) =>
      _savedResults.containsKey(r) &&
      plans.any((p) => p.id == _savedResults[r]);
  Future<void> rename(String id, String name) async {
    await store.rename(id, name);
    plans = await store.plans();
    _notify();
  }

  Future<void> delete(String id) async {
    await store.deletePlan(id);
    plans = await store.plans();
    _notify();
  }

  void copyPlan(PayrollPlan p) {
    final source =
        p.result?.draft ??
        PayrollDraft.fromLegacy(
          CalculatorInputs.fromJson(objectMap(p.legacy!['inputs'])),
        );
    update(source.copyWith(id: newId(), estimateConfirmed: false));
    results = [];
    _calculatedInput = null;
    _notify();
  }

  void newBlank() {
    update(fresh());
    results = [];
    _calculatedInput = null;
    _notify();
  }

  Future<void> clearAll() async {
    await flush();
    final next = fresh();
    await store.clearAll(prefs, next);
    draft = next;
    plans = [];
    results = [];
    recoveryCount = 0;
    _calculatedInput = null;
    _savedResults.clear();
    _cityDrafts.clear();
    persistenceError = null;
    _notify();
  }

  String comparisonInput(PayrollPlan p) =>
      jsonEncode(p.result?.draft.toJson() ?? p.legacy?['inputs']);
  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }
}
