import 'dart:math' as math;

import '../exercises/exercise.dart';
import 'models.dart';

/// Pure workout maths, kept out of widgets so it can be unit-tested.

/// Volume counts only external load: completed sets with a weight above zero
/// and at least one rep. Bodyweight-only, timed and distance sets are excluded
/// rather than estimated.
bool countsTowardVolume(SetLog set, ExerciseType type) =>
    set.isCompleted && type.usesReps && (set.weightKg ?? 0) > 0 && (set.reps ?? 0) > 0;

double setVolume(SetLog set, ExerciseType type) => countsTowardVolume(set, type) ? set.weightKg! * set.reps! : 0;

/// Estimated one-rep max using the Epley formula: weight × (1 + reps / 30).
/// Only calculated for 1–12 reps, where the estimate is reasonable. Always
/// shown as an estimate, never as a tested lift.
double? estimatedOneRepMax(double? weightKg, int? reps) {
  if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0 || reps > 12) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

class SessionSummary {
  const SessionSummary({
    required this.totalExercises,
    required this.completedExercises,
    required this.totalSets,
    required this.completedSets,
    required this.volumeKg,
    required this.volumeSets,
    required this.excludedSets,
  });

  final int totalExercises;

  /// Exercises with at least one completed set.
  final int completedExercises;
  final int totalSets;
  final int completedSets;

  /// External-load volume (kg × reps) from completed sets.
  final double volumeKg;

  /// Completed sets included in [volumeKg].
  final int volumeSets;

  /// Completed sets left out of the volume (bodyweight-only, timed, distance).
  final int excludedSets;
}

SessionSummary summarizeSession(WorkoutSession session) {
  var completedExercises = 0, totalSets = 0, completedSets = 0, volumeSets = 0, excluded = 0;
  var volume = 0.0;
  for (final e in session.exercises) {
    var anyCompleted = false;
    for (final s in e.sets) {
      totalSets++;
      if (!s.isCompleted) continue;
      anyCompleted = true;
      completedSets++;
      if (countsTowardVolume(s, e.exercise.type)) {
        volumeSets++;
        volume += setVolume(s, e.exercise.type);
      } else {
        excluded++;
      }
    }
    if (anyCompleted) completedExercises++;
  }
  return SessionSummary(
    totalExercises: session.exercises.length,
    completedExercises: completedExercises,
    totalSets: totalSets,
    completedSets: completedSets,
    volumeKg: volume,
    volumeSets: volumeSets,
    excludedSets: excluded,
  );
}

/// One exercise's completed sets within one session, condensed for charts.
class ExerciseSessionStats {
  const ExerciseSessionStats({
    required this.sessionId,
    required this.date,
    required this.completedSets,
    required this.totalReps,
    this.topWeightKg,
    this.topWeightReps,
    required this.volumeKg,
    this.bestE1rm,
    this.longestSeconds,
    this.longestDistanceM,
    this.mostReps,
  });

  final int sessionId;
  final String date;
  final int completedSets;
  final int totalReps;

  /// Heaviest completed set and the reps done with it.
  final double? topWeightKg;
  final int? topWeightReps;
  final double volumeKg;
  final double? bestE1rm;
  final int? longestSeconds;
  final double? longestDistanceM;
  final int? mostReps;

  static ExerciseSessionStats fromSets({
    required int sessionId,
    required String date,
    required ExerciseType type,
    required List<SetLog> sets,
  }) {
    final done = sets.where((s) => s.isCompleted).toList();
    double? topWeight;
    int? topReps;
    double? bestE1rm;
    int? longest;
    double? farthest;
    int? mostReps;
    var volume = 0.0;
    var totalReps = 0;
    for (final s in done) {
      totalReps += s.reps ?? 0;
      volume += setVolume(s, type);
      final w = s.weightKg ?? 0;
      if (w > 0 && (topWeight == null || w > topWeight || (w == topWeight && (s.reps ?? 0) > (topReps ?? 0)))) {
        topWeight = w;
        topReps = s.reps;
      }
      final e = estimatedOneRepMax(s.weightKg, s.reps);
      if (e != null && (bestE1rm == null || e > bestE1rm)) bestE1rm = e;
      if (s.durationSeconds != null) longest = math.max(longest ?? 0, s.durationSeconds!);
      if (s.distanceMeters != null) farthest = math.max(farthest ?? 0, s.distanceMeters!);
      if (s.reps != null) mostReps = math.max(mostReps ?? 0, s.reps!);
    }
    return ExerciseSessionStats(
      sessionId: sessionId,
      date: date,
      completedSets: done.length,
      totalReps: totalReps,
      topWeightKg: topWeight,
      topWeightReps: topReps,
      volumeKg: volume,
      bestE1rm: bestE1rm,
      longestSeconds: longest,
      longestDistanceM: farthest,
      mostReps: mostReps,
    );
  }
}

