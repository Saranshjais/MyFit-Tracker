import 'package:sqflite/sqflite.dart';

import '../../../core/utils/dates.dart';

/// Editable starting plans offered on first launch. They are generic examples,
/// not personalised or medical advice, and are clearly labelled as samples.
class SampleExercise {
  const SampleExercise(this.name, {this.sets = 3, this.minReps = 8, this.maxReps = 12, this.rest = 90});
  final String name;
  final int sets;

  /// For timed exercises these are target seconds.
  final int minReps;
  final int maxReps;
  final int rest;
}

class SampleDay {
  const SampleDay(this.weekday, this.name, this.exercises, {this.rest = false});
  const SampleDay.rest(this.weekday, [this.name = 'Rest Day']) : exercises = const [], rest = true;
  final int weekday;
  final String name;
  final List<SampleExercise> exercises;
  final bool rest;
}

const _chestTriceps = [
  SampleExercise('Bench Press', minReps: 6, maxReps: 10, rest: 120),
  SampleExercise('Incline Dumbbell Press'),
  SampleExercise('Chest Fly', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Triceps Pushdown', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Overhead Triceps Extension', minReps: 10, maxReps: 15, rest: 60),
];
const _backBiceps = [
  SampleExercise('Lat Pulldown'),
  SampleExercise('Seated Cable Row'),
  SampleExercise('Barbell Row', minReps: 6, maxReps: 10, rest: 120),
  SampleExercise('Biceps Curl', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Hammer Curl', minReps: 10, maxReps: 15, rest: 60),
];
const _legsCore = [
  SampleExercise('Squat', minReps: 6, maxReps: 10, rest: 150),
  SampleExercise('Leg Press', minReps: 10, maxReps: 12),
  SampleExercise('Romanian Deadlift', rest: 120),
  SampleExercise('Standing Calf Raise', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Plank', minReps: 30, maxReps: 60, rest: 60),
];
const _shoulders = [
  SampleExercise('Shoulder Press', minReps: 6, maxReps: 10, rest: 120),
  SampleExercise('Lateral Raise', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Rear Delt Fly', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Face Pull', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Dumbbell Shrug', minReps: 10, maxReps: 15, rest: 60),
];
const _armsAbs = [
  SampleExercise('Barbell Curl'),
  SampleExercise('Skull Crusher'),
  SampleExercise('Hammer Curl', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Triceps Pushdown', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Hanging Leg Raise', minReps: 8, maxReps: 15, rest: 60),
];
const _fullBody = [
  SampleExercise('Deadlift', minReps: 5, maxReps: 8, rest: 150),
  SampleExercise('Goblet Squat'),
  SampleExercise('Push-up', minReps: 8, maxReps: 15, rest: 60),
  SampleExercise('Pull-up', minReps: 5, maxReps: 10),
  SampleExercise('Kettlebell Swing', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Plank', minReps: 30, maxReps: 60, rest: 60),
];
const _fullBodyA = [
  SampleExercise('Squat', minReps: 6, maxReps: 10, rest: 150),
  SampleExercise('Bench Press', minReps: 6, maxReps: 10, rest: 120),
  SampleExercise('Barbell Row', rest: 120),
  SampleExercise('Shoulder Press'),
  SampleExercise('Plank', minReps: 30, maxReps: 60, rest: 60),
];
const _fullBodyB = [
  SampleExercise('Romanian Deadlift', rest: 120),
  SampleExercise('Incline Dumbbell Press'),
  SampleExercise('Lat Pulldown'),
  SampleExercise('Lateral Raise', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Hanging Leg Raise', minReps: 8, maxReps: 15, rest: 60),
];
const _fullBodyC = [
  SampleExercise('Leg Press', minReps: 10, maxReps: 12),
  SampleExercise('Dumbbell Bench Press'),
  SampleExercise('Seated Cable Row'),
  SampleExercise('Biceps Curl', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Triceps Pushdown', minReps: 10, maxReps: 15, rest: 60),
];
const _upperA = [
  SampleExercise('Bench Press', minReps: 6, maxReps: 10, rest: 120),
  SampleExercise('Barbell Row', rest: 120),
  SampleExercise('Shoulder Press'),
  SampleExercise('Lat Pulldown'),
  SampleExercise('Biceps Curl', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Triceps Pushdown', minReps: 10, maxReps: 15, rest: 60),
];
const _lowerA = [
  SampleExercise('Squat', minReps: 6, maxReps: 10, rest: 150),
  SampleExercise('Romanian Deadlift', rest: 120),
  SampleExercise('Leg Extension', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Standing Calf Raise', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Plank', minReps: 30, maxReps: 60, rest: 60),
];
const _upperB = [
  SampleExercise('Incline Dumbbell Press'),
  SampleExercise('Seated Cable Row'),
  SampleExercise('Lateral Raise', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Pull-up', minReps: 5, maxReps: 10),
  SampleExercise('Hammer Curl', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Overhead Triceps Extension', minReps: 10, maxReps: 15, rest: 60),
];
const _lowerB = [
  SampleExercise('Deadlift', minReps: 5, maxReps: 8, rest: 150),
  SampleExercise('Leg Press', minReps: 10, maxReps: 12),
  SampleExercise('Lying Leg Curl', minReps: 10, maxReps: 15, rest: 60),
  SampleExercise('Walking Lunge', minReps: 10, maxReps: 12),
  SampleExercise('Hanging Leg Raise', minReps: 8, maxReps: 15, rest: 60),
];
const _shouldersArms = [
  SampleExercise('Shoulder Press', minReps: 6, maxReps: 10, rest: 120),
  SampleExercise('Lateral Raise', minReps: 12, maxReps: 15, rest: 60),
  SampleExercise('Barbell Curl'),
  SampleExercise('Skull Crusher'),
  SampleExercise('Face Pull', minReps: 12, maxReps: 15, rest: 60),
];

class SamplePlans {
  static const supportedDays = [3, 4, 5, 6];
  static const defaultDays = 6;

  static String planName(int days) => 'Sample $days-day plan';

  static const description =
      'A generic starting point. Edit the exercises, sets, reps and training days to suit you. '
      'It is not personalised or medical advice.';

  static List<SampleDay> forDays(int days) {
    switch (days) {
      case 3:
        return const [
          SampleDay(1, 'Full Body A', _fullBodyA),
          SampleDay.rest(2),
          SampleDay(3, 'Full Body B', _fullBodyB),
          SampleDay.rest(4),
          SampleDay(5, 'Full Body C', _fullBodyC),
          SampleDay.rest(6),
          SampleDay.rest(7),
        ];
      case 4:
        return const [
          SampleDay(1, 'Upper Body A', _upperA),
          SampleDay(2, 'Lower Body A', _lowerA),
          SampleDay.rest(3),
          SampleDay(4, 'Upper Body B', _upperB),
          SampleDay(5, 'Lower Body B', _lowerB),
          SampleDay.rest(6),
          SampleDay.rest(7),
        ];
      case 5:
        return const [
          SampleDay(1, 'Chest & Triceps', _chestTriceps),
          SampleDay(2, 'Back & Biceps', _backBiceps),
          SampleDay(3, 'Legs & Core', _legsCore),
          SampleDay.rest(4, 'Active Recovery'),
          SampleDay(5, 'Shoulders & Arms', _shouldersArms),
          SampleDay(6, 'Full Body', _fullBody),
          SampleDay.rest(7),
        ];
      default:
        return const [
          SampleDay(1, 'Chest & Triceps', _chestTriceps),
          SampleDay(2, 'Back & Biceps', _backBiceps),
          SampleDay(3, 'Legs & Core', _legsCore),
          SampleDay(4, 'Shoulders', _shoulders),
          SampleDay(5, 'Arms & Abs', _armsAbs),
          SampleDay(6, 'Full Body', _fullBody),
          SampleDay.rest(7, 'Active Recovery'),
        ];
    }
  }

  /// Inserts a sample plan and returns its id. Exercises that are missing
  /// from the library (for example archived ones) are skipped.
  static Future<int> insert(DatabaseExecutor db, {required int days, required bool active}) async {
    final now = timestampNow();
    final rows = await db.query('exercises', columns: ['id', 'name'], where: 'is_archived = 0');
    final idsByName = {for (final r in rows) (r['name'] as String).toLowerCase(): r['id'] as int};

    final planId = await db.insert('workout_plans', {
      'name': planName(days),
      'description': description,
      'is_sample': 1,
      'is_active': active ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
    for (final day in forDays(days)) {
      final dayId = await db.insert('workout_plan_days', {
        'plan_id': planId,
        'weekday': day.weekday,
        'name': day.name,
        'is_rest_day': day.rest ? 1 : 0,
      });
      var order = 0;
      for (final ex in day.exercises) {
        final exerciseId = idsByName[ex.name.toLowerCase()];
        if (exerciseId == null) continue;
        await db.insert('planned_exercises', {
          'plan_day_id': dayId,
          'exercise_id': exerciseId,
          'sort_order': order++,
          'planned_sets': ex.sets,
          'min_reps': ex.minReps,
          'max_reps': ex.maxReps,
          'rest_seconds': ex.rest,
        });
      }
    }
    return planId;
  }
}
