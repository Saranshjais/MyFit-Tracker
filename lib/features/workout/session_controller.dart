import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../exercises/exercise.dart';
import '../settings/app_settings.dart';
import 'models.dart';
import 'session_repository.dart';
import 'workout_providers.dart';

/// The in-progress workout. Every change is written to the database at once,
/// so closing the app never loses an unfinished session.
///
/// Set edits update the in-memory state directly; structural changes reload
/// the session from the database. Starting, finishing and discarding bump the
/// workout revision so the dashboard and plan screens refresh too.
class SessionController extends AsyncNotifier<WorkoutSession?> {
  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  @override
  Future<WorkoutSession?> build() {
    ref.watch(workoutRevisionProvider);
    return ref.read(sessionRepositoryProvider).activeSession();
  }

  WorkoutSession? get _session => state.value;

  void _bump() => ref.read(workoutRevisionProvider.notifier).bump();

  Future<void> _reload() async {
    final s = _session;
    if (s == null) return;
    state = AsyncData(await _repo.byId(s.id));
  }

  SetLog? _findSet(int setId) {
    for (final e in _session?.exercises ?? const <SessionExercise>[]) {
      for (final s in e.sets) {
        if (s.id == setId) return s;
      }
    }
    return null;
  }

  SessionExercise? _exerciseOf(int setId) {
    for (final e in _session?.exercises ?? const <SessionExercise>[]) {
      if (e.sets.any((s) => s.id == setId)) return e;
    }
    return null;
  }

  Future<int> startFromPlanDay(PlanDay day, String date) async {
    final id = await _repo.startFromPlanDay(day, date: date);
    _bump();
    return id;
  }

  Future<int> startEmpty(String date) async {
    final id = await _repo.startEmpty(date: date);
    _bump();
    return id;
  }

  /// Returns a validation message, or null when saved.
  Future<String?> updateSet(int setId, SetValues values) async {
    final error = values.validate();
    if (error != null) return error;
    final current = _findSet(setId);
    if (current == null) return null;
    await _repo.updateSetValues(setId, values);
    final s = _session;
    if (s != null) state = AsyncData(s.replaceSet(current.copyWith(values: values)));
    return null;
  }

  /// Ticks or unticks a set. Returns a message when the set is not ready.
  Future<String?> setCompleted(int setId, bool completed) async {
    final current = _findSet(setId);
    final exercise = _exerciseOf(setId);
    if (current == null || exercise == null) return null;
    if (completed) {
      final problem = current.values.readinessError(exercise.exercise.type);
      if (problem != null) return problem;
    }
    await _repo.setCompleted(setId, completed);
    final s = _session;
    if (s != null) {
      state = AsyncData(
        s.replaceSet(
          current.copyWith(
            isCompleted: completed,
            completedAt: completed ? DateTime.now() : null,
            clearCompletedAt: !completed,
          ),
        ),
      );
    }
    return null;
  }

  Future<void> addSet(int sessionExerciseId) async {
    await _repo.addSet(sessionExerciseId);
    await _reload();
  }

  Future<void> removeSet(int setId) async {
    // Drop it from the screen first: a swiped-away row must leave the widget
    // tree in the same frame.
    final s = _session;
    if (s != null) {
      state = AsyncData(
        s.copyWith(
          exercises: [
            for (final e in s.exercises)
              e.copyWith(
                sets: [
                  for (final x in e.sets)
                    if (x.id != setId) x,
                ],
              ),
          ],
        ),
      );
    }
    await _repo.removeSet(setId);
    await _reload();
  }

  Future<void> addExercise(Exercise exercise) async {
    final s = _session;
    if (s == null) return;
    await _repo.addExercise(s.id, exercise, restSeconds: ref.read(settingsProvider).defaultRestSeconds);
    await _repo.setCurrentIndex(s.id, s.exercises.length);
    await _reload();
  }

  Future<void> replaceExercise(int sessionExerciseId, Exercise replacement) async {
    await _repo.replaceExercise(sessionExerciseId, replacement);
    await _reload();
  }

  Future<void> removeExercise(int sessionExerciseId) async {
    final s = _session;
    if (s == null) return;
    await _repo.removeExercise(sessionExerciseId);
    final newCount = s.exercises.length - 1;
    if (s.currentIndex >= newCount) await _repo.setCurrentIndex(s.id, (newCount - 1).clamp(0, 999));
    await _reload();
  }

  Future<void> setSkipped(int sessionExerciseId, bool skipped) async {
    await _repo.setExerciseStatus(
      sessionExerciseId,
      skipped ? SessionExerciseStatus.skipped : SessionExerciseStatus.pending,
    );
    await _reload();
  }

  Future<void> setRestSeconds(int sessionExerciseId, int seconds) async {
    await _repo.setRestSeconds(sessionExerciseId, seconds);
    await _reload();
  }

  Future<void> goTo(int index) async {
    final s = _session;
    if (s == null || s.exercises.isEmpty) return;
    final clamped = index.clamp(0, s.exercises.length - 1);
    await _repo.setCurrentIndex(s.id, clamped);
    state = AsyncData(s.copyWith(currentIndex: clamped));
  }

  /// Sets that have values but were not ticked.
  int get filledButIncompleteSets {
    var count = 0;
    for (final e in _session?.exercises ?? const <SessionExercise>[]) {
      if (e.status == SessionExerciseStatus.skipped) continue;
      for (final s in e.sets) {
        if (!s.isCompleted && s.values.readinessError(e.exercise.type) == null) count++;
      }
    }
    return count;
  }

  Future<void> completeFilledSets() async {
    for (final e in _session?.exercises ?? const <SessionExercise>[]) {
      if (e.status == SessionExerciseStatus.skipped) continue;
      for (final s in e.sets) {
        if (!s.isCompleted && s.values.readinessError(e.exercise.type) == null) {
          await _repo.setCompleted(s.id, true);
        }
      }
    }
    await _reload();
  }

  /// Returns the finished session's id.
  Future<int?> finish({String notes = ''}) async {
    final s = _session;
    if (s == null) return null;
    await _repo.finish(s.id, notes: notes);
    _bump();
    return s.id;
  }

  Future<void> discard() async {
    final s = _session;
    if (s == null) return;
    await _repo.delete(s.id);
    _bump();
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, WorkoutSession?>(SessionController.new);
