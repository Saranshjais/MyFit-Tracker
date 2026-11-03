import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/features/exercises/exercise.dart';
import 'package:myfit_tracker/features/workout/models.dart';
import 'package:myfit_tracker/features/workout/workout_calculations.dart';

const bench = Exercise(id: 1, name: 'Bench Press', muscle: 'Chest', equipment: 'Barbell');
const pushUp = Exercise(
  id: 2,
  name: 'Push-up',
  muscle: 'Chest',
  equipment: 'Bodyweight',
  type: ExerciseType.bodyweightReps,
);
const plank = Exercise(id: 3, name: 'Plank', muscle: 'Core', equipment: 'Bodyweight', type: ExerciseType.time);

SetLog set(int n, {double? kg, int? reps, int? seconds, bool done = true}) => SetLog(
  id: n,
  sessionExerciseId: 1,
  setNumber: n,
  weightKg: kg,
  reps: reps,
  durationSeconds: seconds,
  isCompleted: done,
);

WorkoutSession session(List<SessionExercise> exercises) => WorkoutSession(
  id: 1,
  name: 'Test',
  date: '2026-11-03',
  startedAt: DateTime(2026, 11, 3, 18),
  status: SessionStatus.inProgress,
  exercises: exercises,
);

SessionExercise se(Exercise e, List<SetLog> sets) => SessionExercise(
  id: e.id,
  sessionId: 1,
  exercise: e,
  sortOrder: 0,
  status: SessionExerciseStatus.pending,
  restSeconds: 90,
  sets: sets,
);

void main() {
  group('volume', () {
    test('counts only completed sets with weight and reps', () {
      final s = session([
        se(bench, [set(1, kg: 20, reps: 12), set(2, kg: 25, reps: 10), set(3, kg: 25, reps: 8, done: false)]),
      ]);
      final summary = summarizeSession(s);
      expect(summary.volumeKg, 20 * 12 + 25 * 10);
      expect(summary.completedSets, 2);
      expect(summary.totalSets, 3);
      expect(summary.volumeSets, 2);
    });

    test('bodyweight and timed sets are excluded and counted separately', () {
      final s = session([
        se(pushUp, [set(1, reps: 15), set(2, kg: 10, reps: 8)]),
        se(plank, [set(1, seconds: 60)]),
      ]);
      final summary = summarizeSession(s);
      expect(summary.volumeKg, 80); // only the +10 kg set
      expect(summary.volumeSets, 1);
      expect(summary.excludedSets, 2);
      expect(summary.completedExercises, 2);
    });

    test('zero weight or zero reps adds no volume', () {
      expect(setVolume(set(1, kg: 0, reps: 10), ExerciseType.weightReps), 0);
      expect(setVolume(set(1, kg: 50, reps: 0), ExerciseType.weightReps), 0);
    });
  });

  group('estimated 1RM (Epley)', () {
    test('formula', () {
      expect(estimatedOneRepMax(100, 10), closeTo(100 * (1 + 10 / 30), 1e-9));
      expect(estimatedOneRepMax(100, 1), 100);
    });

    test('not estimated outside 1–12 reps or without weight', () {
      expect(estimatedOneRepMax(100, 15), isNull);
      expect(estimatedOneRepMax(0, 5), isNull);
      expect(estimatedOneRepMax(null, 5), isNull);
    });
  });

  group('set validation', () {
    test('negative values are rejected', () {
      expect(const SetValues(weightKg: -1, reps: 5).validate(), isNotNull);
      expect(const SetValues(weightKg: 20, reps: -3).validate(), isNotNull);
      expect(const SetValues(weightKg: 0, reps: 10).validate(), isNull);
    });

    test('a set needs the right values before it can be ticked', () {
      expect(const SetValues(reps: 10).readinessError(ExerciseType.weightReps), isNotNull);
      expect(const SetValues(weightKg: 20, reps: 10).readinessError(ExerciseType.weightReps), isNull);
      expect(const SetValues(reps: 12).readinessError(ExerciseType.bodyweightReps), isNull);
      expect(const SetValues(durationSeconds: 45).readinessError(ExerciseType.time), isNull);
      expect(const SetValues().readinessError(ExerciseType.time), isNotNull);
    });
  });

  group('personal records', () {
    ExerciseSessionStats stats(int id, List<SetLog> sets) =>
        ExerciseSessionStats.fromSets(sessionId: id, date: '2026-11-0$id', type: ExerciseType.weightReps, sets: sets);

    test('a first session is not a record', () {
      final first = stats(1, [set(1, kg: 60, reps: 8)]);
      expect(newRecords(ExerciseType.weightReps, first, const []), isEmpty);
    });

    test('beating earlier sessions is a record; matching is not', () {
      final earlier = [
        stats(1, [set(1, kg: 60, reps: 8)]),
      ];
      final same = stats(2, [set(1, kg: 60, reps: 8)]);
      expect(newRecords(ExerciseType.weightReps, same, earlier), isEmpty);
      final heavier = stats(3, [set(1, kg: 62.5, reps: 6)]);
      expect(newRecords(ExerciseType.weightReps, heavier, earlier), contains(RecordKind.heaviestWeight));
    });

    test('all-time records pick the best session', () {
      final history = [
        stats(1, [set(1, kg: 60, reps: 8)]),
        stats(2, [set(1, kg: 70, reps: 3)]),
        stats(3, [set(1, kg: 65, reps: 8)]),
      ];
      final r = ExerciseRecords.from(history);
      expect(r.heaviest!.sessionId, 2);
      expect(r.bestE1rm!.sessionId, 3); // 65 × (1 + 8/30) = 82.3 > 70 × 1.1 = 77
    });
  });

  test('plan day duration estimate', () {
    const pe = PlannedExercise(
      id: 1,
      planDayId: 1,
      exercise: bench,
      sortOrder: 0,
      sets: 3,
      minReps: 8,
      maxReps: 12,
      restSeconds: 90,
    );
    const day = PlanDay(id: 1, planId: 1, weekday: 1, name: 'Push', isRestDay: false, exercises: [pe, pe]);
    // 5 min warm-up + 2 × 3 × (40 + 90) s = 300 + 780 = 1080 s = 18 min → 20 min
    expect(day.estimatedMinutes, 20);
    expect(day.muscles, ['Chest']);
  });
}
