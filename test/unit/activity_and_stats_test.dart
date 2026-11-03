import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/features/dashboard/weekly_activity.dart';
import 'package:myfit_tracker/features/progress/body_repository.dart';
import 'package:myfit_tracker/features/progress/progress_stats.dart';
import 'package:myfit_tracker/features/workout/models.dart';

PlanWithDays plan({required Set<int> restDays}) => PlanWithDays(const WorkoutPlan(id: 1, name: 'Plan'), [
  for (var wd = 1; wd <= 7; wd++)
    PlanDay(id: wd, planId: 1, weekday: wd, name: 'Day $wd', isRestDay: restDays.contains(wd)),
]);

void main() {
  group('weekly activity', () {
    // Thursday 5 Nov 2026; week is Mon 2 – Sun 8.
    final today = DateTime(2026, 11, 5);

    test('completed, missed, today, planned and rest days', () {
      final days = buildWeeklyActivity(
        today: today,
        plan: plan(restDays: {3, 7}),
        completedDates: {'2026-11-02'},
      );
      expect(days.map((d) => d.status).toList(), [
        DayStatus.completed, // Mon
        DayStatus.missed, // Tue: planned, not logged
        DayStatus.rest, // Wed: rest is never missed
        DayStatus.today, // Thu
        DayStatus.planned, // Fri
        DayStatus.planned, // Sat
        DayStatus.rest, // Sun
      ]);
    });

    test('a workout on a rest day still counts as completed', () {
      final days = buildWeeklyActivity(
        today: today,
        plan: plan(restDays: {3}),
        completedDates: {'2026-11-04'},
      );
      expect(days[2].status, DayStatus.completed);
    });

    test('no plan means nothing is marked missed', () {
      final days = buildWeeklyActivity(today: today, plan: null, completedDates: const {});
      expect(days.every((d) => d.status == DayStatus.unplanned), isTrue);
    });

    test('an in-progress session is shown on its day', () {
      final days = buildWeeklyActivity(
        today: today,
        plan: plan(restDays: {}),
        completedDates: const {},
        inProgressDate: '2026-11-05',
      );
      expect(days[3].status, DayStatus.inProgress);
    });
  });

  group('weight stats', () {
    WeightLog w(int id, String date, double kg) => WeightLog(id: id, date: date, weightKg: kg);

    test('change over a period uses only entries inside it', () {
      final logs = [
        w(1, '2026-09-01', 60),
        w(2, '2026-10-20', 62.4),
        w(3, '2026-10-29', 63.0),
        w(4, '2026-11-03', 64.2),
      ];
      final s = weightStats(logs, today: DateTime(2026, 11, 3), periodDays: 30);
      expect(s.entriesInPeriod.length, 3);
      expect(s.periodFirst!.date, '2026-10-20');
      expect(s.periodChangeKg, closeTo(1.8, 1e-9));
      expect(s.latest!.weightKg, 64.2);
    });

    test('weekly average is separate from the latest weight', () {
      final logs = [w(1, '2026-10-27', 65), w(2, '2026-10-30', 63), w(3, '2026-11-02', 64)];
      final s = weightStats(logs, today: DateTime(2026, 11, 2), periodDays: null);
      // Entries from 27 Oct to 2 Nov (7 days ending on the latest): all three.
      expect(s.weeklyAverageKg, closeTo(64, 1e-9));
      expect(s.weeklyAverageCount, 3);
      expect(s.latest!.weightKg, 64);
    });

    test('a single entry has no change', () {
      final s = weightStats([w(1, '2026-11-01', 70)], today: DateTime(2026, 11, 3), periodDays: 7);
      expect(s.periodChangeKg, isNull);
    });

    test('empty history', () {
      final s = weightStats(const [], today: DateTime(2026, 11, 3));
      expect(s.latest, isNull);
      expect(s.weeklyAverageKg, isNull);
    });
  });
}
