import 'package:flutter/foundation.dart';

import '../../core/utils/dates.dart';
import '../exercises/exercise.dart';

@immutable
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    this.description = '',
    this.isSample = false,
    this.isActive = false,
  });

  final int id;
  final String name;
  final String description;
  final bool isSample;
  final bool isActive;

  factory WorkoutPlan.fromMap(Map<String, Object?> m) => WorkoutPlan(
    id: m['id'] as int,
    name: m['name'] as String,
    description: (m['description'] as String?) ?? '',
    isSample: m['is_sample'] == 1,
    isActive: m['is_active'] == 1,
  );
}

@immutable
class PlannedExercise {
  const PlannedExercise({
    required this.id,
    required this.planDayId,
    required this.exercise,
    required this.sortOrder,
    required this.sets,
    this.minReps,
    this.maxReps,
    required this.restSeconds,
  });

  final int id;
  final int planDayId;
  final Exercise exercise;
  final int sortOrder;
  final int sets;

  /// Target reps, or target seconds for timed exercises.
  final int? minReps;
  final int? maxReps;
  final int restSeconds;

  factory PlannedExercise.fromMap(Map<String, Object?> m) => PlannedExercise(
    id: m['id'] as int,
    planDayId: m['plan_day_id'] as int,
    exercise: Exercise.fromMap(m, prefix: 'ex_'),
    sortOrder: m['sort_order'] as int,
    sets: m['planned_sets'] as int,
    minReps: m['min_reps'] as int?,
    maxReps: m['max_reps'] as int?,
    restSeconds: m['rest_seconds'] as int,
  );

  String get targetLabel => describeTarget(exercise.type, sets: sets, minReps: minReps, maxReps: maxReps);
}

/// "3 sets · 8–12 reps", "3 sets · 30–60 s", "1 set".
String describeTarget(ExerciseType type, {required int sets, int? minReps, int? maxReps}) {
  final setsText = '$sets ${sets == 1 ? 'set' : 'sets'}';
  final range = repRangeLabel(minReps, maxReps);
  if (range == null || type == ExerciseType.distance) return setsText;
  return type == ExerciseType.time ? '$setsText · $range s' : '$setsText · $range reps';
}

String? repRangeLabel(int? min, int? max) {
  if (min == null && max == null) return null;
  if (min == null || max == null || min == max) return '${min ?? max}';
  return '$min–$max';
}

@immutable
class PlanDay {
  const PlanDay({
    required this.id,
    required this.planId,
    required this.weekday,
    required this.name,
    required this.isRestDay,
    this.exercises = const [],
  });

  final int id;
  final int planId;
  final int weekday;
  final String name;
  final bool isRestDay;
  final List<PlannedExercise> exercises;

  String get title {
    if (name.trim().isNotEmpty) return name.trim();
    return isRestDay ? 'Rest Day' : 'Workout';
  }

  /// Distinct primary muscle groups, in plan order.
  List<String> get muscles {
    final seen = <String>[];
    for (final e in exercises) {
      if (!seen.contains(e.exercise.muscle)) seen.add(e.exercise.muscle);
    }
    return seen;
  }

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets);

  /// Rough duration: ~40 s of work per set (or the target hold time),
  /// plus the planned rest, plus 5 minutes to warm up. Rounded to 5 minutes.
  int get estimatedMinutes {
    if (exercises.isEmpty) return 0;
    var seconds = 300;
    for (final e in exercises) {
      final work = e.exercise.type == ExerciseType.time ? (e.maxReps ?? e.minReps ?? 40) : 40;
      seconds += e.sets * (work + e.restSeconds);
    }
    return ((seconds / 60) / 5).round() * 5;
  }

  factory PlanDay.fromMap(Map<String, Object?> m, List<PlannedExercise> exercises) => PlanDay(
    id: m['id'] as int,
    planId: m['plan_id'] as int,
    weekday: m['weekday'] as int,
    name: (m['name'] as String?) ?? '',
    isRestDay: m['is_rest_day'] == 1,
    exercises: exercises,
  );
}

