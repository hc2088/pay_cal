import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../calculation/calculator_inputs.dart';
import '../calculation/saved_calculation.dart';
import '../domain/payroll_models.dart';

class PayrollStore {
  PayrollStore(this.db);
  final Database db;
  static const oldInputsKey = 'salary_calculator.inputs.v1';
  static const oldHistoryKey = 'salary_calculator.history.v1';

  static Future<PayrollStore> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final f = factory ?? databaseFactory;
    final p =
        databasePath ?? path.join(await f.getDatabasesPath(), 'payroll_v2.db');
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE drafts (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE plans (id TEXT PRIMARY KEY, name TEXT NOT NULL, saved_at TEXT NOT NULL, body TEXT NOT NULL, legacy INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE raw_backup (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE quarantine (id TEXT PRIMARY KEY, body TEXT NOT NULL, reason TEXT NOT NULL)',
          );
        },
      ),
    );
    return PayrollStore(db);
  }

  Future<void> migrate(SharedPreferences prefs) async {
    // A committed clear must finish removing the old keys even after a crash.
    if ((await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['clear_pending'],
    )).isNotEmpty) {
      await _removeLegacy(prefs);
      await db.delete('meta', where: 'key = ?', whereArgs: ['clear_pending']);
    }
    if ((await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['migration_v1'],
    )).isNotEmpty) {
      return;
    }
    final settings = prefs.getString(oldInputsKey);
    final history = prefs.getStringList(oldHistoryKey) ?? [];
    await db.transaction((txn) async {
      if (settings != null) {
        await txn.insert('raw_backup', {'id': 'settings', 'body': settings});
        PayrollDraft? draft;
        try {
          final input = CalculatorInputs.fromJson(
            objectMap(jsonDecode(settings)),
          );
          draft = PayrollDraft.fromLegacy(input);
        } catch (_) {
          await txn.insert('quarantine', {
            'id': 'settings',
            'body': settings,
            'reason': '旧版参数无法解析；原文已保留',
          });
        }
        // Storage failures must abort the whole migration, not be mistaken for
        // invalid source JSON and marked as a completed migration.
        if (draft != null) {
          await txn.insert('drafts', {
            'id': 'active',
            'body': draft.encode(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (var i = 0; i < history.length; i++) {
        final raw = history[i], backupId = 'history:$i';
        await txn.insert('raw_backup', {'id': backupId, 'body': raw});
        SavedCalculation? saved;
        try {
          final j = objectMap(jsonDecode(raw));
          saved = SavedCalculation.fromJson(j);
        } catch (_) {
          await txn.insert('quarantine', {
            'id': backupId,
            'body': raw,
            'reason': '旧版历史无法解析；原文已保留',
          });
        }
        if (saved != null) {
          await txn.insert('plans', {
            'id': 'legacy:${saved.id}:$i',
            'name': '旧版方案 ${i + 1}',
            'saved_at': saved.savedAt.toIso8601String(),
            'body': raw,
            'legacy': 1,
          });
        }
      }
      await txn.insert('meta', {'key': 'migration_v1', 'value': 'complete'});
    });
  }

  Future<PayrollDraft?> loadDraft([String id = 'active']) async {
    final rows = await db.query('drafts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      if (id == 'active' &&
          (await db.query(
            'quarantine',
            where: 'id = ?',
            whereArgs: ['settings'],
          )).isNotEmpty) {
        throw const FormatException('旧参数无法读取，已保留原文。可重试，或在备份保留的情况下新建空白方案。');
      }
      return null;
    }
    return PayrollDraft.fromJson(
      objectMap(jsonDecode(rows.single['body'] as String)),
    );
  }

  Future<void> saveDraft(PayrollDraft d, {PayrollDraft? previousScope}) =>
      db.transaction((txn) async {
        if (previousScope != null) {
          await txn.insert('drafts', {
            'id': 'scope:${previousScope.id}:${previousScope.scope}',
            'body': previousScope.encode(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.insert('drafts', {
          'id': 'active',
          'body': d.encode(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
  Future<List<PayrollPlan>> plans() async {
    final rows = await db.query('plans', orderBy: 'saved_at DESC');
    final result = <PayrollPlan>[];
    for (final row in rows) {
      try {
        final body = objectMap(jsonDecode(row['body'] as String));
        final legacy = row['legacy'] == 1;
        if (legacy) SavedCalculation.fromJson(body);
        result.add(
          PayrollPlan(
            id: row['id'] as String,
            name: row['name'] as String,
            savedAt: DateTime.parse(row['saved_at'] as String),
            result: legacy ? null : PayrollResult.fromJson(body),
            legacy: legacy ? body : null,
          ),
        );
      } catch (_) {
        await db.insert('quarantine', {
          'id': 'plan:${row['id']}',
          'body': row['body'],
          'reason': '方案快照无法解析；原文已保留',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    return List.unmodifiable(result);
  }

  Future<int> quarantineCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM quarantine'),
      ) ??
      0;
  Future<void> savePlan(PayrollResult result, String id, String name) async {
    if (name.trim().isEmpty || name.trim().length > 60) {
      throw const FormatException('名称须为 1–60 个字符');
    }
    await db.insert('plans', {
      'id': id,
      'name': name.trim(),
      'saved_at': DateTime.now().toIso8601String(),
      'body': jsonEncode(result.toJson()),
      'legacy': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty || name.trim().length > 60) {
      throw const FormatException('名称须为 1–60 个字符');
    }
    await db.update(
      'plans',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlan(String id) => db.transaction((txn) async {
    await txn.delete('plans', where: 'id = ?', whereArgs: [id]);
    await txn.delete('quarantine', where: 'id = ?', whereArgs: ['plan:$id']);
  });
  Future<void> clearAll(SharedPreferences prefs, PayrollDraft fresh) async {
    await db.transaction((txn) async {
      for (final t in ['drafts', 'plans', 'raw_backup', 'quarantine']) {
        await txn.delete(t);
      }
      await txn.insert('meta', {
        'key': 'migration_v1',
        'value': 'cleared',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('meta', {
        'key': 'clear_pending',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('drafts', {'id': 'active', 'body': fresh.encode()});
    });
    await _removeLegacy(prefs);
    await db.delete('meta', where: 'key = ?', whereArgs: ['clear_pending']);
  }

  Future<void> _removeLegacy(SharedPreferences prefs) async {
    for (final key in [oldInputsKey, oldHistoryKey]) {
      if (!await prefs.remove(key)) throw StateError('旧数据清理未完成，请重试');
    }
  }

  Future<String> exportRecovery() async => jsonEncode({
    'rawBackup': await db.query('raw_backup'),
    'quarantine': await db.query('quarantine'),
  });
}
