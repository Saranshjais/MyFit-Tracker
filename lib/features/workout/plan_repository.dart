import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import '../exercises/exercise.dart';
import 'data/sample_plans.dart';
import 'models.dart';

class PlanRepository {
  PlanRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<WorkoutPlan>> plans() async {
    final rows = await _d.query('workout_plans', orderBy: 'is_active DESC, updated_at DESC');
    return rows.map(WorkoutPlan.fromMap).toList();
  }

  Future<PlanWithDays?> activePlan() async {
    final rows = await _d.query('workout_plans', where: 'is_active = 1', limit: 1);
    if (rows.isEmpty) return null;
    return _withDays(WorkoutPlan.fromMap(rows.first));
  }

  Future<PlanWithDays?> planWithDays(int planId) async {
    final rows = await _d.query('workout_plans', where: 'id = ?', whereArgs: [planId]);
    if (rows.isEmpty) return null;
    return _withDays(WorkoutPlan.fromMap(rows.first));
  }

  Future<PlanWithDays> _withDays(WorkoutPlan plan) async {
    await _ensureSevenDays(_d, plan.id);
    final dayRows = await _d.query('workout_plan_days', where: 'plan_id = ?', whereArgs: [plan.id], orderBy: 'weekday');
    final exercises = await _plannedExercises('pd.plan_id = ?', [plan.id]);
    final byDay = <int, List<PlannedExercise>>{};
    for (final e in exercises) {
      byDay.putIfAbsent(e.planDayId, () => []).add(e);
    }
    return PlanWithDays(plan, [for (final r in dayRows) PlanDay.fromMap(r, byDay[r['id']] ?? const [])]);
  }

  Future<PlanDay?> day(int dayId) async {
    final rows = await _d.query('workout_plan_days', where: 'id = ?', whereArgs: [dayId]);
    if (rows.isEmpty) return null;
    return PlanDay.fromMap(rows.first, await _plannedExercises('pe.plan_day_id = ?', [dayId]));
  }

  Future<List<PlannedExercise>> _plannedExercises(String where, List<Object?> args) async {
    final rows = await _d.rawQuery(
      'SELECT pe.*, ${Exercise.selectColumns('e', 'ex_')} FROM planned_exercises pe '
      'JOIN exercises e ON e.id = pe.exercise_id '
      'JOIN workout_plan_days pd ON pd.id = pe.plan_day_id '
      'WHERE $where ORDER BY pe.sort_order, pe.id',
      args,
    );
    return rows.map(PlannedExercise.fromMap).toList();
  }

  /// Older or imported plans may be missing weekdays; add them as rest days.
  static Future<void> _ensureSevenDays(DatabaseExecutor db, int planId) async {
    final rows = await db.query('workout_plan_days', columns: ['weekday'], where: 'plan_id = ?', whereArgs: [planId]);
    final have = rows.map((r) => r['weekday'] as int).toSet();
    for (var wd = 1; wd <= 7; wd++) {
      if (!have.contains(wd)) {
        await db.insert('workout_plan_days', {'plan_id': planId, 'weekday': wd, 'name': '', 'is_rest_day': 1});
      }
    }
  }

  Future<void> _touch(DatabaseExecutor db, int planId) =>
      db.update('workout_plans', {'updated_at': timestampNow()}, where: 'id = ?', whereArgs: [planId]);

  Future<int> _planIdForDay(DatabaseExecutor db, int dayId) async {
    final rows = await db.query('workout_plan_days', columns: ['plan_id'], where: 'id = ?', whereArgs: [dayId]);
    return rows.first['plan_id'] as int;
  }

  /// Creates a plan with seven rest days. It becomes active when no other
  /// plan is.
  Future<int> createPlan(String name) => _d.transaction((txn) async {
    final now = timestampNow();
    final hasActive = (await txn.query('workout_plans', where: 'is_active = 1', limit: 1)).isNotEmpty;
    final id = await txn.insert('workout_plans', {
      'name': name.trim(),
      'description': '',
      'is_sample': 0,
      'is_active': hasActive ? 0 : 1,
      'created_at': now,
      'updated_at': now,
    });
    await _ensureSevenDays(txn, id);
    return id;
  });

