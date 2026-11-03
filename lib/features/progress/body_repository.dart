import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';

@immutable
class WeightLog {
  const WeightLog({required this.id, required this.date, required this.weightKg, this.notes = ''});
  final int id;
  final String date;
  final double weightKg;
  final String notes;

  factory WeightLog.fromMap(Map<String, Object?> m) => WeightLog(
    id: m['id'] as int,
    date: m['date'] as String,
    weightKg: (m['weight_kg'] as num).toDouble(),
    notes: (m['notes'] as String?) ?? '',
  );
}

const measurementTypes = ['Chest', 'Waist', 'Hips', 'Arms', 'Thighs', 'Calves', 'Shoulders', 'Neck'];

@immutable
class Measurement {
  const Measurement({required this.id, required this.date, required this.type, required this.valueCm, this.notes = ''});
  final int id;
  final String date;
  final String type;

  /// Stored in centimetres; converted for display.
  final double valueCm;
  final String notes;

  factory Measurement.fromMap(Map<String, Object?> m) => Measurement(
    id: m['id'] as int,
    date: m['date'] as String,
    type: m['measurement_type'] as String,
    valueCm: (m['value_cm'] as num).toDouble(),
    notes: (m['notes'] as String?) ?? '',
  );
}

class DuplicateDateException implements Exception {
  const DuplicateDateException();
  @override
  String toString() => 'There is already a weight entry for that date. Edit that entry instead.';
}

class BodyRepository {
  BodyRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  static void _checkWeight(double kg) {
    if (kg < 20 || kg > 400) throw ArgumentError('Enter a weight between 20 and 400 kg');
  }

  /// Oldest first.
  Future<List<WeightLog>> weights() async {
    final rows = await _d.query('body_weight_logs', orderBy: 'date');
    return rows.map(WeightLog.fromMap).toList();
  }

  Future<WeightLog?> latestWeight() async {
    final rows = await _d.query('body_weight_logs', orderBy: 'date DESC', limit: 1);
    return rows.isEmpty ? null : WeightLog.fromMap(rows.first);
  }

  /// One weigh-in per date: recording again on the same date replaces it.
  Future<void> recordWeight(String date, double kg, {String notes = ''}) async {
    _checkWeight(kg);
    await _d.rawInsert(
      'INSERT INTO body_weight_logs(date, weight_kg, notes) VALUES(?, ?, ?) '
      'ON CONFLICT(date) DO UPDATE SET weight_kg = excluded.weight_kg, notes = excluded.notes',
      [date, kg, notes.trim()],
    );
  }

  Future<void> updateWeight(int id, {required String date, required double kg, String notes = ''}) async {
    _checkWeight(kg);
    final clash = await _d.query('body_weight_logs', where: 'date = ? AND id != ?', whereArgs: [date, id]);
    if (clash.isNotEmpty) throw const DuplicateDateException();
    await _d.update(
      'body_weight_logs',
      {'date': date, 'weight_kg': kg, 'notes': notes.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteWeight(int id) => _d.delete('body_weight_logs', where: 'id = ?', whereArgs: [id]);

  /// Newest first.
  Future<List<Measurement>> measurements() async {
    final rows = await _d.query('body_measurements', orderBy: 'date DESC, id DESC');
    return rows.map(Measurement.fromMap).toList();
  }

  Future<int> addMeasurement({required String date, required String type, required double valueCm, String notes = ''}) {
    if (type.trim().isEmpty) throw ArgumentError('Choose what you measured');
    if (valueCm <= 0 || valueCm > 300) throw ArgumentError('Enter a value between 0 and 300 cm');
    return _d.insert('body_measurements', {
      'date': date,
      'measurement_type': type.trim(),
      'value_cm': valueCm,
      'notes': notes.trim(),
    });
  }

  Future<void> updateMeasurement(Measurement m) {
    if (m.valueCm <= 0 || m.valueCm > 300) throw ArgumentError('Enter a value between 0 and 300 cm');
    return _d.update(
      'body_measurements',
      {'date': m.date, 'measurement_type': m.type, 'value_cm': m.valueCm, 'notes': m.notes.trim()},
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteMeasurement(int id) => _d.delete('body_measurements', where: 'id = ?', whereArgs: [id]);
}

final bodyRepositoryProvider = Provider((ref) => BodyRepository(ref.watch(databaseProvider)));

final weightLogsProvider = FutureProvider<List<WeightLog>>((ref) {
  ref.watch(bodyRevisionProvider);
  return ref.watch(bodyRepositoryProvider).weights();
});

final latestWeightProvider = FutureProvider<WeightLog?>((ref) async {
  final logs = await ref.watch(weightLogsProvider.future);
  return logs.isEmpty ? null : logs.last;
});

final measurementsProvider = FutureProvider<List<Measurement>>((ref) {
  ref.watch(bodyRevisionProvider);
  return ref.watch(bodyRepositoryProvider).measurements();
});
