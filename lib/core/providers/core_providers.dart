import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../utils/dates.dart';

/// Opened in `main()` (or a test) and injected with `overrideWithValue`.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// A counter that read-providers watch. Repositories' callers bump the
/// matching revision after a write so every screen showing that data reloads.
class Revision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Workout plans, sessions and the exercise library.
final workoutRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Foods, food logs, saved meals and water.
final nutritionRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// Body weight and measurements.
final bodyRevisionProvider = NotifierProvider<Revision, int>(Revision.new);

/// The current local date. Rolls over at midnight and when the app resumes,
/// so "today" never sticks to the day the app was opened.
class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleRollover();
    return dateOnly(DateTime.now());
  }

  void refresh() {
    final today = dateOnly(DateTime.now());
    if (today != state) state = today;
    _scheduleRollover();
  }

  void _scheduleRollover() {
    _timer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), refresh);
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

/// Fixed date for tests: no timers.
class FixedTodayNotifier extends TodayNotifier {
  FixedTodayNotifier(this.fixed);
  final DateTime fixed;

  @override
  DateTime build() => dateOnly(fixed);

  @override
  void refresh() {}
}
