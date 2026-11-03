import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/utils/dates.dart';
import '../exercises/exercise.dart';
import '../exercises/exercise_repository.dart';
import 'models.dart';
import 'plan_repository.dart';
import 'session_repository.dart';
import 'workout_calculations.dart';

final planRepositoryProvider = Provider((ref) => PlanRepository(ref.watch(databaseProvider)));
final sessionRepositoryProvider = Provider((ref) => SessionRepository(ref.watch(databaseProvider)));

final plansProvider = FutureProvider<List<WorkoutPlan>>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(planRepositoryProvider).plans();
});

final activePlanProvider = FutureProvider<PlanWithDays?>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(planRepositoryProvider).activePlan();
});

final planDayProvider = FutureProvider.autoDispose.family<PlanDay?, int>((ref, dayId) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(planRepositoryProvider).day(dayId);
});

/// Today's day in the active plan (null when there is no active plan).
final todayPlanDayProvider = FutureProvider<PlanDay?>((ref) async {
  final today = ref.watch(todayProvider);
  final plan = await ref.watch(activePlanProvider.future);
  return plan?.dayFor(today.weekday);
});

final todayCompletedSessionsProvider = FutureProvider<List<WorkoutSession>>((ref) {
  ref.watch(workoutRevisionProvider);
  final today = ref.watch(todayProvider);
  return ref.watch(sessionRepositoryProvider).completedOn(dateKey(today));
});

/// Dates in the current week (Mon–Sun) with a completed workout.
final weekCompletedDatesProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(workoutRevisionProvider);
  final monday = startOfWeek(ref.watch(todayProvider));
  return ref.watch(sessionRepositoryProvider).completedDates(dateKey(monday), dateKey(addDays(monday, 6)));
});

final historyProvider = FutureProvider<List<SessionListItem>>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(sessionRepositoryProvider).history(limit: 500);
});

final sessionDetailProvider = FutureProvider.autoDispose.family<WorkoutSession?, int>((ref, id) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(sessionRepositoryProvider).byId(id);
});

final exercisesWithHistoryProvider = FutureProvider<List<Exercise>>((ref) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(sessionRepositoryProvider).exercisesWithHistory();
});

final exerciseHistoryProvider = FutureProvider.autoDispose.family<List<ExerciseSessionStats>, int>((
  ref,
  exerciseId,
) async {
  ref.watch(workoutRevisionProvider);
  final exercise = await ref.watch(exerciseRepositoryProvider).byId(exerciseId);
  if (exercise == null) return const [];
  return ref.watch(sessionRepositoryProvider).exerciseHistory(exercise);
});

/// The last completed sets of an exercise, excluding the given session.
final previousSetsProvider = FutureProvider.autoDispose.family<List<SetLog>, ({int exerciseId, int sessionId})>((
  ref,
  key,
) {
  ref.watch(workoutRevisionProvider);
  return ref.watch(sessionRepositoryProvider).previousSets(key.exerciseId, excludeSessionId: key.sessionId);
});

/// Records set in a finished session, compared with earlier sessions only.
final sessionRecordsProvider = FutureProvider.autoDispose.family<List<PersonalRecord>, int>((ref, sessionId) async {
  ref.watch(workoutRevisionProvider);
  final repo = ref.watch(sessionRepositoryProvider);
  final session = await repo.byId(sessionId);
  if (session == null) return const [];
  final records = <PersonalRecord>[];
  for (final e in session.exercises) {
    final history = await repo.exerciseHistory(e.exercise);
    final index = history.indexWhere((h) => h.sessionId == sessionId);
    if (index < 0) continue;
    final current = history[index];
    // Earlier = everything before this session in date order.
    final previous = history.sublist(0, index);
    for (final kind in newRecords(e.exercise.type, current, previous)) {
      final value = switch (kind) {
        RecordKind.heaviestWeight => current.topWeightKg ?? 0,
        RecordKind.bestEstimatedOneRepMax => current.bestE1rm ?? 0,
        RecordKind.mostReps => (current.mostReps ?? 0).toDouble(),
        RecordKind.longestHold => (current.longestSeconds ?? 0).toDouble(),
        RecordKind.longestDistance => current.longestDistanceM ?? 0,
        RecordKind.bestVolume => current.volumeKg,
      };
      records.add(PersonalRecord(kind, value, e.exercise));
    }
  }
  return records;
});
