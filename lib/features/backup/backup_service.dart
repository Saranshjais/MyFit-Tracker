import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_info.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupCheck {
  const BackupCheck({required this.errors, required this.counts, this.exportedAt});
  final List<String> errors;
  final Map<String, int> counts;
  final DateTime? exportedAt;
  bool get isValid => errors.isEmpty;
}

/// JSON export and import of every table.
///
/// Format:
/// ```
/// { "format": "myfit-tracker-backup", "formatVersion": 1, "schemaVersion": 2,
///   "appVersion": "1.0.0", "exportedAt": "<UTC ISO-8601>",
///   "tables": { "<table>": [ { "<column>": value, ... }, ... ], ... } }
/// ```
/// Import validates the whole file first and then replaces all data inside
/// one transaction, so a failed import leaves the existing data untouched.
class BackupService {
  BackupService(this._db);
  final AppDatabase _db;

  static const format = 'myfit-tracker-backup';
  static const formatVersion = 1;

  Future<Map<String, Object?>> export() async {
    final tables = <String, Object?>{};
    for (final t in AppDatabase.tables) {
      tables[t] = await _db.db.query(t, orderBy: 'rowid');
    }
    return {
      'format': format,
      'formatVersion': formatVersion,
      'schemaVersion': AppDatabase.schemaVersion,
      'appVersion': AppInfo.version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  Future<String> exportJson() async => jsonEncode(await export());

  Future<Map<String, Set<String>>> columns() async {
    final result = <String, Set<String>>{};
    for (final t in AppDatabase.tables) {
      final info = await _db.db.rawQuery('PRAGMA table_info($t)');
      result[t] = info.map((r) => r['name'] as String).toSet();
    }
    return result;
  }

  /// Checks structure and values without touching the database.
  static BackupCheck validate(Object? decoded, Map<String, Set<String>> columns) {
    final errors = <String>[];
    final counts = <String, int>{};
    if (decoded is! Map) {
      return const BackupCheck(errors: ['This is not a MyFit Tracker backup file.'], counts: {});
    }
    if (decoded['format'] != format) errors.add('This is not a MyFit Tracker backup file.');
    final fv = decoded['formatVersion'];
    if (fv is! int || fv < 1) {
      errors.add('The backup format version is missing.');
    } else if (fv > formatVersion) {
      errors.add('This backup was made by a newer version of the app. Update the app first.');
    }
    final sv = decoded['schemaVersion'];
    if (sv is! int) {
      errors.add('The database version is missing.');
    } else if (sv > AppDatabase.schemaVersion) {
      errors.add('This backup was made by a newer version of the app. Update the app first.');
    }
    final tables = decoded['tables'];
    if (tables is! Map) {
      errors.add('The backup has no data section.');
      return BackupCheck(errors: errors, counts: counts);
    }
    for (final t in AppDatabase.tables) {
      final rows = tables[t];
      if (rows == null) {
        errors.add('Missing table "$t".');
        continue;
      }
      if (rows is! List) {
        errors.add('Table "$t" is not a list.');
        continue;
      }
      counts[t] = rows.length;
      final known = columns[t] ?? const <String>{};
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row is! Map) {
          errors.add('Row ${i + 1} of "$t" is not a record.');
          break;
        }
        if (row['id'] is! int) {
          errors.add('Row ${i + 1} of "$t" has no valid id.');
          break;
        }
        final badValue = row.entries.where(
          (e) => known.contains(e.key) && !(e.value == null || e.value is num || e.value is String || e.value is bool),
        );
        if (badValue.isNotEmpty) {
          errors.add('Row ${i + 1} of "$t" has an invalid value for "${badValue.first.key}".');
          break;
        }
      }
    }
    for (final single in ['app_settings', 'user_profile']) {
      final rows = tables[single];
      if (rows is List && rows.length != 1) errors.add('The backup must contain exactly one "$single" record.');
    }
    final exported = decoded['exportedAt'];
    return BackupCheck(
      errors: errors.toSet().toList(),
      counts: counts,
      exportedAt: exported is String ? DateTime.tryParse(exported)?.toLocal() : null,
    );
  }

  /// Replaces all data with the backup. Throws [BackupException] when the
  /// file is invalid or does not fit together; existing data is kept then.
  Future<void> import(Object? decoded) async {
    final cols = await columns();
    final check = validate(decoded, cols);
    if (!check.isValid) throw BackupException(check.errors.join('\n'));
    final tables = (decoded as Map)['tables'] as Map;
    try {
      await _db.db.transaction((txn) async {
        await AppDatabase.deleteAllRows(txn);
        for (final t in AppDatabase.tables) {
          final known = cols[t]!;
          for (final row in (tables[t] as List).cast<Map>()) {
            final values = <String, Object?>{
              for (final e in row.entries)
                if (known.contains(e.key)) e.key as String: e.value is bool ? ((e.value as bool) ? 1 : 0) : e.value,
            };
            await txn.insert(t, values, conflictAlgorithm: ConflictAlgorithm.abort);
          }
        }
        // Backups from before schema v3 have no muscle details; fill them in
        // for the bundled exercises.
        if ((decoded['schemaVersion'] as int) < 3) await AppDatabase.syncSeedExercises(txn, _db.seed);
      });
    } on DatabaseException catch (e) {
      throw BackupException(
        'The backup could not be restored because its records do not fit together. '
        'Your existing data has not been changed.\n\nDetails: ${e.toString().split('\n').first}',
      );
    }
  }
}

final backupServiceProvider = Provider((ref) => BackupService(ref.watch(databaseProvider)));