  Future<void> renamePlan(int id, String name) => _d.update(
    'workout_plans',
    {'name': name.trim(), 'is_sample': 0, 'updated_at': timestampNow()},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<int> duplicatePlan(int id) => _d.transaction((txn) async {
    final source = (await txn.query('workout_plans', where: 'id = ?', whereArgs: [id])).first;
    final now = timestampNow();
    final newId = await txn.insert('workout_plans', {
      'name': '${source['name']} (copy)',
      'description': source['description'],
      'is_sample': 0,
      'is_active': 0,
      'created_at': now,
      'updated_at': now,
    });
    final days = await txn.query('workout_plan_days', where: 'plan_id = ?', whereArgs: [id]);
    for (final d in days) {
      final newDayId = await txn.insert('workout_plan_days', {
        'plan_id': newId,
        'weekday': d['weekday'],
        'name': d['name'],
        'is_rest_day': d['is_rest_day'],
      });
      await _copyExercises(txn, d['id'] as int, newDayId);
    }
    await _ensureSevenDays(txn, newId);
    return newId;
  });

  /// Past sessions keep their records; only their link to the plan is cleared.
  Future<void> deletePlan(int id) => _d.transaction((txn) async {
    final wasActive = (await txn.query('workout_plans', where: 'id = ? AND is_active = 1', whereArgs: [id])).isNotEmpty;
    await txn.delete('workout_plans', where: 'id = ?', whereArgs: [id]);
    if (wasActive) {
      final next = await txn.query('workout_plans', orderBy: 'updated_at DESC', limit: 1);
      if (next.isNotEmpty) {
        await txn.update('workout_plans', {'is_active': 1}, where: 'id = ?', whereArgs: [next.first['id']]);
      }
    }
  });

  Future<void> setActive(int id) => _d.transaction((txn) async {
    await txn.update('workout_plans', {'is_active': 0});
    await txn.update('workout_plans', {'is_active': 1, 'updated_at': timestampNow()}, where: 'id = ?', whereArgs: [id]);
  });

  Future<void> updateDay(int dayId, {String? name, bool? isRestDay}) => _d.transaction((txn) async {
    await txn.update(
      'workout_plan_days',
      {if (name != null) 'name': name.trim(), if (isRestDay != null) 'is_rest_day': isRestDay ? 1 : 0},
      where: 'id = ?',
      whereArgs: [dayId],
    );
    await _touch(txn, await _planIdForDay(txn, dayId));
  });

  Future<int> addExercise(
    int dayId,
    int exerciseId, {
    int sets = 3,
    int? minReps = 8,
    int? maxReps = 12,
    int restSeconds = 90,
  }) => _d.transaction((txn) async {
    final maxOrder = await txn.rawQuery('SELECT MAX(sort_order) AS m FROM planned_exercises WHERE plan_day_id = ?', [
      dayId,
    ]);
    final next = ((maxOrder.first['m'] as int?) ?? -1) + 1;
    final id = await txn.insert('planned_exercises', {
      'plan_day_id': dayId,
      'exercise_id': exerciseId,
      'sort_order': next,
      'planned_sets': sets,
      'min_reps': minReps,
      'max_reps': maxReps,
      'rest_seconds': restSeconds,
    });
    // Adding an exercise to a rest day turns it into a training day.
    await txn.update('workout_plan_days', {'is_rest_day': 0}, where: 'id = ?', whereArgs: [dayId]);
    await _touch(txn, await _planIdForDay(txn, dayId));
    return id;
  });

  Future<void> updatePlannedExercise(
    int id, {
    required int sets,
    int? minReps,
    int? maxReps,
    required int restSeconds,
  }) {
    if (sets < 1 || sets > 20) throw ArgumentError('Sets must be between 1 and 20');
    if ((minReps ?? 0) < 0 || (maxReps ?? 0) < 0) throw ArgumentError('Reps cannot be negative');
    if (minReps != null && maxReps != null && minReps > maxReps) throw ArgumentError('Minimum reps exceed maximum');
    if (restSeconds < 0 || restSeconds > 3600) throw ArgumentError('Rest must be between 0 and 3600 seconds');
    return _d.update(
      'planned_exercises',
      {'planned_sets': sets, 'min_reps': minReps, 'max_reps': maxReps, 'rest_seconds': restSeconds},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removePlannedExercise(int id) => _d.delete('planned_exercises', where: 'id = ?', whereArgs: [id]);

  Future<void> reorder(int dayId, List<int> orderedIds) => _d.transaction((txn) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await txn.update(
        'planned_exercises',
        {'sort_order': i},
        where: 'id = ? AND plan_day_id = ?',
        whereArgs: [orderedIds[i], dayId],
      );
    }
  });

  /// Replaces [toDayId]'s workout with a copy of [fromDayId]'s.
  Future<void> copyDay(int fromDayId, int toDayId) => _d.transaction((txn) async {
    final from = (await txn.query('workout_plan_days', where: 'id = ?', whereArgs: [fromDayId])).first;
    await txn.update(
      'workout_plan_days',
      {'name': from['name'], 'is_rest_day': from['is_rest_day']},
      where: 'id = ?',
      whereArgs: [toDayId],
    );
    await txn.delete('planned_exercises', where: 'plan_day_id = ?', whereArgs: [toDayId]);
    await _copyExercises(txn, fromDayId, toDayId);
    await _touch(txn, await _planIdForDay(txn, toDayId));
  });

  Future<void> clearDay(int dayId) => _d.transaction((txn) async {
    await txn.delete('planned_exercises', where: 'plan_day_id = ?', whereArgs: [dayId]);
    await txn.update('workout_plan_days', {'name': '', 'is_rest_day': 1}, where: 'id = ?', whereArgs: [dayId]);
  });

  Future<void> _copyExercises(DatabaseExecutor txn, int fromDayId, int toDayId) async {
    final rows = await txn.query(
      'planned_exercises',
      where: 'plan_day_id = ?',
      whereArgs: [fromDayId],
      orderBy: 'sort_order',
    );
    for (final r in rows) {
      await txn.insert('planned_exercises', {
        'plan_day_id': toDayId,
        'exercise_id': r['exercise_id'],
        'sort_order': r['sort_order'],
        'planned_sets': r['planned_sets'],
        'min_reps': r['min_reps'],
        'max_reps': r['max_reps'],
        'rest_seconds': r['rest_seconds'],
      });
    }
  }

  /// Swaps the bundled sample plan for one matching [days] training days a
  /// week. Used once, at the end of onboarding.
  Future<void> replaceSamplePlan(int days) => _d.transaction((txn) async {
    final userPlans = await txn.query('workout_plans', where: 'is_sample = 0', limit: 1);
    await txn.delete('workout_plans', where: 'is_sample = 1');
    await SamplePlans.insert(txn, days: days, active: userPlans.isEmpty);
  });
}