@immutable
class PlanWithDays {
  const PlanWithDays(this.plan, this.days);
  final WorkoutPlan plan;

  /// Always seven entries, Monday first.
  final List<PlanDay> days;

  PlanDay dayFor(int weekday) => days.firstWhere((d) => d.weekday == weekday);

  int get trainingDays => days.where((d) => !d.isRestDay).length;
}

enum SessionExerciseStatus {
  pending,
  completed,
  skipped;

  static SessionExerciseStatus fromDb(Object? v) =>
      SessionExerciseStatus.values.firstWhere((s) => s.name == v, orElse: () => SessionExerciseStatus.pending);
}

@immutable
class SetLog {
  const SetLog({
    required this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceMeters,
    this.isCompleted = false,
    this.completedAt,
  });

  final int id;
  final int sessionExerciseId;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceMeters;
  final bool isCompleted;
  final DateTime? completedAt;

  bool get hasAnyValue => weightKg != null || reps != null || durationSeconds != null || distanceMeters != null;

  factory SetLog.fromMap(Map<String, Object?> m) => SetLog(
    id: m['id'] as int,
    sessionExerciseId: m['session_exercise_id'] as int,
    setNumber: m['set_number'] as int,
    weightKg: (m['weight_kg'] as num?)?.toDouble(),
    reps: m['reps'] as int?,
    durationSeconds: m['duration_seconds'] as int?,
    distanceMeters: (m['distance_meters'] as num?)?.toDouble(),
    isCompleted: m['is_completed'] == 1,
    completedAt: m['completed_at'] == null ? null : parseTimestamp(m['completed_at'] as String),
  );

  SetLog copyWith({SetValues? values, bool? isCompleted, DateTime? completedAt, bool clearCompletedAt = false}) =>
      SetLog(
        id: id,
        sessionExerciseId: sessionExerciseId,
        setNumber: setNumber,
        weightKg: values == null ? weightKg : values.weightKg,
        reps: values == null ? reps : values.reps,
        durationSeconds: values == null ? durationSeconds : values.durationSeconds,
        distanceMeters: values == null ? distanceMeters : values.distanceMeters,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  SetValues get values =>
      SetValues(weightKg: weightKg, reps: reps, durationSeconds: durationSeconds, distanceMeters: distanceMeters);
}

/// The editable measurements of a set. Null means "not entered".
@immutable
class SetValues {
  const SetValues({this.weightKg, this.reps, this.durationSeconds, this.distanceMeters});
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceMeters;

  /// Rejects negative or absurd values before they reach the database.
  String? validate() {
    if (weightKg != null && (weightKg! < 0 || weightKg! > 1000)) return 'Weight must be between 0 and 1000 kg';
    if (reps != null && (reps! < 0 || reps! > 1000)) return 'Reps must be between 0 and 1000';
    if (durationSeconds != null && (durationSeconds! < 0 || durationSeconds! > 86400)) {
      return 'Duration is out of range';
    }
    if (distanceMeters != null && (distanceMeters! < 0 || distanceMeters! > 1000000)) return 'Distance is out of range';
    return null;
  }