enum RecordKind {
  heaviestWeight('Heaviest weight'),
  bestEstimatedOneRepMax('Best estimated 1RM'),
  mostReps('Most reps in a set'),
  longestHold('Longest time'),
  longestDistance('Longest distance'),
  bestVolume('Most session volume');

  const RecordKind(this.label);
  final String label;
}

class PersonalRecord {
  const PersonalRecord(this.kind, this.value, this.exercise);
  final RecordKind kind;
  final double value;
  final Exercise exercise;
}

/// Records beaten in [current] compared with all [previous] sessions of the
/// same exercise. With no earlier sessions there is no baseline, so nothing
/// is reported: a first session is not a "personal record".
List<RecordKind> newRecords(ExerciseType type, ExerciseSessionStats current, List<ExerciseSessionStats> previous) {
  if (previous.isEmpty || current.completedSets == 0) return const [];
  double? best(double? Function(ExerciseSessionStats s) pick) {
    double? b;
    for (final p in previous) {
      final v = pick(p);
      if (v != null && (b == null || v > b)) b = v;
    }
    return b;
  }

  bool beats(double? now, double? before) => now != null && now > 0 && (before == null || now > before + 1e-9);

  final records = <RecordKind>[];
  if (type.usesReps) {
    if (beats(current.topWeightKg, best((s) => s.topWeightKg))) records.add(RecordKind.heaviestWeight);
    if (beats(current.bestE1rm, best((s) => s.bestE1rm))) records.add(RecordKind.bestEstimatedOneRepMax);
    if ((current.topWeightKg ?? 0) == 0 && beats(current.mostReps?.toDouble(), best((s) => s.mostReps?.toDouble()))) {
      records.add(RecordKind.mostReps);
    }
  }
  if (type == ExerciseType.time &&
      beats(current.longestSeconds?.toDouble(), best((s) => s.longestSeconds?.toDouble()))) {
    records.add(RecordKind.longestHold);
  }
  if (type == ExerciseType.distance && beats(current.longestDistanceM, best((s) => s.longestDistanceM))) {
    records.add(RecordKind.longestDistance);
  }
  return records;
}

/// All-time bests for the strength screen.
class ExerciseRecords {
  const ExerciseRecords({
    this.heaviest,
    this.bestE1rm,
    this.mostReps,
    this.bestVolume,
    this.longestSeconds,
    this.longestDistanceM,
  });

  final ExerciseSessionStats? heaviest;
  final ExerciseSessionStats? bestE1rm;
  final ExerciseSessionStats? mostReps;
  final ExerciseSessionStats? bestVolume;
  final ExerciseSessionStats? longestSeconds;
  final ExerciseSessionStats? longestDistanceM;

  static ExerciseRecords from(List<ExerciseSessionStats> history) {
    ExerciseSessionStats? pick(num? Function(ExerciseSessionStats s) f) {
      ExerciseSessionStats? best;
      for (final s in history) {
        final v = f(s);
        if (v == null || v <= 0) continue;
        if (best == null || v > f(best)!) best = s;
      }
      return best;
    }

    return ExerciseRecords(
      heaviest: pick((s) => s.topWeightKg),
      bestE1rm: pick((s) => s.bestE1rm),
      mostReps: pick((s) => s.mostReps),
      bestVolume: pick((s) => s.volumeKg),
      longestSeconds: pick((s) => s.longestSeconds),
      longestDistanceM: pick((s) => s.longestDistanceM),
    );
  }
}
