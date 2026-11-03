import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import '../exercises/exercise.dart';
import 'models.dart';
import 'workout_calculations.dart';

class SessionRepository {
  SessionRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  // ---------------------------------------------------------------------------
  // Reading

  Future<WorkoutSession?> activeSession() async {
    final rows = await _d.query(
      'workout_sessions',
      columns: ['id'],
      where: "status = 'in_progress'",
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return byId(rows.first['id'] as int);
  }

  Future<WorkoutSession?> byId(int id) async {
    final rows = await _d.query('workout_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final exRows = await _d.rawQuery(
      'SELECT se.*, ${Exercise.selectColumns('e', 'ex_')} FROM session_exercises se '
      'JOIN exercises e ON e.id = se.exercise_id WHERE se.session_id = ? ORDER BY se.sort_order, se.id',
      [id],
    );
    final setRows = await _d.rawQuery(
      'SELECT sl.* FROM set_logs sl JOIN session_exercises se ON se.id = sl.session_exercise_id '
      'WHERE se.session_id = ? ORDER BY sl.set_number, sl.id',
      [id],
    );
    final setsByExercise = <int, List<SetLog>>{};
    for (final r in setRows) {
      final s = SetLog.fromMap(r);
      setsByExercise.putIfAbsent(s.sessionExerciseId, () => []).add(s);
    }
    return WorkoutSession.fromMap(rows.first, [
      for (final r in exRows) SessionExercise.fromMap(r, setsByExercise[r['id']] ?? const []),
    ]);
  }

  /// Completed sets from the most recent finished session that included
  /// [exerciseId]. Used to show "previous" and to pre-fill new sets.
  Future<List<SetLog>> previousSets(int exerciseId, {int? excludeSessionId}) async {
    final last = await _d.rawQuery(
      'SELECT se.id FROM session_exercises se JOIN workout_sessions s ON s.id = se.session_id '
      "WHERE se.exercise_id = ? AND s.status = 'completed' AND s.id != ? "
      'AND EXISTS (SELECT 1 FROM set_logs sl WHERE sl.session_exercise_id = se.id AND sl.is_completed = 1) '
      'ORDER BY s.date DESC, s.started_at DESC LIMIT 1',
      [exerciseId, excludeSessionId ?? -1],
    );
    if (last.isEmpty) return const [];
    final rows = await _d.query(
      'set_logs',
      where: 'session_exercise_id = ? AND is_completed = 1',
      whereArgs: [last.first['id']],
      orderBy: 'set_number',
    );
    return rows.map(SetLog.fromMap).toList();
  }

  Future<List<SessionListItem>> history({int limit = 50, int offset = 0}) async {
    final rows = await _d.rawQuery(
      '''
      SELECT s.id, s.name, s.date, s.duration_seconds,
        (SELECT COUNT(*) FROM session_exercises se WHERE se.session_id = s.id AND se.status = 'completed') AS exercises,
        (SELECT COUNT(*) FROM set_logs sl JOIN session_exercises se ON se.id = sl.session_exercise_id
          WHERE se.session_id = s.id AND sl.is_completed = 1) AS sets,
        (SELECT COALESCE(SUM(sl.weight_kg * sl.reps), 0) FROM set_logs sl
          JOIN session_exercises se ON se.id = sl.session_exercise_id
          JOIN exercises e ON e.id = se.exercise_id
          WHERE se.session_id = s.id AND sl.is_completed = 1 AND sl.weight_kg > 0 AND sl.reps > 0
            AND e.exercise_type IN ('weight_reps', 'bodyweight_reps')) AS volume
      FROM workout_sessions s WHERE s.status = 'completed'
      ORDER BY s.date DESC, s.started_at DESC LIMIT ? OFFSET ?''',
      [limit, offset],
    );
    return [
      for (final r in rows)
        SessionListItem(
          id: r['id'] as int,
          name: r['name'] as String,
          date: r['date'] as String,
          durationSeconds: r['duration_seconds'] as int,
          exerciseCount: r['exercises'] as int,
          setCount: r['sets'] as int,
          volumeKg: (r['volume'] as num).toDouble(),
        ),
    ];
  }

  /// Dates (YYYY-MM-DD) in [from]..[to] with at least one completed session.
  Future<Set<String>> completedDates(String from, String to) async {
    final rows = await _d.rawQuery(
      "SELECT DISTINCT date FROM workout_sessions WHERE status = 'completed' AND date BETWEEN ? AND ?",
      [from, to],
    );
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<List<WorkoutSession>> completedOn(String date) async {
    final rows = await _d.query(
      'workout_sessions',
      columns: ['id'],
      where: "status = 'completed' AND date = ?",
      whereArgs: [date],
      orderBy: 'started_at',
    );
    final result = <WorkoutSession>[];
    for (final r in rows) {
      final s = await byId(r['id'] as int);
      if (s != null) result.add(s);
    }
    return result;
  }

  /// Per-session stats for one exercise, oldest first.
  Future<List<ExerciseSessionStats>> exerciseHistory(Exercise exercise) async {
    final rows = await _d.rawQuery(
      'SELECT s.id AS sid, s.date AS sdate, sl.* FROM set_logs sl '
      'JOIN session_exercises se ON se.id = sl.session_exercise_id '
      'JOIN workout_sessions s ON s.id = se.session_id '
      "WHERE se.exercise_id = ? AND s.status = 'completed' AND sl.is_completed = 1 "
      'ORDER BY s.date, s.started_at, sl.set_number',
      [exercise.id],
    );
    final grouped = <int, List<SetLog>>{};
    final dates = <int, String>{};
    for (final r in rows) {
      final sid = r['sid'] as int;
      dates[sid] = r['sdate'] as String;
      grouped.putIfAbsent(sid, () => []).add(SetLog.fromMap(r));
    }
    return [
      for (final e in grouped.entries)
        ExerciseSessionStats.fromSets(sessionId: e.key, date: dates[e.key]!, type: exercise.type, sets: e.value),
    ];
  }

  /// Exercises that have at least one completed set, most recently used first.
  Future<List<Exercise>> exercisesWithHistory() async {
    final rows = await _d.rawQuery(
      'SELECT ${Exercise.selectColumns('e', '')}, MAX(s.date) AS last_date FROM exercises e '
      'JOIN session_exercises se ON se.exercise_id = e.id '
      'JOIN workout_sessions s ON s.id = se.session_id '
      "WHERE s.status = 'completed' AND EXISTS "
      '(SELECT 1 FROM set_logs sl WHERE sl.session_exercise_id = se.id AND sl.is_completed = 1) '
      'GROUP BY e.id ORDER BY last_date DESC, e.name COLLATE NOCASE',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<int> completedCount(String from, String to) async {
    final rows = await _d.rawQuery(
      "SELECT COUNT(*) AS c FROM workout_sessions WHERE status = 'completed' AND date BETWEEN ? AND ?",
      [from, to],
    );
    return rows.first['c'] as int;
  }

  // ---------------------------------------------------------------------------
  // Starting

  /// Starts a session from a plan day. If a session is already in progress,
  /// returns that one instead of creating a duplicate.
  Future<int> startFromPlanDay(PlanDay day, {required String date}) => _d.transaction((txn) async {
    final existing = await _activeId(txn);
    if (existing != null) return existing;
    final sessionId = await _insertSession(txn, name: day.title, date: date, planDayId: day.id);
    var order = 0;
    for (final p in day.exercises) {
      await _insertSessionExercise(
        txn,
        sessionId: sessionId,
        exercise: p.exercise,
        order: order++,
        sets: p.sets,
        minReps: p.minReps,
        maxReps: p.maxReps,
        rest: p.restSeconds,
      );
    }
    return sessionId;
  });

  /// Starts a session with no exercises; the user adds them as they go.
  Future<int> startEmpty({required String date, String name = 'Quick workout'}) => _d.transaction((txn) async {
    final existing = await _activeId(txn);
    if (existing != null) return existing;
    return _insertSession(txn, name: name, date: date);
  });

  Future<int?> _activeId(DatabaseExecutor txn) async {
    final rows = await txn.query('workout_sessions', columns: ['id'], where: "status = 'in_progress'", limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<int> _insertSession(DatabaseExecutor txn, {required String name, required String date, int? planDayId}) =>
      txn.insert('workout_sessions', {
        'plan_day_id': planDayId,
        'name': name,
        'date': date,
        'started_at': timestampNow(),
        'status': SessionStatus.inProgress.dbValue,
        'current_index': 0,
      });

  /// Adds an exercise with [sets] empty sets, pre-filled from the last time it
  /// was done. Pre-filled sets are never marked complete.
  Future<int> _insertSessionExercise(
    DatabaseExecutor txn, {
    required int sessionId,
    required Exercise exercise,
    required int order,
    required int sets,
    int? minReps,
    int? maxReps,
    required int rest,
  }) async {
    final seId = await txn.insert('session_exercises', {
      'session_id': sessionId,
      'exercise_id': exercise.id,
      'sort_order': order,
      'status': SessionExerciseStatus.pending.name,
      'min_reps': minReps,
      'max_reps': maxReps,
      'rest_seconds': rest,
    });
    final previous = await _previousSetsTxn(txn, exercise.id, sessionId);
    for (var n = 1; n <= sets; n++) {
      final prev = previous.isEmpty ? null : previous[(n - 1).clamp(0, previous.length - 1)];
      await txn.insert('set_logs', {
        'session_exercise_id': seId,
        'set_number': n,
        'weight_kg': prev?['weight_kg'],
        'reps': prev?['reps'],
        'duration_seconds': prev?['duration_seconds'],
        'distance_meters': prev?['distance_meters'],
        'is_completed': 0,
      });
    }
    return seId;
  }

  Future<List<Map<String, Object?>>> _previousSetsTxn(
    DatabaseExecutor txn,
    int exerciseId,
    int excludeSessionId,
  ) async {
    final last = await txn.rawQuery(
      'SELECT se.id FROM session_exercises se JOIN workout_sessions s ON s.id = se.session_id '
      "WHERE se.exercise_id = ? AND s.status = 'completed' AND s.id != ? "
      'AND EXISTS (SELECT 1 FROM set_logs sl WHERE sl.session_exercise_id = se.id AND sl.is_completed = 1) '
      'ORDER BY s.date DESC, s.started_at DESC LIMIT 1',
      [exerciseId, excludeSessionId],
    );
    if (last.isEmpty) return const [];
    return txn.query(
      'set_logs',
      where: 'session_exercise_id = ? AND is_completed = 1',
      whereArgs: [last.first['id']],
      orderBy: 'set_number',
    );
  }

  // ---------------------------------------------------------------------------
  // Editing a session

  Future<int> addExercise(int sessionId, Exercise exercise, {int sets = 3, int restSeconds = 90}) =>
      _d.transaction((txn) async {
        final maxOrder = await txn.rawQuery('SELECT MAX(sort_order) AS m FROM session_exercises WHERE session_id = ?', [
          sessionId,
        ]);
        return _insertSessionExercise(
          txn,
          sessionId: sessionId,
          exercise: exercise,
          order: ((maxOrder.first['m'] as int?) ?? -1) + 1,
          sets: sets,
          rest: restSeconds,
        );
      });

  /// Swaps the exercise in place. Logged values are cleared because they
  /// belonged to the old exercise; the number of sets is kept.
  Future<void> replaceExercise(int sessionExerciseId, Exercise replacement) => _d.transaction((txn) async {
    final row = (await txn.query('session_exercises', where: 'id = ?', whereArgs: [sessionExerciseId])).first;
    final setCount =
        (await txn.rawQuery('SELECT COUNT(*) AS c FROM set_logs WHERE session_exercise_id = ?', [
              sessionExerciseId,
            ])).first['c']
            as int;
    await txn.delete('set_logs', where: 'session_exercise_id = ?', whereArgs: [sessionExerciseId]);
    await txn.update(
      'session_exercises',
      {'exercise_id': replacement.id, 'status': SessionExerciseStatus.pending.name},
      where: 'id = ?',
      whereArgs: [sessionExerciseId],
    );
    final previous = await _previousSetsTxn(txn, replacement.id, row['session_id'] as int);
    for (var n = 1; n <= (setCount == 0 ? 3 : setCount); n++) {
      final prev = previous.isEmpty ? null : previous[(n - 1).clamp(0, previous.length - 1)];
      await txn.insert('set_logs', {
        'session_exercise_id': sessionExerciseId,
        'set_number': n,
        'weight_kg': prev?['weight_kg'],
        'reps': prev?['reps'],
        'duration_seconds': prev?['duration_seconds'],
        'distance_meters': prev?['distance_meters'],
        'is_completed': 0,
      });
    }
  });

  Future<void> removeExercise(int sessionExerciseId) =>
      _d.delete('session_exercises', where: 'id = ?', whereArgs: [sessionExerciseId]);

  Future<void> setExerciseStatus(int sessionExerciseId, SessionExerciseStatus status) =>
      _d.update('session_exercises', {'status': status.name}, where: 'id = ?', whereArgs: [sessionExerciseId]);

  Future<void> setRestSeconds(int sessionExerciseId, int seconds) => _d.update(
    'session_exercises',
    {'rest_seconds': seconds.clamp(0, 3600)},
    where: 'id = ?',
    whereArgs: [sessionExerciseId],
  );

  Future<void> setCurrentIndex(int sessionId, int index) =>
      _d.update('workout_sessions', {'current_index': index}, where: 'id = ?', whereArgs: [sessionId]);

  /// Adds a set copying the previous set's values (not its completion).
  Future<int> addSet(int sessionExerciseId) => _d.transaction((txn) async {
    final last = await txn.query(
      'set_logs',
      where: 'session_exercise_id = ?',
      whereArgs: [sessionExerciseId],
      orderBy: 'set_number DESC',
      limit: 1,
    );
    final prev = last.isEmpty ? null : last.first;
    return txn.insert('set_logs', {
      'session_exercise_id': sessionExerciseId,
      'set_number': ((prev?['set_number'] as int?) ?? 0) + 1,
      'weight_kg': prev?['weight_kg'],
      'reps': prev?['reps'],
      'duration_seconds': prev?['duration_seconds'],
      'distance_meters': prev?['distance_meters'],
      'is_completed': 0,
    });
  });

  Future<void> removeSet(int setId) => _d.transaction((txn) async {
    final row = await txn.query('set_logs', columns: ['session_exercise_id'], where: 'id = ?', whereArgs: [setId]);
    if (row.isEmpty) return;
    final seId = row.first['session_exercise_id'] as int;
    await txn.delete('set_logs', where: 'id = ?', whereArgs: [setId]);
    final remaining = await txn.query(
      'set_logs',
      columns: ['id'],
      where: 'session_exercise_id = ?',
      whereArgs: [seId],
      orderBy: 'set_number, id',
    );
    for (var i = 0; i < remaining.length; i++) {
      await txn.update('set_logs', {'set_number': i + 1}, where: 'id = ?', whereArgs: [remaining[i]['id']]);
    }
  });

  Future<void> updateSetValues(int setId, SetValues values) {
    final error = values.validate();
    if (error != null) throw ArgumentError(error);
    return _d.update(
      'set_logs',
      {
        'weight_kg': values.weightKg,
        'reps': values.reps,
        'duration_seconds': values.durationSeconds,
        'distance_meters': values.distanceMeters,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<void> setCompleted(int setId, bool completed) => _d.update(
    'set_logs',
    {'is_completed': completed ? 1 : 0, 'completed_at': completed ? timestampNow() : null},
    where: 'id = ?',
    whereArgs: [setId],
  );

  // ---------------------------------------------------------------------------
  // Finishing

  /// Saves the session as completed. Sets that were never ticked are removed
  /// (they were not performed); exercises without a completed set are marked
  /// skipped.
  Future<void> finish(int sessionId, {String notes = ''}) => _d.transaction((txn) async {
    final session = (await txn.query('workout_sessions', where: 'id = ?', whereArgs: [sessionId])).first;
    await txn.rawDelete(
      'DELETE FROM set_logs WHERE is_completed = 0 AND session_exercise_id IN '
      '(SELECT id FROM session_exercises WHERE session_id = ?)',
      [sessionId],
    );
    await txn.rawUpdate(
      "UPDATE session_exercises SET status = CASE WHEN EXISTS "
      '(SELECT 1 FROM set_logs sl WHERE sl.session_exercise_id = session_exercises.id) '
      "THEN 'completed' ELSE 'skipped' END WHERE session_id = ?",
      [sessionId],
    );
    final started = DateTime.parse(session['started_at'] as String);
    final now = DateTime.now().toUtc();
    await txn.update(
      'workout_sessions',
      {
        'status': SessionStatus.completed.dbValue,
        'completed_at': now.toIso8601String(),
        'duration_seconds': now.difference(started).inSeconds.clamp(0, 86400),
        'notes': notes.trim(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  });

  Future<void> updateDuration(int sessionId, int seconds) => _d.update(
    'workout_sessions',
    {'duration_seconds': seconds.clamp(0, 86400)},
    where: 'id = ?',
    whereArgs: [sessionId],
  );

  Future<void> updateNotes(int sessionId, String notes) =>
      _d.update('workout_sessions', {'notes': notes.trim()}, where: 'id = ?', whereArgs: [sessionId]);

  /// Deletes a session and everything logged in it.
  Future<void> delete(int sessionId) => _d.delete('workout_sessions', where: 'id = ?', whereArgs: [sessionId]);
}
