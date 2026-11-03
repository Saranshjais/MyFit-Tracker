import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/dates.dart';

@immutable
class WaterLog {
  const WaterLog({required this.id, required this.date, required this.loggedAt, required this.ml});
  final int id;
  final String date;
  final DateTime loggedAt;
  final double ml;

  factory WaterLog.fromMap(Map<String, Object?> m) => WaterLog(
    id: m['id'] as int,
    date: m['date'] as String,
    loggedAt: parseTimestamp(m['logged_at'] as String),
    ml: (m['quantity_ml'] as num).toDouble(),
  );
}

class WaterRepository {
  WaterRepository(this._db);
  final AppDatabase _db;

  Future<List<WaterLog>> forDate(String date) async {
    final rows = await _db.db.query('water_logs', where: 'date = ?', whereArgs: [date], orderBy: 'logged_at, id');
    return rows.map(WaterLog.fromMap).toList();
  }

  Future<int> add(String date, double ml) {
    if (ml <= 0 || ml > 5000) throw ArgumentError('Enter an amount between 1 and 5000 ml');
    return _db.db.insert('water_logs', {'date': date, 'logged_at': timestampNow(), 'quantity_ml': ml});
  }

  Future<void> delete(int id) => _db.db.delete('water_logs', where: 'id = ?', whereArgs: [id]);
}

final waterRepositoryProvider = Provider((ref) => WaterRepository(ref.watch(databaseProvider)));

final waterForDateProvider = FutureProvider.autoDispose.family<List<WaterLog>, String>((ref, date) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(waterRepositoryProvider).forDate(date);
});