  /// What must be filled in before a set can be ticked off.
  String? readinessError(ExerciseType type) => switch (type) {
    ExerciseType.weightReps when weightKg == null || reps == null || reps == 0 => 'Enter the weight and reps first',
    ExerciseType.bodyweightReps when reps == null || reps == 0 => 'Enter the reps first',
    ExerciseType.time when durationSeconds == null || durationSeconds == 0 => 'Enter the time first',
    ExerciseType.distance
        when (distanceMeters == null || distanceMeters == 0) && (durationSeconds == null || durationSeconds == 0) =>
      'Enter the distance or time first',
    _ => null,
  };
}

@immutable
class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exercise,
    required this.sortOrder,
    required this.status,
    this.minReps,
    this.maxReps,
    required this.restSeconds,
    this.notes = '',
    this.sets = const [],
  });

  final int id;
  final int sessionId;
  final Exercise exercise;
  final int sortOrder;
  final SessionExerciseStatus status;
  final int? minReps;
  final int? maxReps;
  final int restSeconds;
  final String notes;
  final List<SetLog> sets;

  int get completedSets => sets.where((s) => s.isCompleted).length;
  bool get isDone => sets.isNotEmpty && completedSets == sets.length;

  factory SessionExercise.fromMap(Map<String, Object?> m, List<SetLog> sets) => SessionExercise(
    id: m['id'] as int,
    sessionId: m['session_id'] as int,
    exercise: Exercise.fromMap(m, prefix: 'ex_'),
    sortOrder: m['sort_order'] as int,
    status: SessionExerciseStatus.fromDb(m['status']),
    minReps: m['min_reps'] as int?,
    maxReps: m['max_reps'] as int?,
    restSeconds: m['rest_seconds'] as int,
    notes: (m['notes'] as String?) ?? '',
    sets: sets,
  );

  SessionExercise copyWith({List<SetLog>? sets, SessionExerciseStatus? status, int? restSeconds}) => SessionExercise(
    id: id,
    sessionId: sessionId,
    exercise: exercise,
    sortOrder: sortOrder,
    status: status ?? this.status,
    minReps: minReps,
    maxReps: maxReps,
    restSeconds: restSeconds ?? this.restSeconds,
    notes: notes,
    sets: sets ?? this.sets,
  );
}

enum SessionStatus {
  inProgress('in_progress'),
  completed('completed');

  const SessionStatus(this.dbValue);
  final String dbValue;

  static SessionStatus fromDb(Object? v) => v == 'completed' ? completed : inProgress;
}

@immutable
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    this.planDayId,
    required this.name,
    required this.date,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds = 0,
    required this.status,
    this.currentIndex = 0,
    this.notes = '',
    this.exercises = const [],
  });

  final int id;
  final int? planDayId;
  final String name;

  /// Local date key (YYYY-MM-DD).
  final String date;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final SessionStatus status;
  final int currentIndex;
  final String notes;
  final List<SessionExercise> exercises;

  bool get isActive => status == SessionStatus.inProgress;

  factory WorkoutSession.fromMap(Map<String, Object?> m, List<SessionExercise> exercises) => WorkoutSession(
    id: m['id'] as int,
    planDayId: m['plan_day_id'] as int?,
    name: m['name'] as String,
    date: m['date'] as String,
    startedAt: parseTimestamp(m['started_at'] as String),
    completedAt: m['completed_at'] == null ? null : parseTimestamp(m['completed_at'] as String),
    durationSeconds: m['duration_seconds'] as int,
    status: SessionStatus.fromDb(m['status']),
    currentIndex: m['current_index'] as int,
    notes: (m['notes'] as String?) ?? '',
    exercises: exercises,
  );

  WorkoutSession copyWith({List<SessionExercise>? exercises, int? currentIndex}) => WorkoutSession(
    id: id,
    planDayId: planDayId,
    name: name,
    date: date,
    startedAt: startedAt,
    completedAt: completedAt,
    durationSeconds: durationSeconds,
    status: status,
    currentIndex: currentIndex ?? this.currentIndex,
    notes: notes,
    exercises: exercises ?? this.exercises,
  );

  WorkoutSession replaceSet(SetLog updated) => copyWith(
    exercises: [
      for (final e in exercises)
        e.id == updated.sessionExerciseId
            ? e.copyWith(sets: [for (final s in e.sets) s.id == updated.id ? updated : s])
            : e,
    ],
  );
}

/// A completed session in the history list.
@immutable
class SessionListItem {
  const SessionListItem({
    required this.id,
    required this.name,
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.setCount,
    required this.volumeKg,
  });

  final int id;
  final String name;
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int setCount;
  final double volumeKg;
}
