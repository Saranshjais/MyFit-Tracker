import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/dates.dart';
import 'exercise.dart';

class ExerciseRepository {
  ExerciseRepository(this._db);
  final AppDatabase _db;

  Future<List<Exercise>> all({bool includeArchived = false}) async {
    final rows = await _db.db.query(
      'exercises',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> byId(int id) async {
    final rows = await _db.db.query('exercises', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Exercise.fromMap(rows.first);
  }

  Future<int> create(Exercise e) =>
      _db.db.insert('exercises', {...e.toMap(), 'is_custom': 1, 'created_at': timestampNow()});

  /// Renaming keeps the id, so plans and history stay attached.
  Future<void> update(Exercise e) => _db.db.update('exercises', e.toMap(), where: 'id = ?', whereArgs: [e.id]);

  Future<bool> isReferenced(int id) async {
    final planned = await _db.db.rawQuery('SELECT 1 FROM planned_exercises WHERE exercise_id = ? LIMIT 1', [id]);
    if (planned.isNotEmpty) return true;
    final logged = await _db.db.rawQuery('SELECT 1 FROM session_exercises WHERE exercise_id = ? LIMIT 1', [id]);
    return logged.isNotEmpty;
  }

  /// Exercises used in plans or history are archived (hidden but kept) so
  /// past sessions never lose their records. Returns true if archived.
  Future<bool> deleteOrArchive(int id) async {
    if (await isReferenced(id)) {
      await _db.db.update('exercises', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
      return true;
    }
    await _db.db.delete('exercises', where: 'id = ?', whereArgs: [id]);
    return false;
  }

  Future<void> restore(int id) => _db.db.update('exercises', {'is_archived': 0}, where: 'id = ?', whereArgs: [id]);
}

final exerciseRepositoryProvider = Provider((ref) => ExerciseRepository(ref.watch(databaseProvider)));

final exercisesProvider = FutureProvider<List<Exercise>>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(exerciseRepositoryProvider).all();
});

final exerciseProvider = FutureProvider.autoDispose.family<Exercise?, int>((ref, id) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(exerciseRepositoryProvider).byId(id);
});
